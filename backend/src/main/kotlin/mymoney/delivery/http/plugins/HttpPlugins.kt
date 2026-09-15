package mymoney.delivery.http.plugins

import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.application.log
import io.ktor.server.plugins.calllogging.CallLogging
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.cors.routing.CORS
import io.ktor.server.plugins.defaultheaders.DefaultHeaders
import io.ktor.server.plugins.statuspages.StatusPages
import io.ktor.server.response.respond
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import mymoney.config.AppConfig
import mymoney.config.AppEnv
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.DomainException
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.TooManyRequestsException
import mymoney.domain.errors.UnauthorizedException
import mymoney.domain.errors.ValidationException
import org.slf4j.event.Level

fun Application.configureHttp(config: AppConfig) {
    val isProduction = config.env == AppEnv.PRODUCTION

    install(DefaultHeaders) {
        // Заголовок Server выдаёт версию Ktor/Netty — бесплатная подсказка
        // тому, кто подбирает известные уязвимости под конкретную версию.
        header(io.ktor.http.HttpHeaders.Server, "MyMoney")
    }

    install(CallLogging) {
        level = Level.INFO
    }

    install(ContentNegotiation) {
        json(
            Json {
                prettyPrint = false
                ignoreUnknownKeys = true
                encodeDefaults = true
            },
        )
    }

    // CORS — ограничение браузера, мобильному клиенту он не нужен вообще:
    // Dio ходит напрямую и preflight не делает. Поэтому в проде плагин
    // ставится только если явно перечислены источники (появится веб-клиент),
    // а по умолчанию не ставится вовсе — так `anyHost()` не может случайно
    // доехать до продакшена и разрешить любому сайту дёргать API из браузера
    // жертвы. В dev остаётся открытым, иначе не отладить Flutter Web.
    if (!isProduction || config.http.allowedOrigins.isNotEmpty()) {
        install(CORS) {
            if (isProduction) {
                config.http.allowedOrigins.forEach { origin ->
                    val scheme = origin.substringBefore("://", missingDelimiterValue = "https")
                    val host = origin.substringAfter("://")
                    allowHost(host, schemes = listOf(scheme))
                }
            } else {
                anyHost()
            }
            allowHeader(io.ktor.http.HttpHeaders.Authorization)
            allowHeader(io.ktor.http.HttpHeaders.ContentType)
            allowMethod(io.ktor.http.HttpMethod.Options)
            allowMethod(io.ktor.http.HttpMethod.Get)
            allowMethod(io.ktor.http.HttpMethod.Post)
            allowMethod(io.ktor.http.HttpMethod.Put)
            allowMethod(io.ktor.http.HttpMethod.Delete)
        }
    }

    install(StatusPages) {
        exception<DomainException> { call, cause ->
            val status = when (cause) {
                is NotFoundException -> HttpStatusCode.NotFound
                is ValidationException -> HttpStatusCode.BadRequest
                is ConflictException -> HttpStatusCode.Conflict
                is UnauthorizedException -> HttpStatusCode.Unauthorized
                is ForbiddenException -> HttpStatusCode.Forbidden
                is TooManyRequestsException -> HttpStatusCode.TooManyRequests
            }
            call.respond(
                status,
                ErrorResponse(ErrorBody(cause.code, cause.message ?: cause.code, cause.details)),
            )
        }
        exception<Throwable> { call, cause ->
            call.application.log.error("Unhandled exception", cause)
            // Текст исключения наружу отдаём только в dev. В проде сообщения
            // вроде «ERROR: relation "account" does not exist» или куска SQL
            // с именами колонок — это бесплатная разведка схемы для того, кто
            // перебирает запросы. Разработчику они всё ещё доступны в логе.
            val message = if (isProduction) "Unexpected error" else cause.message ?: "Unexpected error"
            call.respond(
                HttpStatusCode.InternalServerError,
                ErrorResponse(ErrorBody("INTERNAL_ERROR", message)),
            )
        }
    }
}

@Serializable
data class ErrorResponse(val error: ErrorBody)

@Serializable
data class ErrorBody(
    val code: String,
    val message: String,
    val details: Map<String, String> = emptyMap(),
)
