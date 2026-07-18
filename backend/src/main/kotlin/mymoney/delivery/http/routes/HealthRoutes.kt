package mymoney.delivery.http.routes

import io.ktor.http.HttpStatusCode
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import kotlinx.serialization.Serializable
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.transactions.transaction

fun Route.healthRoutes(database: Database?) {
    get("/healthz") {
        val dbStatus = if (database == null) {
            "disabled"
        } else {
            runCatching {
                transaction(database) { exec("SELECT 1") { it.next(); it.getInt(1) } }
                "up"
            }.getOrElse { "down" }
        }
        val status = if (dbStatus == "down") HttpStatusCode.ServiceUnavailable else HttpStatusCode.OK
        call.respond(status, HealthResponse(status = "ok", db = dbStatus))
    }
}

@Serializable
data class HealthResponse(
    val status: String,
    val db: String,
)
