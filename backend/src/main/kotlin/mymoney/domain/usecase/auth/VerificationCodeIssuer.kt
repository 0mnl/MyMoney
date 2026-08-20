package mymoney.domain.usecase.auth

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.repository.EmailVerificationRepository
import mymoney.domain.security.VerificationCodeService
import java.util.UUID
import kotlin.time.Duration.Companion.minutes

/**
 * Issues and delivers confirmation codes. Every path that can cause an email
 * to be sent — registration, re-registration on an unconfirmed address, and
 * the explicit resend — goes through here, so the cooldown cannot be bypassed
 * by picking a different endpoint. Without that, `/auth/register` would let
 * anyone flood an address they do not own.
 *
 * Any previously issued code is consumed before a new one is stored: a user
 * who requests a new code must use the newest one, and an old code left in an
 * inbox stops working.
 */
class VerificationCodeIssuer(
    private val codes: EmailVerificationRepository,
    private val codeService: VerificationCodeService,
    private val sender: VerificationCodeSender,
    private val clock: Clock = Clock.System,
) {

    /**
     * Sends a fresh code unless the active one is still inside its cooldown,
     * in which case nothing is sent and the existing code stays valid.
     * Callers decide whether that is an error ([ResendVerificationCodeUseCase]
     * reports 429) or simply the answer ([RegisterUserUseCase] returns the
     * timings of the code already in the user's inbox).
     */
    suspend fun issue(userId: UUID, email: String): IssueResult {
        val now = clock.now()

        val active = codes.findActiveByUser(userId)
        if (active != null && active.expiresAt > now) {
            val nextAllowedAt = active.createdAt.plus(RESEND_COOLDOWN)
            if (now < nextAllowedAt) {
                return IssueResult(
                    codeExpiresAt = active.expiresAt,
                    resendAvailableAt = nextAllowedAt,
                    sent = false,
                )
            }
        }

        codes.consumeAllForUser(userId, now)

        val generated = codeService.generate()
        val expiresAt = now.plus(CODE_TTL)
        codes.create(
            id = UUID.randomUUID(),
            userId = userId,
            codeHash = generated.hash,
            expiresAt = expiresAt,
            createdAt = now,
        )
        sender.send(email, generated.plaintext, expiresAt)

        return IssueResult(
            codeExpiresAt = expiresAt,
            resendAvailableAt = now.plus(RESEND_COOLDOWN),
            sent = true,
        )
    }

    companion object {
        val CODE_TTL = 10.minutes

        /** Wrong-code tries allowed per issued code before it is burned. */
        const val MAX_ATTEMPTS = 5

        /** Minimum gap between two sends. Mirrored by the client's countdown. */
        val RESEND_COOLDOWN = 1.minutes
    }
}

data class IssueResult(
    val codeExpiresAt: Instant,
    val resendAvailableAt: Instant,
    /** False when the cooldown suppressed the send and the old code still stands. */
    val sent: Boolean,
) {
    fun toPending(email: String) = PendingRegistration(
        email = email,
        codeExpiresAt = codeExpiresAt,
        resendAvailableAt = resendAvailableAt,
    )
}
