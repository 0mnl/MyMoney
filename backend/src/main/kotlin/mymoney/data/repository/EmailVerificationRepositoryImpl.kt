package mymoney.data.repository

import kotlinx.datetime.Instant
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.EmailVerificationCodeTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.EmailVerificationCode
import mymoney.domain.repository.EmailVerificationRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class EmailVerificationRepositoryImpl(private val db: Database) : EmailVerificationRepository {

    override suspend fun create(
        id: UUID,
        userId: UUID,
        codeHash: String,
        expiresAt: Instant,
        createdAt: Instant,
    ): EmailVerificationCode = dbQuery(db) {
        EmailVerificationCodeTable.insert {
            it[EmailVerificationCodeTable.id] = id
            it[EmailVerificationCodeTable.userId] = userId
            it[EmailVerificationCodeTable.codeHash] = codeHash
            it[EmailVerificationCodeTable.expiresAt] = expiresAt
            it[consumedAt] = null
            it[attempts] = 0
            it[EmailVerificationCodeTable.createdAt] = createdAt
        }
        EmailVerificationCode(id, userId, codeHash, expiresAt, null, 0, createdAt)
    }

    override suspend fun findActiveByUser(userId: UUID): EmailVerificationCode? = dbQuery(db) {
        EmailVerificationCodeTable.selectAll()
            .where {
                (EmailVerificationCodeTable.userId eq userId) and
                    EmailVerificationCodeTable.consumedAt.isNull()
            }
            .orderBy(EmailVerificationCodeTable.createdAt to SortOrder.DESC)
            .limit(1)
            .singleOrNull()
            ?.toCode()
    }

    override suspend fun incrementAttempts(id: UUID): Int = dbQuery(db) {
        val current = EmailVerificationCodeTable.selectAll()
            .where { EmailVerificationCodeTable.id eq id }
            .singleOrNull()
            ?.get(EmailVerificationCodeTable.attempts)
            ?: throw NotFoundException("email_verification_code", id.toString())

        val next = current + 1
        EmailVerificationCodeTable.update({ EmailVerificationCodeTable.id eq id }) {
            it[attempts] = next
        }
        next
    }

    override suspend fun markConsumed(id: UUID, at: Instant): Unit = dbQuery(db) {
        EmailVerificationCodeTable.update({
            (EmailVerificationCodeTable.id eq id) and EmailVerificationCodeTable.consumedAt.isNull()
        }) {
            it[consumedAt] = at
        }
        Unit
    }

    override suspend fun consumeAllForUser(userId: UUID, at: Instant): Unit = dbQuery(db) {
        EmailVerificationCodeTable.update({
            (EmailVerificationCodeTable.userId eq userId) and
                EmailVerificationCodeTable.consumedAt.isNull()
        }) {
            it[consumedAt] = at
        }
        Unit
    }

    private fun ResultRow.toCode() = EmailVerificationCode(
        id = this[EmailVerificationCodeTable.id],
        userId = this[EmailVerificationCodeTable.userId],
        codeHash = this[EmailVerificationCodeTable.codeHash],
        expiresAt = this[EmailVerificationCodeTable.expiresAt],
        consumedAt = this[EmailVerificationCodeTable.consumedAt],
        attempts = this[EmailVerificationCodeTable.attempts],
        createdAt = this[EmailVerificationCodeTable.createdAt],
    )
}
