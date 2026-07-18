package mymoney.data.repository

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.RefreshTokenTable
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.repository.StoredRefreshToken
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class RefreshTokenRepositoryImpl(private val db: Database) : RefreshTokenRepository {

    override suspend fun create(
        id: UUID,
        userId: UUID,
        tokenHash: String,
        expiresAt: Instant,
    ): StoredRefreshToken = dbQuery(db) {
        val createdAt = Clock.System.now()
        RefreshTokenTable.insert {
            it[RefreshTokenTable.id] = id
            it[RefreshTokenTable.userId] = userId
            it[RefreshTokenTable.tokenHash] = tokenHash
            it[RefreshTokenTable.expiresAt] = expiresAt
            it[RefreshTokenTable.revokedAt] = null
            it[RefreshTokenTable.createdAt] = createdAt
        }
        StoredRefreshToken(id, userId, tokenHash, expiresAt, null, createdAt)
    }

    override suspend fun findByHash(tokenHash: String): StoredRefreshToken? = dbQuery(db) {
        RefreshTokenTable.selectAll()
            .where { RefreshTokenTable.tokenHash eq tokenHash }
            .singleOrNull()
            ?.toToken()
    }

    override suspend fun revoke(id: UUID): Unit = dbQuery(db) {
        RefreshTokenTable.update({
            (RefreshTokenTable.id eq id) and (RefreshTokenTable.revokedAt.isNull())
        }) {
            it[revokedAt] = Clock.System.now()
        }
        Unit
    }

    override suspend fun revokeAllForUser(userId: UUID): Unit = dbQuery(db) {
        RefreshTokenTable.update({
            (RefreshTokenTable.userId eq userId) and (RefreshTokenTable.revokedAt.isNull())
        }) {
            it[revokedAt] = Clock.System.now()
        }
        Unit
    }

    private fun ResultRow.toToken() = StoredRefreshToken(
        id = this[RefreshTokenTable.id],
        userId = this[RefreshTokenTable.userId],
        tokenHash = this[RefreshTokenTable.tokenHash],
        expiresAt = this[RefreshTokenTable.expiresAt],
        revokedAt = this[RefreshTokenTable.revokedAt],
        createdAt = this[RefreshTokenTable.createdAt],
    )
}
