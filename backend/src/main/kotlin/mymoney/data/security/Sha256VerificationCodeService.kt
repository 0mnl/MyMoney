package mymoney.data.security

import mymoney.domain.security.GeneratedVerificationCode
import mymoney.domain.security.VerificationCodeService
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Six digits from [SecureRandom], stored as SHA-256. A plain digest is enough
 * here (unlike passwords) because the code is high-entropy relative to its
 * 10-minute lifetime and capped attempt count — see VerifyEmailUseCase.
 */
class Sha256VerificationCodeService(
    private val random: SecureRandom = SecureRandom(),
) : VerificationCodeService {

    override fun generate(): GeneratedVerificationCode {
        val value = random.nextInt(1_000_000)
        val plaintext = value.toString().padStart(CODE_LENGTH, '0')
        return GeneratedVerificationCode(plaintext = plaintext, hash = hash(plaintext))
    }

    override fun hash(plain: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(plain.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    companion object {
        const val CODE_LENGTH = 6
    }
}
