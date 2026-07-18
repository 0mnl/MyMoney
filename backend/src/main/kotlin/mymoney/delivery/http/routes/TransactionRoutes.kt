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
import mymoney.delivery.http.dto.CreateTransactionRequest
import mymoney.delivery.http.dto.TransactionDto
import mymoney.delivery.http.dto.TransactionHistoryEntryDto
import mymoney.delivery.http.dto.UpdateTransactionRequest
import mymoney.delivery.http.dto.parseTransactionType
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.usecase.transaction.CreateTransactionUseCase
import mymoney.domain.usecase.transaction.DeleteTransactionUseCase
import mymoney.domain.usecase.transaction.GetTransactionHistoryUseCase
import mymoney.domain.usecase.transaction.GetTransactionUseCase
import mymoney.domain.usecase.transaction.ListTransactionsUseCase
import mymoney.domain.usecase.transaction.UpdateTransactionUseCase
import java.util.UUID

fun Route.transactionRoutes(
    create: CreateTransactionUseCase,
    list: ListTransactionsUseCase,
    get: GetTransactionUseCase,
    update: UpdateTransactionUseCase,
    delete: DeleteTransactionUseCase,
    history: GetTransactionHistoryUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/transactions") {

            post {
                val ctx = call.userContext()
                val body = call.receive<CreateTransactionRequest>()
                val created = create.execute(
                    ctx = ctx,
                    id = parseUuid(body.id, "id"),
                    accountId = parseUuid(body.accountId, "accountId"),
                    type = parseTransactionType(body.type),
                    amountKopecks = body.amount,
                    occurredAt = body.occurredAt,
                    currency = body.currency,
                    categoryId = body.categoryId?.let { parseUuid(it, "categoryId") },
                    targetAccountId = body.targetAccountId?.let { parseUuid(it, "targetAccountId") },
                    comment = body.comment,
                    attachmentPhotoPath = body.attachmentPhotoPath,
                )
                call.respond(HttpStatusCode.Created, created.toDto())
            }

            get {
                val ctx = call.userContext()
                val q = call.request.queryParameters
                val items: List<TransactionDto> = list.execute(
                    ctx = ctx,
                    accountId = q["accountId"]?.let { parseUuid(it, "accountId") },
                    categoryId = q["categoryId"]?.let { parseUuid(it, "categoryId") },
                    from = q["from"]?.let { parseInstant(it, "from") },
                    to = q["to"]?.let { parseInstant(it, "to") },
                    limit = q["limit"]?.toIntOrNull() ?: 100,
                    offset = q["offset"]?.toLongOrNull() ?: 0,
                ).map { it.toDto() }
                call.respond(items)
            }

            get("/{id}") {
                val ctx = call.userContext()
                val id = pathId(call.parameters["id"])
                call.respond(get.execute(ctx, id).toDto())
            }

            put("/{id}") {
                val ctx = call.userContext()
                val id = pathId(call.parameters["id"])
                val body = call.receive<UpdateTransactionRequest>()
                val updated = update.execute(
                    ctx = ctx,
                    id = id,
                    accountId = parseUuid(body.accountId, "accountId"),
                    type = parseTransactionType(body.type),
                    amountKopecks = body.amount,
                    occurredAt = body.occurredAt,
                    currency = body.currency,
                    categoryId = body.categoryId?.let { parseUuid(it, "categoryId") },
                    targetAccountId = body.targetAccountId?.let { parseUuid(it, "targetAccountId") },
                    comment = body.comment,
                    attachmentPhotoPath = body.attachmentPhotoPath,
                )
                call.respond(updated.toDto())
            }

            delete("/{id}") {
                val ctx = call.userContext()
                val id = pathId(call.parameters["id"])
                delete.execute(ctx, id)
                call.respond(HttpStatusCode.NoContent)
            }

            get("/{id}/history") {
                val ctx = call.userContext()
                val id = pathId(call.parameters["id"])
                val entries: List<TransactionHistoryEntryDto> = history.execute(ctx, id).map { it.toDto() }
                call.respond(entries)
            }
        }
    }
}

private fun parseUuid(raw: String, field: String): UUID = try {
    UUID.fromString(raw)
} catch (_: IllegalArgumentException) {
    throw ValidationException("Invalid UUID", mapOf("field" to field))
}

private fun pathId(raw: String?): UUID {
    if (raw.isNullOrBlank()) {
        throw ValidationException("Path parameter 'id' is required", mapOf("field" to "id"))
    }
    return parseUuid(raw, "id")
}

private fun parseInstant(raw: String, field: String): Instant = try {
    Instant.parse(raw)
} catch (_: Exception) {
    throw ValidationException("Invalid ISO-8601 instant", mapOf("field" to field))
}
