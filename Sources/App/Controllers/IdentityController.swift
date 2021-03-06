import Vapor
import Fluent
import JWTKit

final class IdentityController: RouteCollection {

    public static let uri: PathComponent = .constant("identity")

    func boot(routes: RoutesBuilder) throws {
        let identityGroup = routes.grouped(IdentityController.uri)

        identityGroup.get("authenticate", ":uri", use: authenticate)
        identityGroup.get("callback", ":uri", use: callback)
        identityGroup.post("login", use: login)
    }
    
    /// Redirect to external authentication provider.
    func authenticate(request: Request) throws -> EventLoopFuture<Response> {
        guard let uri = request.parameters.get("uri") else {
            throw OpenIdConnectError.invalidClientName
        }
        
        let externalUsersService = request.application.services.externalUsersService
        let authClientFuture = AuthClient.query(on: request.db).filter(\.$uri == uri).first()
        return authClientFuture.flatMapThrowing { authClient in
            guard let authClient = authClient else {
                throw OpenIdConnectError.clientNotFound
            }
            
            let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
            let baseAddress = appplicationSettings?.baseAddress ?? ""
            let location = try externalUsersService.getRedirectLocation(authClient: authClient, baseAddress: baseAddress)
            return request.redirect(to: location, type: .permanent)
        }
    }
    
    /// Callback from external authentication provider.
    func callback(request: Request) throws -> EventLoopFuture<Response> {
        guard let uri = request.parameters.get("uri") else {
            throw OpenIdConnectError.invalidClientName
        }
        
        let callbackResponse = try request.query.decode(OAuthCallback.self)
        guard let code = callbackResponse.code else {
            throw OpenIdConnectError.codeTokenNotFound
        }
        
        let externalUsersService = request.application.services.externalUsersService
        var authClient: AuthClient!
        var oauthUser: OAuthUser!

        // Get AuthClient object.
        let authClientFuture = AuthClient.query(on: request.db).filter(\.$uri == uri).first().flatMap { authClientFromDb -> EventLoopFuture<AuthClient> in
            guard let authClientFromDb = authClientFromDb else {
                return request.fail(OpenIdConnectError.clientNotFound)
            }
            
            authClient = authClientFromDb
            return request.success(authClientFromDb)
        }
        
        // Send POST to token endpoint.
        let postResponseFuture = authClientFuture.flatMapThrowing { authClientFromDb -> EventLoopFuture<ClientResponse> in
            return self.postOAuthRequest(on: request, for: authClient, code: code)
        }.flatMap { response in response }
        
        // Validate token from OAuth provider.
        let tokenFuture = postResponseFuture.flatMapThrowing { response -> EventLoopFuture<OAuthUser> in
            try self.getOAuthUser(on: request, from: response, type: authClient.type)
        }.flatMap { token in token }
        
        // Check if external user is registered.
        let getExternalUserFuture = tokenFuture.flatMap { oauthUserFromToken -> EventLoopFuture<(User?, ExternalUser?)> in
            oauthUser = oauthUserFromToken
            return externalUsersService.getRegisteredExternalUser(on: request, user: oauthUser)
        }
        
        // Create user if not exists.
        let userFuture = getExternalUserFuture.flatMapThrowing { (user, externalUser) -> EventLoopFuture<(User, ExternalUser?)> in
            try self.createUserIfNotExists(on: request, userFromDb: user, oauthUser: oauthUser).map { createdUser in
                (createdUser, externalUser)
            }
        }.flatMap { wrappedFuture in wrappedFuture }
        
        // Create external user if not exists.
        let externalUserFuture = userFuture.map { (user, externalUser) -> EventLoopFuture<(User, ExternalUser)>  in
            self.createExternalUserIfNotExists(on: request,
                                                   authClient: authClient,
                                                   oauthUser: oauthUser,
                                                   user: user,
                                                   externalUserFromDb: externalUser).map { createdExternalUser in
                (user, createdExternalUser)
            }
        }.flatMap { wrappedFuture in wrappedFuture }
        
        // Generate authentication token and redirects.
        return externalUserFuture.flatMap { (user, externalUser) in
            let authenticationToken = String.createRandomString(length: 100)
            externalUser.authenticationToken = authenticationToken
            externalUser.tokenCreatedAt = Date()
            
            return externalUser.save(on: request.db).map {
                request.redirect(to: "\(authClient.callbackUrl)?authenticateToken=\(authenticationToken)", type: .permanent)
            }
        }
    }
    
