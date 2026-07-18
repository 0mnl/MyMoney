package mymoney.data.repository

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.TransactionHistoryTable
import mymoney.data.db.tables.TransactionTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionHistoryEntry
import mymoney.domain.model.TransactionType
import mymoney.domain.repository.TransactionHistoryRepository
import mymoney.domain.repository.TransactionRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.andWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.or
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class TransactionRepositoryImpl(private val db: Database) : TransactionRepository {

    override suspend fun create(transaction: Transaction): Transaction = dbQuery(db) {
        TransactionTable.insert {
            it[id] = transaction.id
            it[familyId] = transaction.familyId
            it[accountId] = transaction.accountId
            it[categoryId] = transaction.categoryId
            it[type] = transaction.type.name
            it[targetAccountId] = transaction.targetAccountId
            it[amount] = transaction.amountKopecks
            it[currency] = transaction.currency
            it[occurredAt] = transaction.occurredAt
            it[comment] = transaction.comment
            it[attachmentPhotoPath] = transaction.attachmentPhotoPath
            it[createdBy] = transaction.createdBy
            it[createdAt] = transaction.createdAt
            it[updatedAt] = transaction.updatedAt
            it[isDeleted] = transaction.isDeleted
        }
        transaction
    }

    override suspend fun findById(id: UUID): Transaction? = dbQuery(db) {
        TransactionTable.selectAll()
            .where { TransactionTable.id eq id }
            .singleOrNull()
            ?.toTransaction()
    }

    override suspend fun list(
        familyId: UUID,
        accountId: UUID?,
        categoryId: UUID?,
        from: Instant?,
        to: Instant?,
        limit: Int,
        offset: Long,
    ): List<Transaction> = dbQuery(db) {
        val q = TransactionTable.selectAll()
            .where { (TransactionTable.familyId eq familyId) and (TransactionTable.isDeleted eq false) }
        if (accountId != null) q.andWhere {
            (TransactionTable.accountId eq accountId) or (TransactionTable.targetAccountId eq accountId)
        }
        if (categoryId != null) q.andWhere { TransactionTable.categoryId eq categoryId }
        if (from != null) q.andWhere { TransactionTable.occurredAt greaterEq from }
        if (to != null) q.andWhere { TransactionTable.occurredAt lessEq to }
        q.orderBy(TransactionTable.occurredAt to SortOrder.DESC)
            .limit(limit).offset(offset)
            .map { it.toTransaction() }
    }

    /**
     * Atomically snapshots the previous state and writes the new one.
     * Both operations run inside the same Exposed transaction so partial
     * failure cannot leave audit trail out of sync with the row (ADR-0004).
     */
    override suspend fun update(transaction: Transaction, changedBy: UUID): Transaction = dbQuery(db) {
        val existing = TransactionTable.selectAll()
            .where { TransactionTable.id eq transaction.id }
            .singleOrNull()
            ?.toTransaction()
            ?: throw NotFoundException("transaction", transaction.id.toString())

        TransactionHistoryTable.insert {
            it[id] = UUID.randomUUID()
            it[transactionId] = existing.id
            it[snapshotJson] = existing.toSnapshotJson()
            it[TransactionHistoryTable.changedBy] = changedBy
            it[changedAt] = Clock.System.now()
        }

        TransactionTable.update({ TransactionTable.id eq transaction.id }) {
            it[accountId] = transaction.accountId
            it[categoryId] = transaction.categoryId
            it[type] = transaction.type.name
            it[targetAccountId] = transaction.targetAccountId
            it[amount] = transaction.amountKopecks
            it[currency] = transaction.currency
            it[occurredAt] = transaction.occurredAt
            it[comment] = transaction.comment
            it[attachmentPhotoPath] = transaction.attachmentPhotoPath
            it[updatedAt] = transaction.updatedAt
            it[isDeleted] = transaction.isDeleted
        }

        transaction
    }

    /**
     * Soft-delete: snapshots the row into history (so an accidental deletion
     * is recoverable) and flips is_deleted.
     */
    override suspend fun softDelete(id: UUID, changedBy: UUID): Unit = dbQuery(db) {
        val existing = TransactionTable.selectAll()
            .where { TransactionTable.id eq id }
            .singleOrNull()
            ?.toTransaction()
            ?: throw NotFoundException("transaction", id.toString())

        TransactionHistoryTable.insert {
            it[TransactionHistoryTable.id] = UUID.randomUUID()
            it[transactionId] = existing.id
            it[snapshotJson] = existing.toSnapshotJson()
            it[TransactionHistoryTable.changedBy] = changedBy
            it[changedAt] = Clock.System.now()
        }

        TransactionTable.update({ TransactionTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = Clock.System.now()
        }
    }

    private fun ResultRow.toTransaction() = Transaction(
        id = this[TransactionTable.id],
        familyId = this[TransactionTable.familyId],
        accountId = this[TransactionTable.accountId],
        categoryId = this[TransactionTable.categoryId],
        type = TransactionType.valueOf(this[TransactionTable.type]),
        targetAccountId = this[TransactionTable.targetAccountId],
        amountKopecks = this[TransactionTable.amount],
        currency = this[TransactionTable.currency],
        occurredAt = this[TransactionTable.occurredAt],
        comment = this[TransactionTable.comment],
        attachmentPhotoPath = this[TransactionTable.attachmentPhotoPath],
        createdBy = this[TransactionTable.createdBy],
        createdAt = this[TransactionTable.createdAt],
        updatedAt = this[TransactionTable.updatedAt],
        isDeleted = this[TransactionTable.isDeleted],
    )
}

class TransactionHistoryRepositoryImpl(private val db: Database) : TransactionHistoryRepository {
    override suspend fun listByTransaction(transactionId: UUID): List<TransactionHistoryEntry> = dbQuery(db) {
        TransactionHistoryTable.selectAll()
            .where { TransactionHistoryTable.transactionId eq transactionId }
            .orderBy(TransactionHistoryTable.changedAt to SortOrder.DESC)
            .map {
                TransactionHistoryEntry(
                    id = it[TransactionHistoryTable.id],
                    transactionId = it[TransactionHistoryTable.transactionId],
                    snapshotJson = it[TransactionHistoryTable.snapshotJson].toString(),
                    changedBy = it[TransactionHistoryTable.changedBy],
                    changedAt = it[TransactionHistoryTable.changedAt],
                )
            }
    }
}

/**
 * Manual JSON construction avoids adding kotlinx-serialization annotations
 * to the domain Transaction, and keeps the snapshot format stable across
 * future refactors of the domain model (see § 25.5 Bible).
 */
private fun Transaction.toSnapshotJson(): JsonElement = buildJsonObject {
    put("id", JsonPrimitive(id.toString()))
    put("familyId", JsonPrimitive(familyId.toString()))
    put("accountId", JsonPrimitive(accountId.toString()))
    put("categoryId", if (categoryId != null) JsonPrimitive(categoryId.toString()) else JsonPrimitive(null as String?))
    put("type", JsonPrimitive(type.name))
    put("targetAccountId", if (targetAccountId != null) JsonPrimitive(targetAccountId.toString()) else JsonPrimitive(null as String?))
    put("amount", JsonPrimitive(amountKopecks))
    put("currency", JsonPrimitive(currency))
    put("occurredAt", JsonPrimitive(occurredAt.toString()))
    put("comment", if (comment != null) JsonPrimitive(comment) else JsonPrimitive(null as String?))
    put("attachmentPhotoPath", if (attachmentPhotoPath != null) JsonPrimitive(attachmentPhotoPath) else JsonPrimitive(null as String?))
    put("createdBy", JsonPrimitive(createdBy.toString()))
    put("createdAt", JsonPrimitive(createdAt.toString()))
    put("updatedAt", JsonPrimitive(updatedAt.toString()))
    put("isDeleted", JsonPrimitive(isDeleted))
}
