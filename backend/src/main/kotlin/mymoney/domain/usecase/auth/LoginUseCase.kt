package mymoney.domain.usecase.auth

import mymoney.domain.errors.UnauthorizedException
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.security.PasswordHasher
import mymoney.domain.security.TokenService
import java.util.UUID

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

        val familyId = members.listByUser(lookup.userId).firstOrNull()?.familyId
            ?: throw UnauthorizedException("User has no family membership")

        val access = tokenService.issueAccessToken(lookup.userId, familyId)
        val refresh = tokenService.issueRefreshToken()
        refreshTokens.create(
            id = UUID.randomUUID(),
            userId = lookup.userId,
            tokenHash = refresh.hash,
            expiresAt = refresh.expiresAt,
        )

        return AuthSession(
            userId = lookup.userId,
            familyId = familyId,
            tokens = AuthTokens(
                accessToken = access.token,
                refreshToken = refresh.plaintext,
                accessTokenExpiresAt = access.expiresAt,
                refreshTokenExpiresAt = refresh.expiresAt,
            ),
        )
    }
}
