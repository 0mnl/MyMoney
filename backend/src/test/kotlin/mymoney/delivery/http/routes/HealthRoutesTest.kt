package mymoney.delivery.http.routes

import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.server.routing.routing
import io.ktor.server.testing.testApplication
import mymoney.delivery.http.plugins.configureHttp
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HealthRoutesTest {

    @Test
    fun `healthz returns ok when database is null (disabled)`() = testApplication {
        application {
            configureHttp()
            routing {
                healthRoutes(database = null)
            }
        }

        val response = client.get("/healthz")

        assertEquals(HttpStatusCode.OK, response.status)
        val body = response.bodyAsText()
        assertTrue(body.contains("\"status\":\"ok\""), "body: $body")
        assertTrue(body.contains("\"db\":\"disabled\""), "body: $body")
    }
}
