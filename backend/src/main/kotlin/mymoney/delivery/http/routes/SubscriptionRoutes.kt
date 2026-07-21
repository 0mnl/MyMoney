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
import mymoney.delivery.http.dto.CreateSubscriptionRequest
import mymoney.delivery.http.dto.UpdateSubscriptionRequest
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.SubscriptionPeriod
import mymoney.domain.usecase.subscription.AdvanceSubscriptionUseCase
import mymoney.domain.usecase.subscription.CreateSubscriptionUseCase
import mymoney.domain.usecase.subscription.DeleteSubscriptionUseCase
import mymoney.domain.usecase.subscription.GetSubscriptionUseCase
import mymoney.domain.usecase.subscription.ListSubscriptionsUseCase
import mymoney.domain.usecase.subscription.UpdateSubscriptionUseCase
import java.util.UUID

fun Route.subscriptionRoutes(
    create: CreateSubscriptionUseCase,
    list: ListSubscriptionsUseCase,
    get: GetSubscriptionUseCase,
    update: UpdateSubscriptionUseCase,
    delete: DeleteSubscriptionUseCase,
    advance: AdvanceSubscriptionUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/subscriptions") {
            post {
                val ctx = call.userContext()
                val body = call.receive<CreateSubscriptionRequest>()
                val created = create.execute(
                    ctx = ctx,
                    id = parseUuid(body.id, "id"),
                    name = body.name,
                    amountKopecks = body.amount,
                    billingPeriod = parsePeriod(body.billingPeriod),
                    nextChargeDate = body.nextChargeDate,
                    categoryId = body.categoryId?.let { parseUuid(it, "categoryId") },
                )
                call.respond(HttpStatusCode.Created, created.toDto())
            }

            get {
                val ctx = call.userContext()
                call.respond(list.execute(ctx).map { it.toDto() })
            }

            get("/{id}") {
                val ctx = call.userContext()
                val id = parseUuid(call.parameters["id"], "id")
                call.respond(get.execute(ctx, id).toDto())
            }

            put("/{id}") {
                val ctx = call.userContext()
                val id = parseUuid(call.parameters["id"], "id")
                val body = call.receive<UpdateSubscriptionRequest>()
                val updated = update.execute(
                    ctx = ctx,
                    id = id,
                    name = body.name,
                    amountKopecks = body.amount,
                    billingPeriod = parsePeriod(body.billingPeriod),
                    nextChargeDate = body.nextChargeDate,
                    categoryId = body.categoryId?.let { parseUuid(it, "categoryId") },
                )
                call.respond(updated.toDto())
            }

            post("/{id}/advance") {
                val ctx = call.userContext()
                val id = parseUuid(call.parameters["id"], "id")
                call.respond(advance.execute(ctx, id).toDto())
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

private fun parsePeriod(raw: String): SubscriptionPeriod =
    runCatching { SubscriptionPeriod.valueOf(raw) }.getOrElse {
        throw ValidationException("billingPeriod must be WEEKLY, MONTHLY, or YEARLY")
    }
