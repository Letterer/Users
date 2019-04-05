# :couple: Mikroservices - Users

[![Build Status](https://travis-ci.org/Mikroservices/Users.svg?branch=master)](https://travis-ci.org/Mikroservices/Users) [![Swift 4.0](https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat)](ttps://developer.apple.com/swift/) [![Platforms OS X | Linux](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat)](https://developer.apple.com/swift/)

Microservice which provides common features for managing users (only RESTful API).
Application is written in [Swift](https://swift.org) and [Vapor](https://vapor.codes).

## Main features

Main features which has been implemented:

- registering new user
- sign-in user (JWT access token & refresh token)
- forgot password
- change password
- update user data
- user roles

*Class diagram*

![model](Images/model.png)

## Getting started

First you need to have [Swift](https://swift.org) installed on your computer. 
Next you should run following commands:

```bash
$ git clone https://github.com/Mikroservices/Users.git
$ cd Users
$ swift package update
$ swift build
```

If application successfully builds you need to set up connection string to the database. 
Service supports only PostgreSQL database. 

```
Variable name:              LETTERER_USERS_CONNECTION_STRING
Value (connection string):  postgresql://user:password@host:5432/database?sslmode=require
```

You can set up this variable as:

1. environment variable in your system
2. environment variable in XCode

Now you can run the application:

```bash
$ .build/debug/Run --port 8001
```

If application starts open following link in your browser: [http://localhost:8001](http://localhost:8001).
You should see blank page with text: *Service is up and running!*. Now you can use API which is described below.

## Configuration

The application uses the default settings. All settings are stored in the database in the `Setting` table.
We can find there following settings:

- `isRecaptchaEnabled` - information about enable/disable Google Recaptcha, it's highly recommended to enable this feature. Recaptcha is validated during user registration process.
- `recaptchaKey` - secret key for Google Recaptcha.
- `jwtPrivateKey` - RSA512 key for generating JWT tokens (signing in). Private key should be entered only in that service. Other services should use only public key.
- `emailServiceAddress` - address to service responsible for sending emails (confirmation email, forgot your password features).

In production environment you *MUST* change especially `jwtPrivateKey`.

## API

Service provides simple RESTful API. Below there is a description of each endpoint.

### Register controller

Controller responsible for registering new user.

#### Create new user

Endpoint for creating new user in the system.

**Request**

```
METHOD: POST
URL: /register
BODY:
{
    "email": "johndoe@email.com",
    "userName": "johndoe",
    "password": "P@ssw0rd",
    "bio": "This is some bio...",
    "location": "London",
    "website": "http://johndoe.io",
    "securityToken": "a712udda8df822d8sa8w8dsac8sa7das8a990c"
}
```

**Response**

```
STATUS: 201 (Created)
BODY:
{
    "id": "19349a02-81c1-4506-b70a-c1b442e2fc1b"
    "email": "johndoe@email.com",
    "userName": "johndoe",
    "bio": "This is some bio...",
    "location": "London",
    "website": "http://johndoe.io",
}
```

**Errors**

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "securityTokenIsMandatory",
    "reason": "Security token is mandatory (it should be provided from Google reCaptcha)."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "securityTokenIsInvalid",
    "reason": "Security token is invalid (Google reCaptcha API returned that information)."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "userNameIsAlreadyTaken",
    "reason": "User with provided user name already exists in the system."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "emailIsAlreadyConnected",
    "reason": "Email is already connected with other account."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "validationError",
    "reason": "[different validation messages for each field]"
}
```

#### Confirm user email

Endpoint should be used for email verification. During creating account special email is sending. In that email there is a link to your website (with `id` and `confirmationGuid` as query parameters). You have to create page which will read that parameters and it should send request to following endpoint. Only after that procedure user can sign-in to the system.

**Request**

```
METHOD: POST
URL: /register/confirm
BODY:
{
    "id": "19349a02-81c1-4506-b70a-c1b442e2fc1b",
    "confirmationGuid": "1bb5118c-6814-4991-8410-de6656b19a2c"
}
```
**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "invalidIdOrToken",
    "reason": "Invalid user Id or token. User have to activate account by reseting his password."
}
```

#### Verify user name

Endpoint can be used to verification if user can use specified user name for his new account. It returns `true` if user name is valid and user can create user with that user name.

**Request**

```
METHOD: POST
URL: /register/username/@{username}
```
**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "result": true
}
```

#### Verify email

Endpoint can be used to verification if user can use specified email for his new account. It returns `true` if email is valid and user can create user with that email.

**Request**

```
METHOD: POST
URL: /register/email/{email}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "result": true
}
```

### Account controller

Controller responsible for managing user account.

#### Sign in to the system

Endpoint for signing in user into the system. It requires user name or email and password. Returns two things:

- `accessToken` - JWT token with basic information about user, signed in by private key from settings.
- `refreshToken` - token which should be used for refreshing access token.

`Refresh token` has a much longer life time (~30 days) then `access token` (~1 hour). You should use `refresh token` for downloading new `access token`.

**Request**

```
METHOD: POST
URL: /account/login
BODY:
{
    "userNameOrEmail": "johndoe@email.com",
    "password": "P@ssw0rd"
}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "accessToken": "4Zo6SK6VFSxrRVN......3ZKcW35jRo43BQShJfBcpleQPY",
    "refreshToken": "himl3VsU0Uq3oFSIF2ihPwwX5NGdQ1TLOs99Ox3p6"
}
```

**Errors**

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "invalidLoginCredentials",
    "reason": "Given user name or password are invalid."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "emailNotConfirmed",
    "reason": "User email is not confirmed. User have to confirm his email first."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "userAccountIsBlocked",
    "reason": "User account is blocked. User cannot login to the system right now."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "internalServerError",
    "reason": "Private key is not configured in database."
}
```

#### Refresh access token

Endpoint for refreshing access token.

**Request**

```
METHOD: POST
URL: /account/refresh
BODY:
{
    "refreshToken": "himl3VsU0Uq3oFSIF2ihPwwX5NGdQ1TLOs99Ox3p6"
}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "accessToken": "GUoSGcqNqsKP7cQd......tE8O5FQN1btqSjhbw5hxH9EBh",
    "refreshToken": "LPB4euZSHaODXJA1W650rvReKwnrBngjEAx2MxCvz"
}
```

**Errors**

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "refreshTokenNotFound",
    "reason": "Refresh token not exists."
}
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "refreshTokenRevoked",
    "reason": "Refresh token was revoked."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "refreshTokenExpired",
    "reason": "Refresh token was expired."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "userAccountIsBlocked",
    "reason": "User account is blocked. User cannot login to the system right now."
}
```

#### Change password

Endpoint for change user password.

**Request**

```
METHOD: POST
URL: /account/change-password
BODY:
{
    "currentPassword": "P@ssw0rd",
    "newPassword": "NewP@ssw0rd"
}
```

**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 401 (Unauthorized)
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "invalidLoginCredentials",
    "reason": "Given user name or password are invalid."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "emailNotConfirmed",
    "reason": "User email is not confirmed. User have to confirm his email first."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "userAccountIsBlocked",
    "reason": "User account is blocked. User cannot login to the system right now."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "validationError",
    "reason": "'newPassword' is less than required minimum of 8 characters and 'newPassword' is not a valid password"
}
```

