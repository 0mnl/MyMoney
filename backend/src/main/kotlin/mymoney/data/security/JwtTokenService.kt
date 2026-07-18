package mymoney.data.security

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import kotlinx.datetime.Clock
import kotlinx.datetime.toJavaInstant
import mymoney.config.JwtConfig
import mymoney.domain.security.IssuedAccessToken
import mymoney.domain.security.IssuedRefreshToken
import mymoney.domain.security.TokenService
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Date
import java.util.UUID
import kotlin.time.Duration.Companion.days
import kotlin.time.Duration.Companion.minutes

/**
 * Access tokens: HS256-signed JWTs. Refresh tokens: 256 bits of secure random
 * data (base64url-encoded), stored server-side as SHA-256 hashes so a DB dump
 * cannot be used to forge sessions.
 */
class JwtTokenService(
    private val config: JwtConfig,
    private val clock: Clock = Clock.System,
) : TokenService {

    private val algorithm = Algorithm.HMAC256(config.secret)
    private val secureRandom = SecureRandom()

    override fun issueAccessToken(userId: UUID, familyId: UUID): IssuedAccessToken {
        val now = clock.now()
        val expiresAt = now + config.accessTokenTtlMinutes.minutes
        val token = JWT.create()
            .withIssuer(config.issuer)
            .withAudience(config.audience)
            .withSubject(userId.toString())
            .withClaim("family_id", familyId.toString())
            .withIssuedAt(Date.from(now.toJavaInstant()))
            .withExpiresAt(Date.from(expiresAt.toJavaInstant()))
            .sign(algorithm)
        return IssuedAccessToken(token = token, expiresAt = expiresAt)
    }

    override fun issueRefreshToken(): IssuedRefreshToken {
        val bytes = ByteArray(32).also { secureRandom.nextBytes(it) }
        val plaintext = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
        val hash = hashRefreshToken(plaintext)
        val expiresAt = clock.now() + config.refreshTokenTtlDays.days
        return IssuedRefreshToken(plaintext = plaintext, hash = hash, expiresAt = expiresAt)
    }

    override fun hashRefreshToken(plain: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(plain.toByteArray(Charsets.UTF_8))
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
    }
}
