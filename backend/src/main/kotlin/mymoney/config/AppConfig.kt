package mymoney.config

import io.ktor.server.config.ApplicationConfig

data class AppConfig(
    val db: DbConfig,
    val jwt: JwtConfig,
)

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

fun loadAppConfig(config: ApplicationConfig): AppConfig = AppConfig(
    db = DbConfig(
        url = config.property("db.url").getString(),
        user = config.property("db.user").getString(),
        password = config.property("db.password").getString(),
        poolSize = config.property("db.poolSize").getString().toInt(),
    ),
    jwt = JwtConfig(
        issuer = config.property("jwt.issuer").getString(),
        audience = config.property("jwt.audience").getString(),
        realm = config.property("jwt.realm").getString(),
        secret = config.property("jwt.secret").getString(),
        accessTokenTtlMinutes = config.property("jwt.accessTokenTtlMinutes").getString().toLong(),
        refreshTokenTtlDays = config.property("jwt.refreshTokenTtlDays").getString().toLong(),
    ),
)
