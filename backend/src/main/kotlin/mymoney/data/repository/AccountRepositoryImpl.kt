package mymoney.data.repository

import kotlinx.datetime.Clock
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.AccountTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Account
import mymoney.domain.repository.AccountRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.andWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class AccountRepositoryImpl(private val db: Database) : AccountRepository {

    override suspend fun create(account: Account): Account = dbQuery(db) {
        AccountTable.insert {
            it[id] = account.id
            it[familyId] = account.familyId
            it[name] = account.name
            it[type] = account.type
            it[currency] = account.currency
            it[initialBalance] = account.initialBalanceKopecks
            it[creditLimit] = account.creditLimitKopecks
            it[isArchived] = account.isArchived
            it[isDeleted] = account.isDeleted
            it[createdAt] = account.createdAt
            it[updatedAt] = account.updatedAt
        }
        account
    }

    override suspend fun findById(id: UUID): Account? = dbQuery(db) {
        AccountTable.selectAll()
            .where { AccountTable.id eq id }
            .singleOrNull()
            ?.toAccount()
    }

    override suspend fun listByFamily(familyId: UUID, includeArchived: Boolean): List<Account> = dbQuery(db) {
        val base = AccountTable.selectAll()
            .where { (AccountTable.familyId eq familyId) and (AccountTable.isDeleted eq false) }
        val filtered = if (includeArchived) base else base.andWhere { AccountTable.isArchived eq false }
        filtered.orderBy(AccountTable.createdAt to SortOrder.ASC)
            .map { it.toAccount() }
    }

    override suspend fun update(account: Account): Account = dbQuery(db) {
        val updated = AccountTable.update({ AccountTable.id eq account.id }) {
            it[name] = account.name
            it[type] = account.type
            it[currency] = account.currency
            it[initialBalance] = account.initialBalanceKopecks
            it[creditLimit] = account.creditLimitKopecks
            it[isArchived] = account.isArchived
            it[isDeleted] = account.isDeleted
            it[updatedAt] = account.updatedAt
        }
        if (updated == 0) throw NotFoundException("account", account.id.toString())
        account
    }

    override suspend fun softDelete(id: UUID): Unit = dbQuery(db) {
        val now = Clock.System.now()
        val updated = AccountTable.update({ AccountTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = now
        }
        if (updated == 0) throw NotFoundException("account", id.toString())
    }

    private fun ResultRow.toAccount() = Account(
        id = this[AccountTable.id],
        familyId = this[AccountTable.familyId],
        name = this[AccountTable.name],
        type = this[AccountTable.type],
        currency = this[AccountTable.currency],
        initialBalanceKopecks = this[AccountTable.initialBalance],
        creditLimitKopecks = this[AccountTable.creditLimit],
        isArchived = this[AccountTable.isArchived],
        isDeleted = this[AccountTable.isDeleted],
        createdAt = this[AccountTable.createdAt],
        updatedAt = this[AccountTable.updatedAt],
    )
}