    /// Sign-in user based on authenticate token.
    func login(request: Request) throws -> EventLoopFuture<AccessTokenDto> {
        let loginRequestDto = try request.content.decode(ExternalLoginRequestDto.self)
        let usersService = request.application.services.usersService

        let loginFuture = try usersService.login(on: request, authenticateToken: loginRequestDto.authenticateToken)
        return loginFuture.flatMap { user -> EventLoopFuture<AccessTokenDto> in
            let tokensService = request.application.services.tokensService
            return tokensService.createAccessTokens(on: request, forUser: user)
        }
    }
    
    private func postOAuthRequest(on request: Request, for authClient: AuthClient, code: String) -> EventLoopFuture<ClientResponse> {
        let externalUsersService = request.application.services.externalUsersService
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        let oauthRequest = externalUsersService.getOauthRequest(authClient: authClient, baseAddress: baseAddress, code: code)
        return request.client.post(URI(string: oauthRequest.url), headers: HTTPHeaders()) { clientRequest in
            try clientRequest.content.encode(oauthRequest, as: .urlEncodedForm)
        }
    }
    
    private func getOAuthUser(on request: Request, from response: ClientResponse, type: AuthClientType) throws -> EventLoopFuture<OAuthUser>{
        let accessTokenResponse = try response.content.decode(OAuthResponse.self)
        
        switch type {
        case .apple:
            return request.jwt.apple.verify(accessTokenResponse.idToken!).map { jwt in
                return OAuthUser(uniqueId: jwt.subject.value,
                                 email: jwt.email!,
                                 familyName: nil,
                                 givenName: nil,
                                 name: nil)
            }
            
        case .google:
            return request.jwt.google.verify(accessTokenResponse.idToken!).map { jwt in
                return OAuthUser(uniqueId: jwt.subject.value,
                                 email: jwt.email!,
                                 familyName: jwt.familyName,
                                 givenName: jwt.givenName,
                                 name: jwt.name)
            }
        case .microsoft:
            return request.jwt.microsoft.verify(accessTokenResponse.idToken!).map { jwt in
                return OAuthUser(uniqueId: jwt.subject.value,
                                 email: jwt.email!,
                                 familyName: "",
                                 givenName: "",
                                 name: jwt.name)
            }
        }
    }
    
    private func createExternalUserIfNotExists(on request: Request,
                                               authClient: AuthClient,
                                               oauthUser: OAuthUser,
                                               user: User,
                                               externalUserFromDb: ExternalUser?) -> EventLoopFuture<ExternalUser> {
        
        if let externalUserFromDb = externalUserFromDb {
            return request.success(externalUserFromDb)
        }
        
        let externalUser = ExternalUser(type: authClient.type,
                                        externalId: oauthUser.uniqueId,
                                        userId: user.id!)
        
        return externalUser.save(on: request.db).map { _ in
            externalUser
        }
    }
    
    private func createUserIfNotExists(on request: Request,
                                       userFromDb: User?,
                                       oauthUser: OAuthUser
    ) throws -> EventLoopFuture<User> {

        if let userFromDb = userFromDb {
            return request.success(userFromDb)
        }
        
        let rolesService = request.application.services.rolesService
        let usersService = request.application.services.usersService
        
        let salt = Password.generateSalt()
        let passwordHash = try Password.hash(UUID.init().uuidString, withSalt: salt)
        let gravatarHash = usersService.createGravatarHash(from: oauthUser.email)
        
        let user = User(fromOAuth: oauthUser,
                        withPassword: passwordHash,
                        salt: salt,
                        gravatarHash: gravatarHash)

        let saveUserFuture = user.save(on: request.db)

        let rolesWrappedFuture = saveUserFuture.map { _ in
            rolesService.getDefault(on: request)
        }
        
        let rolesFuture = rolesWrappedFuture.flatMap { roles in
            roles
        }
        
        return rolesFuture.flatMap { roles -> EventLoopFuture<User> in
            var rolesSavedFuture: [EventLoopFuture<Void>] = [EventLoopFuture<Void>]()
            roles.forEach { role in
                let roleSavedFuture = user.$roles.attach(role, on: request.db)
                rolesSavedFuture.append(roleSavedFuture)
            }
            
            return EventLoopFuture.andAllSucceed(rolesSavedFuture, on: request.eventLoop).map { _ -> User in
                user
            }
        }
    }
}
