package mymoney.config

import io.ktor.server.config.ApplicationConfig

data class AppConfig(
    val env: AppEnv,
    val db: DbConfig,
    val jwt: JwtConfig,
    val mail: MailConfig,
    val registration: RegistrationConfig,
    val http: HttpConfig,
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

/**
 * Настройки SMTP. Пустой [host] означает «почта не настроена» — в этом
 * случае приложение остаётся на [mymoney.data.notification.LoggingVerificationCodeSender],
 * который пишет коды в лог вместо отправки писем.
 */
data class MailConfig(
    val host: String,
    val port: Int,
    val username: String,
    val password: String,
    val from: String,
    val fromName: String,
    val startTls: Boolean,
    val ssl: Boolean,
) {
    val isConfigured: Boolean get() = host.isNotBlank()
}

/**
 * Кто вообще может завести аккаунт на этом сервере.
 *
 * [entries] — список из переменной `REGISTRATION_ALLOWLIST`, по запятой.
 * Элемент либо полный адрес (`ivan@example.com`), либо домен (`@example.com`)
 * — тогда пускаются все адреса этого домена.
 *
 * **Пустой список означает открытую регистрацию.** Это осознанный дефолт:
 * сервер для одного человека и публичный сервис — один и тот же код, а
 * «закрыто по умолчанию» сломало бы разработку и тесты, где список задавать
 * неоткуда. Прод пишет предупреждение в лог, если список пуст (см.
 * [loadAppConfig]), так что открытая регистрация не может включиться молча.
 */
data class RegistrationConfig(val entries: List<String>) {
    val isRestricted: Boolean get() = entries.isNotEmpty()

    companion object {
        fun parse(raw: String?): RegistrationConfig = RegistrationConfig(
            raw.orEmpty()
                .split(',')
                .map { it.trim().lowercase() }
                .filter { it.isNotBlank() },
        )
    }
}

/**
 * Настройки самого HTTP-слоя.
 *
 * [allowedOrigins] — источники для CORS. Мобильному клиенту CORS не нужен
 * вовсе (это ограничение браузера), поэтому пустой список в проде —
 * нормальное и самое безопасное состояние. Заполнять только если появится
 * веб-клиент.
 */
data class HttpConfig(val allowedOrigins: List<String>)

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

    val mail = MailConfig(
        host = config.propertyOrNull("mail.host")?.getString().orEmpty().trim(),
        port = config.propertyOrNull("mail.port")?.getString()?.toIntOrNull() ?: 587,
        username = config.propertyOrNull("mail.username")?.getString().orEmpty(),
        password = config.propertyOrNull("mail.password")?.getString().orEmpty(),
        from = config.propertyOrNull("mail.from")?.getString() ?: "no-reply@mymoney.local",
        fromName = config.propertyOrNull("mail.fromName")?.getString() ?: "MyMoney",
        startTls = config.propertyOrNull("mail.startTls")?.getString()?.toBoolean() ?: true,
        ssl = config.propertyOrNull("mail.ssl")?.getString()?.toBoolean() ?: false,
    )

    val registration = RegistrationConfig.parse(
        config.propertyOrNull("registration.allowlist")?.getString(),
    )

    val http = HttpConfig(
        allowedOrigins = config.propertyOrNull("http.allowedOrigins")?.getString()
            .orEmpty()
            .split(',')
            .map { it.trim() }
            .filter { it.isNotBlank() },
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
        // Без почты в проде регистрация мертва: код подтверждения ушёл бы
        // только в лог сервера, а пользователь остался бы с неподтверждённым
        // аккаунтом. Падать на старте лучше, чем принимать регистрации в никуда.
        require(mail.isConfigured) {
            "MAIL_HOST is not set in production. Confirmation codes would only be written to the log and no user could complete registration. Set MAIL_HOST/MAIL_PORT/MAIL_USERNAME/MAIL_PASSWORD."
        }
    }

    return AppConfig(
        env = env,
        db = db,
        jwt = jwt,
        mail = mail,
        registration = registration,
        http = http,
    )
}
