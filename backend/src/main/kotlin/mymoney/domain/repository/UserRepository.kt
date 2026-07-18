package mymoney.domain.repository

import mymoney.domain.model.User
import java.util.UUID

interface UserRepository {
    /**
     * Persist a new user. `passwordHash` is expected to be an argon2id hash
     * generated at the use case layer — repository never sees plaintext.
     */
    suspend fun create(user: User, passwordHash: String): User

    suspend fun findById(id: UUID): User?
    suspend fun findByEmail(email: String): User?

    /**
     * Returns the raw password hash for the given user, or null if the user
     * does not exist. Used only by the login use case.
     */
    suspend fun findPasswordHashByEmail(email: String): PasswordLookup?

    suspend fun updatePasswordHash(userId: UUID, newHash: String)
}

data class PasswordLookup(
    val userId: UUID,
    val passwordHash: String,
)
