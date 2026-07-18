package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.usecase.auth.AuthSession
import mymoney.domain.usecase.auth.AuthTokens

@Serializable
data class RegisterRequest(
    val email: String,
    val password: String,
)

@Serializable
data class LoginRequest(
    val email: String,
    val password: String,
)

@Serializable
data class RefreshRequest(
    val refreshToken: String,
)

@Serializable
data class AuthSessionResponse(
    val userId: String,
    val familyId: String,
    val accessToken: String,
    val refreshToken: String,
    val accessTokenExpiresAt: Instant,
    val refreshTokenExpiresAt: Instant,
)

@Serializable
data class AuthTokensResponse(
    val accessToken: String,
    val refreshToken: String,
    val accessTokenExpiresAt: Instant,
    val refreshTokenExpiresAt: Instant,
)

fun AuthSession.toResponse() = AuthSessionResponse(
    userId = userId.toString(),
    familyId = familyId.toString(),
    accessToken = tokens.accessToken,
    refreshToken = tokens.refreshToken,
    accessTokenExpiresAt = tokens.accessTokenExpiresAt,
    refreshTokenExpiresAt = tokens.refreshTokenExpiresAt,
)

fun AuthTokens.toResponse() = AuthTokensResponse(
    accessToken = accessToken,
    refreshToken = refreshToken,
    accessTokenExpiresAt = accessTokenExpiresAt,
    refreshTokenExpiresAt = refreshTokenExpiresAt,
)
