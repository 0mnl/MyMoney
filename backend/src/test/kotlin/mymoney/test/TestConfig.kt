package mymoney.test

import io.ktor.server.config.MapApplicationConfig
import mymoney.config.AppConfig
import mymoney.config.AppEnv
import mymoney.config.DbConfig
import mymoney.config.HttpConfig
import mymoney.config.JwtConfig
import mymoney.config.MailConfig
import mymoney.config.RegistrationConfig
import org.testcontainers.containers.PostgreSQLContainer

fun testAppConfig(postgres: PostgreSQLContainer<*>): MapApplicationConfig =
    MapApplicationConfig(
        "db.url" to postgres.jdbcUrl,
        "db.user" to postgres.username,
        "db.password" to postgres.password,
        "db.poolSize" to "3",
        "jwt.issuer" to "mymoney-test",
        "jwt.audience" to "mymoney-mobile",
        "jwt.realm" to "mymoney",
        "jwt.secret" to "test-secret-please-do-not-use-in-production-please",
        "jwt.accessTokenTtlMinutes" to "15",
        "jwt.refreshTokenTtlDays" to "30",
    )

/**
 * Готовый [AppConfig] для тестов, которым нужен не весь стартап, а только
 * один плагин (например `configureHttp`). База здесь фиктивная — такие тесты
 * до неё не доходят.
 */
fun devAppConfig(
    registrationAllowlist: List<String> = emptyList(),
): AppConfig = AppConfig(
    env = AppEnv.DEVELOPMENT,
    db = DbConfig(url = "jdbc:postgresql://localhost:5432/unused", user = "u", password = "p", poolSize = 1),
    jwt = JwtConfig(
        issuer = "mymoney-test",
        audience = "mymoney-mobile",
        realm = "mymoney",
        secret = "test-secret-please-do-not-use-in-production-please",
        accessTokenTtlMinutes = 15,
        refreshTokenTtlDays = 30,
    ),
    mail = MailConfig(
        host = "",
        port = 587,
        username = "",
        password = "",
        from = "no-reply@mymoney.local",
        fromName = "MyMoney",
        startTls = true,
        ssl = false,
    ),
    registration = RegistrationConfig(registrationAllowlist),
    http = HttpConfig(allowedOrigins = emptyList()),
)
