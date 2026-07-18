package mymoney.delivery.http.routes

import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.delete
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.put
import io.ktor.server.routing.route
import mymoney.delivery.http.dto.CreateGoalRequest
import mymoney.delivery.http.dto.GoalContributionRequest
import mymoney.delivery.http.dto.GoalDto
import mymoney.delivery.http.dto.UpdateGoalRequest
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.usecase.goal.ContributeGoalUseCase
import mymoney.domain.usecase.goal.CreateGoalUseCase
import mymoney.domain.usecase.goal.DeleteGoalUseCase
import mymoney.domain.usecase.goal.GetGoalUseCase
import mymoney.domain.usecase.goal.ListGoalsUseCase
import mymoney.domain.usecase.goal.UpdateGoalUseCase
import java.util.UUID

fun Route.goalRoutes(
    create: CreateGoalUseCase,
    list: ListGoalsUseCase,
    get: GetGoalUseCase,
    update: UpdateGoalUseCase,
    delete: DeleteGoalUseCase,
    contribute: ContributeGoalUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/goals") {

            post {
                val ctx = call.userContext()
                val body = call.receive<CreateGoalRequest>()
                val created = create.execute(
                    ctx = ctx,
                    id = parseUuidField(body.id, "id"),
                    name = body.name,
                    targetAmountKopecks = body.targetAmount,
                    currentAmountKopecks = body.currentAmount,
                    targetDate = body.targetDate,
                )
                call.respond(HttpStatusCode.Created, created.toDto())
            }

            get {
                val ctx = call.userContext()
                val items: List<GoalDto> = list.execute(ctx).map { it.toDto() }
                call.respond(items)
            }

            get("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                call.respond(get.execute(ctx, id).toDto())
            }

            put("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                val body = call.receive<UpdateGoalRequest>()
                val updated = update.execute(
                    ctx = ctx,
                    id = id,
                    name = body.name,
                    targetAmountKopecks = body.targetAmount,
                    targetDate = body.targetDate,
                )
                call.respond(updated.toDto())
            }

            post("/{id}/deposit") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                val body = call.receive<GoalContributionRequest>()
                val updated = contribute.execute(ctx, id, body.amount, deposit = true)
                call.respond(updated.toDto())
            }

            post("/{id}/withdraw") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                val body = call.receive<GoalContributionRequest>()
                val updated = contribute.execute(ctx, id, body.amount, deposit = false)
                call.respond(updated.toDto())
            }

            delete("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                delete.execute(ctx, id)
                call.respond(HttpStatusCode.NoContent)
            }
        }
    }
}

private fun parseUuidField(raw: String, field: String): UUID = try {
    UUID.fromString(raw)
} catch (_: IllegalArgumentException) {
    throw ValidationException("Invalid UUID", mapOf("field" to field))
}

private fun parseUuidPath(raw: String?): UUID {
    if (raw.isNullOrBlank()) throw ValidationException("Path parameter 'id' is required", mapOf("field" to "id"))
    return parseUuidField(raw, "id")
}
