package mymoney.domain.security

/**
 * Generates the 6-digit email-confirmation codes and the hash persisted
 * alongside them. Split out of [TokenService] because the lifetime, length and
 * threat model are different: codes are short, human-typed and rate-limited.
 */
interface VerificationCodeService {
    fun generate(): GeneratedVerificationCode

    /** Deterministic hash used to compare an incoming code against storage. */
    fun hash(plain: String): String
}

data class GeneratedVerificationCode(
    val plaintext: String,
    val hash: String,
)
