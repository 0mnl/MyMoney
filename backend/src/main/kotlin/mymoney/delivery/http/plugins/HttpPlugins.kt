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
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.DomainException
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.UnauthorizedException
import mymoney.domain.errors.ValidationException
import org.slf4j.event.Level

fun Application.configureHttp() {
    install(DefaultHeaders)

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

    install(CORS) {
        // Restrict in production; open for MVP dev to allow local Flutter debugging.
        anyHost()
        allowHeader(io.ktor.http.HttpHeaders.Authorization)
        allowHeader(io.ktor.http.HttpHeaders.ContentType)
        allowMethod(io.ktor.http.HttpMethod.Options)
        allowMethod(io.ktor.http.HttpMethod.Get)
        allowMethod(io.ktor.http.HttpMethod.Post)
        allowMethod(io.ktor.http.HttpMethod.Put)
        allowMethod(io.ktor.http.HttpMethod.Delete)
    }

    install(StatusPages) {
        exception<DomainException> { call, cause ->
            val status = when (cause) {
                is NotFoundException -> HttpStatusCode.NotFound
                is ValidationException -> HttpStatusCode.BadRequest
                is ConflictException -> HttpStatusCode.Conflict
                is UnauthorizedException -> HttpStatusCode.Unauthorized
                is ForbiddenException -> HttpStatusCode.Forbidden
            }
            call.respond(
                status,
                ErrorResponse(ErrorBody(cause.code, cause.message ?: cause.code, cause.details)),
            )
        }
        exception<Throwable> { call, cause ->
            call.application.log.error("Unhandled exception", cause)
            call.respond(
                HttpStatusCode.InternalServerError,
                ErrorResponse(ErrorBody("INTERNAL_ERROR", cause.message ?: "Unexpected error")),
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
