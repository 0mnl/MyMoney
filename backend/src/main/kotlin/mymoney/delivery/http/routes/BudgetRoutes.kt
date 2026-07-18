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
import kotlinx.datetime.Instant
import mymoney.delivery.http.dto.BudgetDto
import mymoney.delivery.http.dto.CreateBudgetRequest
import mymoney.delivery.http.dto.UpdateBudgetRequest
import mymoney.delivery.http.dto.parseBudgetPeriodType
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.usecase.budget.CreateBudgetUseCase
import mymoney.domain.usecase.budget.DeleteBudgetUseCase
import mymoney.domain.usecase.budget.GetBudgetProgressUseCase
import mymoney.domain.usecase.budget.GetBudgetUseCase
import mymoney.domain.usecase.budget.ListBudgetsUseCase
import mymoney.domain.usecase.budget.UpdateBudgetUseCase
import java.util.UUID

fun Route.budgetRoutes(
    create: CreateBudgetUseCase,
    list: ListBudgetsUseCase,
    get: GetBudgetUseCase,
    update: UpdateBudgetUseCase,
    delete: DeleteBudgetUseCase,
    progress: GetBudgetProgressUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/budgets") {

            post {
                val ctx = call.userContext()
                val body = call.receive<CreateBudgetRequest>()
                val created = create.execute(
                    ctx = ctx,
                    id = parseUuidField(body.id, "id"),
                    categoryId = parseUuidField(body.categoryId, "categoryId"),
                    periodType = parseBudgetPeriodType(body.periodType),
                    periodStart = body.periodStart,
                    plannedAmountKopecks = body.plannedAmount,
                )
                call.respond(HttpStatusCode.Created, created.toDto())
            }

            get {
                val ctx = call.userContext()
                val q = call.request.queryParameters
                val items: List<BudgetDto> = list.execute(
                    ctx = ctx,
                    periodType = q["periodType"]?.let { parseBudgetPeriodType(it) },
                    periodStart = q["periodStart"]?.let { parseInstantParam(it, "periodStart") },
                ).map { it.toDto() }
                call.respond(items)
            }

            get("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                call.respond(get.execute(ctx, id).toDto())
            }

            get("/{id}/progress") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                call.respond(progress.execute(ctx, id).toDto())
            }

            put("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPath(call.parameters["id"])
                val body = call.receive<UpdateBudgetRequest>()
                val updated = update.execute(ctx, id, body.plannedAmount)
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

private fun parseInstantParam(raw: String, field: String): Instant = try {
    Instant.parse(raw)
} catch (_: Exception) {
    throw ValidationException("Invalid ISO-8601 instant", mapOf("field" to field))
}
