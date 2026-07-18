package mymoney.delivery.http.plugins

import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.plugins.calllogging.CallLogging
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.cors.routing.CORS
import io.ktor.server.plugins.defaultheaders.DefaultHeaders
import io.ktor.server.plugins.statuspages.StatusPages
import io.ktor.server.response.respond
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
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
