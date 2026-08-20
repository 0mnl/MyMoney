package mymoney.domain.usecase.auth

import kotlinx.datetime.Clock
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.TooManyRequestsException
import mymoney.domain.errors.UnauthorizedException
import mymoney.domain.errors.ValidationException
import mymoney.domain.repository.EmailVerificationRepository
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.security.TokenService
import mymoney.domain.security.VerificationCodeService
import java.util.UUID

/**
 * Exchanges a confirmation code for a real session. This — not /auth/register —
 * is where the client first receives tokens, so an unconfirmed address can
 * never reach the app.
 *
 * Failure codes are distinct on purpose: the confirmation screen shows
 * different copy for a wrong code, an expired one and a burned one.
 */
class VerifyEmailUseCase(
    private val users: UserRepository,
    private val members: FamilyMemberRepository,
    private val codes: EmailVerificationRepository,
    private val refreshTokens: RefreshTokenRepository,
    private val codeService: VerificationCodeService,
    private val tokenService: TokenService,
    private val clock: Clock = Clock.System,
) {

    suspend fun execute(rawEmail: String, code: String): AuthSession {
        val email = normalizeEmail(rawEmail)
        val user = users.findByEmail(email)
            ?: throw UnauthorizedException("Invalid email or code")

        if (users.isEmailVerified(user.id)) {
            throw ConflictException(
                code = "EMAIL_ALREADY_VERIFIED",
                msg = "Email is already confirmed",
                details = mapOf("email" to email),
            )
        }

        val active = codes.findActiveByUser(user.id)
            ?: throw ValidationException(
                msg = "No active confirmation code — request a new one",
                code = "CODE_EXPIRED",
            )

        val now = clock.now()
        if (active.expiresAt <= now) {
            codes.markConsumed(active.id, now)
            throw ValidationException(
                msg = "Confirmation code expired — request a new one",
                code = "CODE_EXPIRED",
            )
        }

        if (active.attempts >= VerificationCodeIssuer.MAX_ATTEMPTS) {
            codes.markConsumed(active.id, now)
            throw TooManyRequestsException(
                msg = "Too many wrong codes — request a new one",
                code = "TOO_MANY_ATTEMPTS",
            )
        }

        if (codeService.hash(code.trim()) != active.codeHash) {
            val attempts = codes.incrementAttempts(active.id)
            val remaining = (VerificationCodeIssuer.MAX_ATTEMPTS - attempts).coerceAtLeast(0)
            throw ValidationException(
                msg = "Invalid confirmation code",
                details = mapOf("attemptsLeft" to remaining.toString()),
                code = "INVALID_CODE",
            )
        }

        codes.markConsumed(active.id, now)
        users.markEmailVerified(user.id, now)

        val familyId = members.listByUser(user.id).firstOrNull()?.familyId
            ?: throw UnauthorizedException("User has no family membership")

        return issueSession(
            userId = user.id,
            familyId = familyId,
            tokenService = tokenService,
            refreshTokens = refreshTokens,
        )
    }
}

/**
 * Mints an access + refresh pair and persists the refresh hash. Shared by
 * login and email confirmation so both produce identical sessions.
 */
internal suspend fun issueSession(
    userId: UUID,
    familyId: UUID,
    tokenService: TokenService,
    refreshTokens: RefreshTokenRepository,
): AuthSession {
    val access = tokenService.issueAccessToken(userId, familyId)
    val refresh = tokenService.issueRefreshToken()
    refreshTokens.create(
        id = UUID.randomUUID(),
        userId = userId,
        tokenHash = refresh.hash,
        expiresAt = refresh.expiresAt,
    )
    return AuthSession(
        userId = userId,
        familyId = familyId,
        tokens = AuthTokens(
            accessToken = access.token,
            refreshToken = refresh.plaintext,
            accessTokenExpiresAt = access.expiresAt,
            refreshTokenExpiresAt = refresh.expiresAt,
        ),
    )
}