### Forgot password controller

Controller responsible for forgot password feature.

#### Forgot password

Endpoint is sending email with link to your website. Link in query parameter contains special GUID which have to used in next endpoint.

**Request**

```
METHOD: POST
URL: /forgot/token
BODY:
{
    "email": "johndoe@email.com"
}
```

**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "userAccountIsBlocked",
    "reason": "User account is blocked. You cannot change password right now."
}
```

#### Forgot password

Endpoint is responsible for setting up new password. It requires GUID generated in previous endpoint and new password.

**Request**

```
METHOD: POST
URL: /forgot/confirm
BODY:
{
    "forgotPasswordGuid": "9957D516-761A-4D86-B281-E31F2D707F3B",
    "password": "P@ssw0rd"
}
```

**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "userAccountIsBlocked",
    "reason": "User account is blocked. You cannot change password right now."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "tokenExpired",
    "reason": "Token which allows to change password expired. User have to repeat forgot password process."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "validationError",
    "reason": "'password' is less than required minimum of 8 characters and 'password' is not a valid password"
}
```

### Users controller

Controller responsible for managing user.

#### Get user (profile)

Endpoint returns user data. It's public endpoint. Some data (like email and birth date) are visible only for the owner.

**Request**

```
METHOD: GET
URL: /users/@{username}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "id": "19349a02-81c1-4506-b70a-c1b442e2fc1b"
    "email": "johndoe@email.com",
    "userName": "johndoe",
    "password": "P@ssw0rd",
    "bio": "This is some bio...",
    "location": "London",
    "website": "http://johndoe.io",
}
```

**Errors**

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```

#### Update user data

Endpoint for updating user data.

```
METHOD: PUT
URL: /users/@{username}
BODY:
{
    "id": "19349a02-81c1-4506-b70a-c1b442e2fc1b",
    "email": "johndoe@email.com",
    "userName": "johndoe",
    "bio": "This is some bio...",
    "location": "London",
    "website": "http://johndoe.io"
}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "id": "19349a02-81c1-4506-b70a-c1b442e2fc1b"
    "email": "johndoe@email.com",
    "userName": "johndoe",
    "bio": "This is some bio...",
    "location": "London",
    "website": "http://johndoe.io",
}
```

**Errors**

```
STATUS: 403 (Forbidden)
BODY: 
{
    "error": true,
    "code": "userForbidden",
    "reason": "Access to specified user is forbidden."
}
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "securityTokenIsMandatory",
    "reason": "Security token is mandatory (it should be provided from Google reCaptcha)."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "validationError",
    "reason": "[different validation messages for each field]"
}
```

#### Delete user account

Endpoint for deleting user account.

```
METHOD: DELETE
URL: /users/@{username}
```

**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 403 (Forbidden)
BODY: 
{
    "error": true,
    "code": "userForbidden",
    "reason": "Access to specified user is forbidden."
}
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```

