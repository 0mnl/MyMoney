package mymoney.domain.usecase.auth

import mymoney.domain.repository.RefreshTokenRepository
import java.util.UUID

class LogoutAllUseCase(
    private val refreshTokens: RefreshTokenRepository,
) {
    suspend fun execute(userId: UUID) {
        refreshTokens.revokeAllForUser(userId)
    }
}
