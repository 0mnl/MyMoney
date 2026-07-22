package mymoney.config

import io.ktor.server.config.ApplicationConfig

data class AppConfig(
    val env: AppEnv,
    val db: DbConfig,
    val jwt: JwtConfig,
)

enum class AppEnv { DEVELOPMENT, PRODUCTION }

data class DbConfig(
    val url: String,
    val user: String,
    val password: String,
    val poolSize: Int,
)

data class JwtConfig(
    val issuer: String,
    val audience: String,
    val realm: String,
    val secret: String,
    val accessTokenTtlMinutes: Long,
    val refreshTokenTtlDays: Long,
)

private const val DEV_JWT_SECRET = "dev-only-change-me-in-production"
private const val DEV_DB_PASSWORD = "mymoney_dev_password"

fun loadAppConfig(config: ApplicationConfig): AppConfig {
    val env = when (config.propertyOrNull("app.env")?.getString()?.lowercase()) {
        "production" -> AppEnv.PRODUCTION
        else -> AppEnv.DEVELOPMENT
    }

    val db = DbConfig(
        url = config.property("db.url").getString(),
        user = config.property("db.user").getString(),
        password = config.property("db.password").getString(),
        poolSize = config.property("db.poolSize").getString().toInt(),
    )

    val jwt = JwtConfig(
        issuer = config.property("jwt.issuer").getString(),
        audience = config.property("jwt.audience").getString(),
        realm = config.property("jwt.realm").getString(),
        secret = config.property("jwt.secret").getString(),
        accessTokenTtlMinutes = config.property("jwt.accessTokenTtlMinutes").getString().toLong(),
        refreshTokenTtlDays = config.property("jwt.refreshTokenTtlDays").getString().toLong(),
    )

    if (env == AppEnv.PRODUCTION) {
        require(jwt.secret != DEV_JWT_SECRET) {
            "JWT_SECRET is set to the built-in dev value in production. Set env var JWT_SECRET to a strong random string (>= 32 bytes)."
        }
        require(jwt.secret.length >= 32) {
            "JWT_SECRET must be at least 32 characters long in production."
        }
        require(db.password != DEV_DB_PASSWORD) {
            "DB_PASSWORD is set to the built-in dev value in production. Set env var DB_PASSWORD to a strong random string."
        }
    }

    return AppConfig(env = env, db = db, jwt = jwt)
}