### Roles controller

Controller responsible for managing roles. All endpoints are accessible only for user assigned to role with super privileges.

#### Get roles

Endpoint for downloading user roles.

```
METHOD: GET
URL: /roles
```

**Response**

```
STATUS: 200 (Ok)
BODY:
[
    {
        "id": "jt7390gt-63kt-09fw-b70a-c1b442e2fc1b",
        "name": "Administrator",
        "code": "administrator",
        "description": "This is role for people with high privileges.",
        "hasSuperPrivileges": true,
        "isDefault": false
    },
    {
        "id": "ut85jdnw-93jf-02js-jg92-c1b442e2fc1b",
        "name": "Member",
        "code": "member",
        "description": "Normal user",
        "hasSuperPrivileges": false,
        "isDefault": true
    }
]
```

**Errors**

```
STATUS: 401 (Unauthorize)
```

```
STATUS: 403 (Forbidden)
```

#### Get specific role

Endpoint for downloading specific role data.

```
METHOD: GET
URL: /roles/{id}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "id": "jt7390gt-63kt-09fw-b70a-c1b442e2fc1b",
    "name": "Administrator",
    "code": "administrator",
    "description": "This is role for people with high privileges.",
    "hasSuperPrivileges": true,
    "isDefault": false
}
```

**Errors**

```
STATUS: 401 (Unauthorize)
```

```
STATUS: 403 (Forbidden)
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "incorrectRoleId",
    "reason": "Role id is incorrect."
}
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "roleNotFound",
    "reason": "Role not exists."
}
```

#### Create new role

Endpoint for creating new role.

```
METHOD: POST
URL: /roles
BODY:
{
    "name": "Developer",
    "code": "developer",
    "description": "Some guy who creates code.",
    "hasSuperPrivileges": true,
    "isDefault": false
}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "id": "85kfh37i-kf82-dd92-032d-c1b442e2fc1b",
    "name": "Developer",
    "code": "developer",
    "description": "Some guy who creates code.",
    "hasSuperPrivileges": true,
    "isDefault": false
}
```

**Errors**

```
STATUS: 401 (Unauthorize)
```

```
STATUS: 403 (Forbidden)
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "roleWithCodeExists",
    "reason": "Role with specified code already exists."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "validationError",
    "reason": "[different validation messages for each field]"
}
```

#### Update existing role

Endpoint for updating role.

```
METHOD: PUT
URL: /roles/{id}
BODY:
{
    "id": "85kfh37i-kf82-dd92-032d-c1b442e2fc1b",
    "name": "Senior Developer",
    "code": "senior-developer",
    "description": "Some guy who creates code.",
    "hasSuperPrivileges": true,
    "isDefault": false
}
```

**Response**

```
STATUS: 200 (Ok)
BODY:
{
    "id": "85kfh37i-kf82-dd92-032d-c1b442e2fc1b",
    "name": "Developer",
    "code": "developer",
    "description": "Some guy who creates code.",
    "hasSuperPrivileges": true,
    "isDefault": false
}
```

**Errors**

```
STATUS: 401 (Unauthorize)
```

```
STATUS: 403 (Forbidden)
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "roleWithCodeExists",
    "reason": "Role with specified code already exists."
}
```

```
STATUS: 400 (BadRequest)
BODY: 
{
    "error": true,
    "code": "validationError",
    "reason": "[different validation messages for each field]"
}
```

#### Delete role

Endpoint for deleting role.

```
METHOD: DELETE
URL: /roles/{id}
```

**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 401 (Unauthorize)
```

```
STATUS: 403 (Forbidden)
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "roleNotFound",
    "reason": "Role not exists."
}
```

### User roles controller

Controller responsible for setting up users with appropriate roles.

#### Connect role to user

Endpoint for connecting user to role.

```
METHOD: POST
URL: /user-roles/connect
```

**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 401 (Unauthorize)
```

```
STATUS: 403 (Forbidden)
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "roleNotFound",
    "reason": "Role not exists."
}
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```

#### Disconnect role from user

Endpoint for disconnecting user from role.

```
METHOD: POST
URL: /user-roles/disconnect
```

**Response**

```
STATUS: 200 (Ok)
```

**Errors**

```
STATUS: 401 (Unauthorize)
```

```
STATUS: 403 (Forbidden)
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "roleNotFound",
    "reason": "Role not exists."
}
```

```
STATUS: 404 (NotFound)
BODY: 
{
    "error": true,
    "code": "userNotFound",
    "reason": "User not exists."
}
```
