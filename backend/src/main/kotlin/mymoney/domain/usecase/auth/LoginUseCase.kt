package mymoney.domain.usecase.auth

import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.UnauthorizedException
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.security.PasswordHasher
import mymoney.domain.security.TokenService

class LoginUseCase(
    private val users: UserRepository,
    private val members: FamilyMemberRepository,
    private val refreshTokens: RefreshTokenRepository,
    private val passwordHasher: PasswordHasher,
    private val tokenService: TokenService,
) {

    suspend fun execute(rawEmail: String, password: String): AuthSession {
        val email = normalizeEmail(rawEmail)
        val lookup = users.findPasswordHashByEmail(email)
            ?: throw UnauthorizedException("Invalid email or password")

        if (!passwordHasher.verify(password, lookup.passwordHash)) {
            throw UnauthorizedException("Invalid email or password")
        }

        // Checked only after the password matches, so this cannot be used to
        // probe which addresses are registered. The client routes EMAIL_NOT_VERIFIED
        // to the confirmation screen instead of showing a login error.
        if (!lookup.emailVerified) {
            throw ForbiddenException(
                msg = "Email is not confirmed",
                code = "EMAIL_NOT_VERIFIED",
                details = mapOf("email" to email),
            )
        }

        val familyId = members.listByUser(lookup.userId).firstOrNull()?.familyId
            ?: throw UnauthorizedException("User has no family membership")

        return issueSession(
            userId = lookup.userId,
            familyId = familyId,
            tokenService = tokenService,
            refreshTokens = refreshTokens,
        )
    }
}
