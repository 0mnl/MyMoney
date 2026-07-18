package mymoney.delivery.http.routes

import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import mymoney.delivery.http.dto.ArchiveCategoryRequest
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.CategoryDto
import mymoney.delivery.http.dto.CreateCategoryRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.UpdateCategoryRequest
import mymoney.domain.usecase.category.SystemCategoriesCatalog
import mymoney.module
import mymoney.test.TestPostgres
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class CategoryRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private data class TestUser(val familyId: String, val accessToken: String)

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { module() }
    }

    private suspend fun ApplicationTestBuilder.registerUser(): TestUser {
        val email = "cat-${UUID.randomUUID()}@example.com"
        val resp = client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, "password123")))
        }
        val s = json.decodeFromString<AuthSessionResponse>(resp.bodyAsText())
        return TestUser(s.familyId, s.accessToken)
    }

    private suspend fun ApplicationTestBuilder.listCategories(
        user: TestUser,
        query: String = "",
    ): List<CategoryDto> = client.get("/v1/categories$query") {
        header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
    }.let { json.decodeFromString<List<CategoryDto>>(it.bodyAsText()) }

    private suspend fun ApplicationTestBuilder.createCategory(
        user: TestUser,
        id: UUID = UUID.randomUUID(),
        name: String = "Coffee",
        type: String = "EXPENSE",
        parentId: UUID? = null,
        isMandatory: Boolean = false,
    ): HttpResponse = client.post("/v1/categories") {
        header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        contentType(ContentType.Application.Json)
        setBody(
            json.encodeToString<CreateCategoryRequest>(CreateCategoryRequest(
                    id = id.toString(),
                    name = name,
                    type = type,
                    parentCategoryId = parentId?.toString(),
                    isMandatory = isMandatory,
                    icon = null,
                    color = null,
                ),
            ),
        )
    }

    @Test
    fun `newly registered user gets the full system category catalog`() = testApplication {
        setup()
        val user = registerUser()
        val list = listCategories(user)
        assertEquals(SystemCategoriesCatalog.defaults.size, list.size)
        assertTrue(list.all { it.isSystem })
        assertNotNull(list.firstOrNull { it.name == "Продукты" && it.isMandatory })
        assertNotNull(list.firstOrNull { it.name == "Зарплата" && it.type == "INCOME" })
    }

    @Test
    fun `list can filter by type`() = testApplication {
        setup()
        val user = registerUser()
        val incomes = listCategories(user, "?type=INCOME")
        assertTrue(incomes.isNotEmpty())
        assertTrue(incomes.all { it.type == "INCOME" })

        val expenses = listCategories(user, "?type=EXPENSE")
        assertTrue(expenses.isNotEmpty())
        assertTrue(expenses.all { it.type == "EXPENSE" })
    }

    @Test
    fun `create user category and list contains it`() = testApplication {
        setup()
        val user = registerUser()
        val id = UUID.randomUUID()
        val res = createCategory(user, id = id, name = "Coffee shops", type = "EXPENSE")
        assertEquals(HttpStatusCode.Created, res.status)
        val dto = json.decodeFromString<CategoryDto>(res.bodyAsText())
        assertEquals(false, dto.isSystem)
        assertEquals("Coffee shops", dto.name)

        val list = listCategories(user)
        assertNotNull(list.firstOrNull { it.id == id.toString() })
    }

    @Test
    fun `child category rejected when parent type differs`() = testApplication {
        setup()
        val user = registerUser()
        val expenses = listCategories(user, "?type=EXPENSE")
        val expenseParent = expenses.first { it.name == "Продукты" }

        val res = createCategory(
            user,
            id = UUID.randomUUID(),
            name = "Salary bonus",
            type = "INCOME",
            parentId = UUID.fromString(expenseParent.id),
        )
        assertEquals(HttpStatusCode.BadRequest, res.status)
        assertTrue(res.bodyAsText().contains("parentType"))
    }

    @Test
    fun `child of a child is rejected as third level`() = testApplication {
        setup()
        val user = registerUser()
        val list = listCategories(user, "?type=EXPENSE")
        val topLevel = list.first { it.name == "Транспорт" }

        val childId = UUID.randomUUID()
        val createChild = createCategory(
            user,
            id = childId,
            name = "Taxi",
            type = "EXPENSE",
            parentId = UUID.fromString(topLevel.id),
        )
        assertEquals(HttpStatusCode.Created, createChild.status)

        val createGrandchild = createCategory(
            user,
            id = UUID.randomUUID(),
            name = "Yandex Go",
            type = "EXPENSE",
            parentId = childId,
        )
        assertEquals(HttpStatusCode.BadRequest, createGrandchild.status)
        assertTrue(createGrandchild.bodyAsText().contains("two levels"))
    }

    @Test
    fun `system category can be renamed but not deleted`() = testApplication {
        setup()
        val user = registerUser()
        val list = listCategories(user)
        val system = list.first { it.isSystem }

        val rename = client.put("/v1/categories/${system.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<UpdateCategoryRequest>(UpdateCategoryRequest("Renamed", system.isMandatory, null, null)))
        }
        assertEquals(HttpStatusCode.OK, rename.status)

        val delete = client.delete("/v1/categories/${system.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.Conflict, delete.status)
        assertTrue(delete.bodyAsText().contains("SYSTEM_CATEGORY_UNDELETABLE"))
    }

    @Test
    fun `system category can be archived and hidden from default list`() = testApplication {
        setup()
        val user = registerUser()
        val system = listCategories(user).first { it.name == "Прочие поступления" }

        val archived = client.post("/v1/categories/${system.id}/archive") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<ArchiveCategoryRequest>(ArchiveCategoryRequest(true)))
        }
        assertEquals(HttpStatusCode.OK, archived.status)

        val defaultList = listCategories(user)
        assertTrue(defaultList.none { it.id == system.id })

        val withArchived = listCategories(user, "?includeArchived=true")
        assertNotNull(withArchived.firstOrNull { it.id == system.id })
    }

    @Test
    fun `parent with children cannot be deleted`() = testApplication {
        setup()
        val user = registerUser()
        val parentId = UUID.randomUUID()
        val childId = UUID.randomUUID()

        assertEquals(HttpStatusCode.Created, createCategory(user, id = parentId, name = "Food v2").status)
        assertEquals(
            HttpStatusCode.Created,
            createCategory(user, id = childId, name = "Snacks", parentId = parentId).status,
        )

        val res = client.delete("/v1/categories/$parentId") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.Conflict, res.status)
        assertTrue(res.bodyAsText().contains("CATEGORY_HAS_CHILDREN"))

        // Deleting the child first should then allow the parent to be deleted.
        assertEquals(
            HttpStatusCode.NoContent,
            client.delete("/v1/categories/$childId") {
                header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            }.status,
        )
        assertEquals(
            HttpStatusCode.NoContent,
            client.delete("/v1/categories/$parentId") {
                header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            }.status,
        )
    }

    @Test
    fun `cross-family access is forbidden`() = testApplication {
        setup()
        val alice = registerUser()
        val bob = registerUser()
        val aliceCatId = UUID.randomUUID()
        assertEquals(HttpStatusCode.Created, createCategory(alice, id = aliceCatId).status)

        val bobGet = client.get("/v1/categories/$aliceCatId") {
            header(HttpHeaders.Authorization, "Bearer ${bob.accessToken}")
        }
        assertEquals(HttpStatusCode.Forbidden, bobGet.status)
    }

    @Test
    fun `unauthenticated requests are rejected`() = testApplication {
        setup()
        assertEquals(HttpStatusCode.Unauthorized, client.get("/v1/categories").status)
    }

    @Test
    fun `invalid type in query returns 400`() = testApplication {
        setup()
        val user = registerUser()
        val res = client.get("/v1/categories?type=INVEST") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.BadRequest, res.status)
    }
}
