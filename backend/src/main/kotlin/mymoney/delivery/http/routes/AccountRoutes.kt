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
import mymoney.delivery.http.dto.AccountDto
import mymoney.delivery.http.dto.ArchiveAccountRequest
import mymoney.delivery.http.dto.CreateAccountRequest
import mymoney.delivery.http.dto.UpdateAccountRequest
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.usecase.account.ArchiveAccountUseCase
import mymoney.domain.usecase.account.CreateAccountUseCase
import mymoney.domain.usecase.account.DeleteAccountUseCase
import mymoney.domain.usecase.account.GetAccountUseCase
import mymoney.domain.usecase.account.ListAccountsUseCase
import mymoney.domain.usecase.account.UpdateAccountUseCase
import java.util.UUID

fun Route.accountRoutes(
    create: CreateAccountUseCase,
    list: ListAccountsUseCase,
    get: GetAccountUseCase,
    update: UpdateAccountUseCase,
    archive: ArchiveAccountUseCase,
    delete: DeleteAccountUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/accounts") {

            post {
                val ctx = call.userContext()
                val body = call.receive<CreateAccountRequest>()
                val account = create.execute(
                    ctx = ctx,
                    id = parseUuid(body.id, "id"),
                    name = body.name,
                    type = body.type,
                    currency = body.currency,
                    initialBalanceKopecks = body.initialBalance,
                )
                call.respond(HttpStatusCode.Created, account.toDto())
            }

            get {
                val ctx = call.userContext()
                val includeArchived = call.request.queryParameters["includeArchived"]
                    ?.toBooleanStrictOrNull() ?: false
                val items: List<AccountDto> = list.execute(ctx, includeArchived).map { it.toDto() }
                call.respond(items)
            }

            get("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidParam(call.parameters["id"])
                call.respond(get.execute(ctx, id).toDto())
            }

            put("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidParam(call.parameters["id"])
                val body = call.receive<UpdateAccountRequest>()
                val updated = update.execute(
                    ctx = ctx,
                    id = id,
                    name = body.name,
                    type = body.type,
                    currency = body.currency,
                    initialBalanceKopecks = body.initialBalance,
                )
                call.respond(updated.toDto())
            }

            post("/{id}/archive") {
                val ctx = call.userContext()
                val id = parseUuidParam(call.parameters["id"])
                val body = call.receive<ArchiveAccountRequest>()
                val updated = archive.execute(ctx, id, body.archived)
                call.respond(updated.toDto())
            }

            delete("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidParam(call.parameters["id"])
                delete.execute(ctx, id)
                call.respond(HttpStatusCode.NoContent)
            }
        }
    }
}

private fun parseUuid(raw: String, field: String): UUID = try {
    UUID.fromString(raw)
} catch (_: IllegalArgumentException) {
    throw ValidationException("Invalid UUID", mapOf("field" to field))
}

private fun parseUuidParam(raw: String?): UUID {
    if (raw.isNullOrBlank()) throw ValidationException("Path parameter 'id' is required", mapOf("field" to "id"))
    return parseUuid(raw, "id")
}
