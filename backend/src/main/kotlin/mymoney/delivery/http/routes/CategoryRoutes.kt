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
import mymoney.delivery.http.dto.ArchiveCategoryRequest
import mymoney.delivery.http.dto.CategoryDto
import mymoney.delivery.http.dto.CreateCategoryRequest
import mymoney.delivery.http.dto.UpdateCategoryRequest
import mymoney.delivery.http.dto.parseCategoryType
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.errors.ValidationException
import mymoney.domain.usecase.category.ArchiveCategoryUseCase
import mymoney.domain.usecase.category.CreateCategoryUseCase
import mymoney.domain.usecase.category.DeleteCategoryUseCase
import mymoney.domain.usecase.category.GetCategoryUseCase
import mymoney.domain.usecase.category.ListCategoriesUseCase
import mymoney.domain.usecase.category.UpdateCategoryUseCase
import java.util.UUID

fun Route.categoryRoutes(
    create: CreateCategoryUseCase,
    list: ListCategoriesUseCase,
    get: GetCategoryUseCase,
    update: UpdateCategoryUseCase,
    archive: ArchiveCategoryUseCase,
    delete: DeleteCategoryUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/categories") {

            post {
                val ctx = call.userContext()
                val body = call.receive<CreateCategoryRequest>()
                val created = create.execute(
                    ctx = ctx,
                    id = parseUuidField(body.id, "id"),
                    name = body.name,
                    type = parseCategoryType(body.type),
                    parentCategoryId = body.parentCategoryId?.let { parseUuidField(it, "parentCategoryId") },
                    isMandatory = body.isMandatory,
                    icon = body.icon,
                    color = body.color,
                )
                call.respond(HttpStatusCode.Created, created.toDto())
            }

            get {
                val ctx = call.userContext()
                val type = call.request.queryParameters["type"]?.let { parseCategoryType(it) }
                val includeArchived = call.request.queryParameters["includeArchived"]
                    ?.toBooleanStrictOrNull() ?: false
                val items: List<CategoryDto> = list.execute(ctx, type, includeArchived).map { it.toDto() }
                call.respond(items)
            }

            get("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPathParam(call.parameters["id"])
                call.respond(get.execute(ctx, id).toDto())
            }

            put("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPathParam(call.parameters["id"])
                val body = call.receive<UpdateCategoryRequest>()
                val updated = update.execute(
                    ctx = ctx,
                    id = id,
                    name = body.name,
                    isMandatory = body.isMandatory,
                    icon = body.icon,
                    color = body.color,
                )
                call.respond(updated.toDto())
            }

            post("/{id}/archive") {
                val ctx = call.userContext()
                val id = parseUuidPathParam(call.parameters["id"])
                val body = call.receive<ArchiveCategoryRequest>()
                val updated = archive.execute(ctx, id, body.archived)
                call.respond(updated.toDto())
            }

            delete("/{id}") {
                val ctx = call.userContext()
                val id = parseUuidPathParam(call.parameters["id"])
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

private fun parseUuidPathParam(raw: String?): UUID {
    if (raw.isNullOrBlank()) {
        throw ValidationException("Path parameter 'id' is required", mapOf("field" to "id"))
    }
    return parseUuidField(raw, "id")
}
