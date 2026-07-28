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
import mymoney.delivery.http.dto.CreateDebtRequest
import mymoney.delivery.http.dto.UpdateDebtRequest
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.DebtDirection
import mymoney.domain.model.DebtStatus
import mymoney.domain.usecase.debt.CreateDebtUseCase
import mymoney.domain.usecase.debt.DeleteDebtUseCase
import mymoney.domain.usecase.debt.GetDebtUseCase
import mymoney.domain.usecase.debt.ListDebtsUseCase
import mymoney.domain.usecase.debt.UpdateDebtUseCase
import java.util.UUID

fun Route.debtRoutes(
    create: CreateDebtUseCase,
    list: ListDebtsUseCase,
    get: GetDebtUseCase,
    update: UpdateDebtUseCase,
    delete: DeleteDebtUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/debts") {
            post {
                val ctx = call.userContext()
                val body = call.receive<CreateDebtRequest>()
                val created = create.execute(
                    ctx = ctx,
                    id = parseUuid(body.id, "id"),
                    counterpartyName = body.counterpartyName,
                    direction = parseDirection(body.direction),
                    amountKopecks = body.amount,
                    interestRate = body.interestRate,
                    dueDate = body.dueDate,
                )
                call.respond(HttpStatusCode.Created, created.toDto())
            }

            get {
                val ctx = call.userContext()
                val openOnly = call.request.queryParameters["openOnly"] == "true"
                call.respond(list.execute(ctx, openOnly).map { it.toDto() })
            }

            get("/{id}") {
                val ctx = call.userContext()
                val id = parseUuid(call.parameters["id"], "id")
                call.respond(get.execute(ctx, id).toDto())
            }

            put("/{id}") {
                val ctx = call.userContext()
                val id = parseUuid(call.parameters["id"], "id")
                val body = call.receive<UpdateDebtRequest>()
                val updated = update.execute(
                    ctx = ctx,
                    id = id,
                    counterpartyName = body.counterpartyName,
                    amountKopecks = body.amount,
                    interestRate = body.interestRate,
                    dueDate = body.dueDate,
                    status = parseStatus(body.status),
                )
                call.respond(updated.toDto())
            }

            delete("/{id}") {
                val ctx = call.userContext()
                val id = parseUuid(call.parameters["id"], "id")
                delete.execute(ctx, id)
                call.respond(HttpStatusCode.NoContent)
            }
        }
    }
}

private fun parseUuid(raw: String?, field: String): UUID {
    val v = raw ?: throw ValidationException("$field is required")
    return try { UUID.fromString(v) } catch (_: IllegalArgumentException) {
        throw ValidationException("$field is not a UUID")
    }
}

private fun parseDirection(raw: String): DebtDirection = runCatching { DebtDirection.valueOf(raw) }
    .getOrElse { throw ValidationException("direction must be I_OWE or OWED_TO_ME") }

private fun parseStatus(raw: String): DebtStatus = runCatching { DebtStatus.valueOf(raw) }
    .getOrElse { throw ValidationException("status must be OPEN or CLOSED") }
