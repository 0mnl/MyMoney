package mymoney.data.repository

import kotlinx.datetime.Clock
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.AppUserTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.User
import mymoney.domain.repository.PasswordLookup
import mymoney.domain.repository.UserRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class UserRepositoryImpl(private val db: Database) : UserRepository {

    override suspend fun create(user: User, passwordHash: String): User = dbQuery(db) {
        AppUserTable.insert {
            it[id] = user.id
            it[email] = user.email
            it[AppUserTable.passwordHash] = passwordHash
            it[createdAt] = user.createdAt
            it[updatedAt] = user.updatedAt
        }
        user
    }

    override suspend fun findById(id: UUID): User? = dbQuery(db) {
        AppUserTable.selectAll()
            .where { AppUserTable.id eq id }
            .singleOrNull()
            ?.toUser()
    }

    override suspend fun findByEmail(email: String): User? = dbQuery(db) {
        AppUserTable.selectAll()
            .where { AppUserTable.email eq email }
            .singleOrNull()
            ?.toUser()
    }

    override suspend fun findPasswordHashByEmail(email: String): PasswordLookup? = dbQuery(db) {
        AppUserTable.selectAll()
            .where { AppUserTable.email eq email }
            .singleOrNull()
            ?.let {
                PasswordLookup(
                    userId = it[AppUserTable.id],
                    passwordHash = it[AppUserTable.passwordHash],
                )
            }
    }

    override suspend fun updatePasswordHash(userId: UUID, newHash: String): Unit = dbQuery(db) {
        val updated = AppUserTable.update({ AppUserTable.id eq userId }) {
            it[passwordHash] = newHash
            it[updatedAt] = Clock.System.now()
        }
        if (updated == 0) throw NotFoundException("user", userId.toString())
    }

    private fun ResultRow.toUser() = User(
        id = this[AppUserTable.id],
        email = this[AppUserTable.email],
        createdAt = this[AppUserTable.createdAt],
        updatedAt = this[AppUserTable.updatedAt],
    )
}
