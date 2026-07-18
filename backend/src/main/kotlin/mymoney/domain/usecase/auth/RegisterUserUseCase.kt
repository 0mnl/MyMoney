package mymoney.domain.usecase.auth

import kotlinx.datetime.Clock
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Family
import mymoney.domain.model.FamilyMember
import mymoney.domain.model.FamilyRole
import mymoney.domain.model.User
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.FamilyRepository
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.security.PasswordHasher
import mymoney.domain.security.TokenService
import mymoney.domain.usecase.category.SeedSystemCategoriesUseCase
import java.util.UUID

/**
 * Registers a new user, provisions a personal family with the user as OWNER,
 * and returns a session with fresh access + refresh tokens.
 *
 * This is one of the two places where the server generates entity IDs
 * (see ADR-0005). Elsewhere IDs come from the client.
 */
class RegisterUserUseCase(
    private val users: UserRepository,
    private val families: FamilyRepository,
    private val members: FamilyMemberRepository,
    private val refreshTokens: RefreshTokenRepository,
    private val passwordHasher: PasswordHasher,
    private val tokenService: TokenService,
    private val seedSystemCategories: SeedSystemCategoriesUseCase,
    private val clock: Clock = Clock.System,
) {

    suspend fun execute(rawEmail: String, password: String): AuthSession {
        val email = normalizeEmail(rawEmail)
        if (!isValidEmail(email)) {
            throw ValidationException("Invalid email", mapOf("field" to "email"))
        }
        if (!isValidPassword(password)) {
            throw ValidationException(
                "Password too short",
                mapOf("field" to "password", "minLength" to "8"),
            )
        }

        if (users.findByEmail(email) != null) {
            throw ConflictException(
                code = "EMAIL_TAKEN",
                msg = "Email already registered",
                details = mapOf("email" to email),
            )
        }

        val now = clock.now()
        val userId = UUID.randomUUID()
        val familyId = UUID.randomUUID()

        val passwordHash = passwordHasher.hash(password)

        users.create(
            User(id = userId, email = email, createdAt = now, updatedAt = now),
            passwordHash,
        )
        families.create(
            Family(id = familyId, name = defaultFamilyName(email), createdAt = now, updatedAt = now),
        )
        members.add(
            FamilyMember(
                id = UUID.randomUUID(),
                familyId = familyId,
                userId = userId,
                role = FamilyRole.OWNER,
                joinedAt = now,
            ),
        )
        seedSystemCategories.execute(familyId)

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

    private fun defaultFamilyName(email: String) = email.substringBefore('@').ifBlank { "Family" }
}
