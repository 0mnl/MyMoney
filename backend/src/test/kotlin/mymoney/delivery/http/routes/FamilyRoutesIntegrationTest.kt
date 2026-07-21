package mymoney.delivery.http.routes

import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import mymoney.delivery.http.dto.AcceptInviteRequest
import mymoney.delivery.http.dto.AcceptInviteResponse
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.FamilyMembersResponse
import mymoney.delivery.http.dto.InviteRequest
import mymoney.delivery.http.dto.InviteResponse
import mymoney.delivery.http.dto.LoginRequest
import mymoney.delivery.http.dto.RefreshRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.module
import mymoney.test.TestPostgres
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class FamilyRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { module() }
    }

    private suspend inline fun <reified T> HttpResponse.decode(): T =
        json.decodeFromString<T>(bodyAsText())

    private suspend fun ApplicationTestBuilder.register(email: String, password: String = "password123") =
        client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(RegisterRequest(email, password)))
        }.decode<AuthSessionResponse>()

    private suspend fun ApplicationTestBuilder.login(email: String, password: String = "password123") =
        client.post("/v1/auth/login") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(LoginRequest(email, password)))
        }.decode<AuthSessionResponse>()

    private suspend fun ApplicationTestBuilder.sendInvite(ownerAccessToken: String, email: String): HttpResponse =
        client.post("/v1/family/invite") {
            header(HttpHeaders.Authorization, "Bearer $ownerAccessToken")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(InviteRequest(email)))
        }

    private suspend fun ApplicationTestBuilder.acceptInvite(accessToken: String, token: String): HttpResponse =
        client.post("/v1/family/accept") {
            header(HttpHeaders.Authorization, "Bearer $accessToken")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(AcceptInviteRequest(token)))
        }

    private fun newEmail(prefix: String) = "$prefix-${UUID.randomUUID()}@example.com"

    @Test
    fun `owner invites and target accepts — acceptor joins the family`() = testApplication {
        setup()
        val ownerEmail = newEmail("owner")
        val memberEmail = newEmail("member")

        val owner = register(ownerEmail)
        val member = register(memberEmail)
        assertNotEquals(owner.familyId, member.familyId, "each user starts in own family")

        val inviteResp = sendInvite(owner.accessToken, memberEmail)
        assertEquals(HttpStatusCode.OK, inviteResp.status)
        val inviteBody = inviteResp.decode<InviteResponse>()
        assertTrue(inviteBody.inviteToken.isNotBlank())

        val acceptResp = acceptInvite(member.accessToken, inviteBody.inviteToken)
        assertEquals(HttpStatusCode.OK, acceptResp.status)
        val acceptBody = acceptResp.decode<AcceptInviteResponse>()
        assertEquals(owner.familyId, acceptBody.familyId)

        // Refresh tokens for the acceptor must be revoked so the next JWT
        // carries the new family_id (see AcceptFamilyInviteUseCase).
        val staleRefresh = client.post("/v1/auth/refresh") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(RefreshRequest(member.refreshToken)))
        }
        assertEquals(HttpStatusCode.Unauthorized, staleRefresh.status)

        val relogged = login(memberEmail)
        assertEquals(owner.familyId, relogged.familyId)

        val members = client.get("/v1/family/members") {
            header(HttpHeaders.Authorization, "Bearer ${owner.accessToken}")
        }.decode<FamilyMembersResponse>()
        assertEquals(2, members.members.size)
        assertTrue(members.members.any { it.userId == owner.userId })
        assertTrue(members.members.any { it.userId == member.userId })
    }

    @Test
    fun `accept fails with unknown token`() = testApplication {
        setup()
        val user = register(newEmail("bad-token"))
        val response = acceptInvite(user.accessToken, "nonexistent-token")
        assertEquals(HttpStatusCode.NotFound, response.status)
    }

    @Test
    fun `accept fails on second use of the same invite token`() = testApplication {
        setup()
        val ownerEmail = newEmail("owner-reuse")
        val firstEmail = newEmail("member-first")
        val secondEmail = newEmail("member-second")

        val owner = register(ownerEmail)
        val first = register(firstEmail)
        val second = register(secondEmail)

        val inviteBody = sendInvite(owner.accessToken, firstEmail).decode<InviteResponse>()
        val firstAccept = acceptInvite(first.accessToken, inviteBody.inviteToken)
        assertEquals(HttpStatusCode.OK, firstAccept.status)

        val secondAccept = acceptInvite(second.accessToken, inviteBody.inviteToken)
        assertEquals(HttpStatusCode.Conflict, secondAccept.status)
    }

    @Test
    fun `owner cannot invite themselves`() = testApplication {
        setup()
        val ownerEmail = newEmail("self")
        val owner = register(ownerEmail)
        val response = sendInvite(owner.accessToken, ownerEmail)
        assertEquals(HttpStatusCode.BadRequest, response.status)
    }

    @Test
    fun `invite fails when target email is not registered`() = testApplication {
        setup()
        val owner = register(newEmail("no-target"))
        val response = sendInvite(owner.accessToken, newEmail("ghost"))
        assertEquals(HttpStatusCode.NotFound, response.status)
    }

    @Test
    fun `family cannot accept a third member`() = testApplication {
        setup()
        val ownerEmail = newEmail("full-owner")
        val secondEmail = newEmail("full-second")
        val thirdEmail = newEmail("full-third")

        val owner = register(ownerEmail)
        val second = register(secondEmail)
        val third = register(thirdEmail)

        val firstInvite = sendInvite(owner.accessToken, secondEmail).decode<InviteResponse>()
        assertEquals(HttpStatusCode.OK, acceptInvite(second.accessToken, firstInvite.inviteToken).status)

        // Owner tries to invite a third — should be blocked.
        val overflow = sendInvite(owner.accessToken, thirdEmail)
        assertEquals(HttpStatusCode.Conflict, overflow.status)
    }
}
