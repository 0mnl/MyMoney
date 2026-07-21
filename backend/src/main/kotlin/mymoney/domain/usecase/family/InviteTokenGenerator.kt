package mymoney.domain.usecase.family

import java.security.SecureRandom
import java.util.Base64

/**
 * Opaque, URL-safe single-use tokens for family invites.
 * 32 bytes of secure random data → 43 char base64url string.
 */
class InviteTokenGenerator(private val secureRandom: SecureRandom = SecureRandom()) {
    fun generate(): String {
        val bytes = ByteArray(32).also { secureRandom.nextBytes(it) }
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }
}
