package mymoney.delivery.http.routes

import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import kotlinx.datetime.Instant
import mymoney.delivery.http.dto.SyncPushRequest
import mymoney.delivery.http.dto.toDomain
import mymoney.delivery.http.dto.toResponse
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.usecase.sync.PullChangesUseCase
import mymoney.domain.usecase.sync.PushChangesUseCase

fun Route.syncRoutes(
    pull: PullChangesUseCase,
    push: PushChangesUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/sync") {
            get("/pull") {
                val ctx = call.userContext()
                val since = call.request.queryParameters["since"]?.let {
                    runCatching { Instant.parse(it) }.getOrElse {
                        throw ValidationException("Invalid 'since' — must be ISO-8601 UTC")
                    }
                }
                val result = pull.execute(ctx.familyId, since)
                call.respond(HttpStatusCode.OK, result.toResponse())
            }

            post("/push") {
                val ctx = call.userContext()
                val body = call.receive<SyncPushRequest>()
                val outcome = push.execute(ctx.familyId, body.bundle.toDomain())
                call.respond(HttpStatusCode.OK, outcome.toResponse())
            }
        }
    }
}
