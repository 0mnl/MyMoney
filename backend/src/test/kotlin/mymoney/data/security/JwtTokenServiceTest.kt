package mymoney.data.security

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import mymoney.config.JwtConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class JwtTokenServiceTest {

    private val config = JwtConfig(
        issuer = "mymoney-test",
        audience = "mymoney-mobile",
        realm = "mymoney",
        secret = "test-secret-please-do-not-use-in-production-please",
        accessTokenTtlMinutes = 15,
        refreshTokenTtlDays = 30,
    )

    private val service = JwtTokenService(config)

    @Test
    fun `access token carries expected claims and verifies with same secret`() {
        val userId = UUID.randomUUID()
        val familyId = UUID.randomUUID()

        val issued = service.issueAccessToken(userId, familyId)

        val decoded = JWT.require(Algorithm.HMAC256(config.secret))
            .withIssuer(config.issuer)
            .withAudience(config.audience)
            .build()
            .verify(issued.token)

        assertEquals(userId.toString(), decoded.subject)
        assertEquals(familyId.toString(), decoded.getClaim("family_id").asString())
        assertNotNull(decoded.expiresAt)
    }

    @Test
    fun `refresh token plaintext differs between calls but hash is deterministic for same input`() {
        val a = service.issueRefreshToken()
        val b = service.issueRefreshToken()
        assertNotEquals(a.plaintext, b.plaintext)
        assertNotEquals(a.hash, b.hash)
        assertEquals(a.hash, service.hashRefreshToken(a.plaintext))
        assertEquals(b.hash, service.hashRefreshToken(b.plaintext))
    }

    @Test
    fun `hash is base64 url safe and reasonably long`() {
        val issued = service.issueRefreshToken()
        assertTrue(issued.hash.length >= 40, "hash too short: ${issued.hash}")
        assertTrue(issued.hash.all { it.isLetterOrDigit() || it == '-' || it == '_' }, "not base64url: ${issued.hash}")
    }
}
