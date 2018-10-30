import FluentSQLite
import Vapor
import VaporRecaptcha

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Register providers first
    try services.register(FluentSQLiteProvider())

    // Register custom services.
    guard let privateKey = Environment.get("LETTERER_PRIVATE_KEY") else { throw Abort(.internalServerError) }
    services.register { container -> SecureKeyStorage in
        return SecureKeyStorage(privateKey: privateKey)
    }

    // Register reCaptcha.
    guard let recaptchaKey = Environment.get("LETTERER_RECAPTCHA_KEY") else { throw Abort(.internalServerError) }
    let captchaConfig = CaptchaConfig(secretKey: recaptchaKey)
    try services.register(CaptchaProvider(config: captchaConfig))

    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    /// Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    /// middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)

    // Configure a SQLite database
    guard let sqliteFilePath  = Environment.get("LETTERER_SQLITE_PATH") else { throw Abort(.internalServerError) }
    let sqlite = try SQLiteDatabase(storage: .file(path: sqliteFilePath))

    /// Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: sqlite, as: .sqlite)
    services.register(databases)

    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .sqlite)
    services.register(migrations)
}
