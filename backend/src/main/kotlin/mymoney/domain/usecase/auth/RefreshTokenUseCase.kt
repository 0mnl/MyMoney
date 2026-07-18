package mymoney.domain.usecase.auth

import kotlinx.datetime.Clock
import mymoney.domain.errors.UnauthorizedException
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.security.TokenService
import java.util.UUID

/**
 * Rotates the refresh token: verifies the incoming plaintext, revokes it
 * (single-use), and issues a fresh pair. Also refreshes the access token.
 * See ADR-0005 § "aut" — rotation on refresh.
 */
class RefreshTokenUseCase(
    private val refreshTokens: RefreshTokenRepository,
    private val members: FamilyMemberRepository,
    private val tokenService: TokenService,
    private val clock: Clock = Clock.System,
) {

    suspend fun execute(rawRefreshToken: String): AuthTokens {
        val hash = tokenService.hashRefreshToken(rawRefreshToken)
        val stored = refreshTokens.findByHash(hash)
            ?: throw UnauthorizedException("Refresh token invalid")

        if (stored.revokedAt != null) throw UnauthorizedException("Refresh token revoked")
        if (stored.expiresAt <= clock.now()) throw UnauthorizedException("Refresh token expired")

        val familyId = members.listByUser(stored.userId).firstOrNull()?.familyId
            ?: throw UnauthorizedException("User has no family membership")

        // Rotate: revoke the old, issue a new pair.
        refreshTokens.revoke(stored.id)

        val access = tokenService.issueAccessToken(stored.userId, familyId)
        val refresh = tokenService.issueRefreshToken()
        refreshTokens.create(
            id = UUID.randomUUID(),
            userId = stored.userId,
            tokenHash = refresh.hash,
            expiresAt = refresh.expiresAt,
        )

        return AuthTokens(
            accessToken = access.token,
            refreshToken = refresh.plaintext,
            accessTokenExpiresAt = access.expiresAt,
            refreshTokenExpiresAt = refresh.expiresAt,
        )
    }
}
