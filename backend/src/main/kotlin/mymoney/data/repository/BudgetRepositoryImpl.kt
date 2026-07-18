package mymoney.data.repository

import kotlinx.datetime.Instant
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.BudgetTable
import mymoney.data.db.tables.TransactionTable
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import mymoney.domain.model.TransactionType
import mymoney.domain.repository.BudgetRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.andWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.sum
import org.jetbrains.exposed.sql.update
import java.util.UUID

class BudgetRepositoryImpl(private val db: Database) : BudgetRepository {

    override suspend fun create(budget: Budget): Budget = dbQuery(db) {
        BudgetTable.insert {
            it[id] = budget.id
            it[familyId] = budget.familyId
            it[periodType] = budget.periodType.name
            it[periodStart] = budget.periodStart
            it[categoryId] = budget.categoryId
            it[plannedAmount] = budget.plannedAmountKopecks
            it[isDeleted] = budget.isDeleted
            it[createdAt] = budget.createdAt
            it[updatedAt] = budget.updatedAt
        }
        budget
    }

    override suspend fun findById(id: UUID): Budget? = dbQuery(db) {
        BudgetTable.selectAll()
            .where { BudgetTable.id eq id }
            .singleOrNull()
            ?.toBudget()
    }

    override suspend fun findExisting(
        familyId: UUID,
        categoryId: UUID,
        periodType: BudgetPeriodType,
        periodStart: Instant,
    ): Budget? = dbQuery(db) {
        BudgetTable.selectAll()
            .where {
                (BudgetTable.familyId eq familyId) and
                    (BudgetTable.categoryId eq categoryId) and
                    (BudgetTable.periodType eq periodType.name) and
                    (BudgetTable.periodStart eq periodStart) and
                    (BudgetTable.isDeleted eq false)
            }
            .singleOrNull()
            ?.toBudget()
    }

    override suspend fun list(
        familyId: UUID,
        periodType: BudgetPeriodType?,
        periodStart: Instant?,
    ): List<Budget> = dbQuery(db) {
        val q = BudgetTable.selectAll()
            .where { (BudgetTable.familyId eq familyId) and (BudgetTable.isDeleted eq false) }
        if (periodType != null) q.andWhere { BudgetTable.periodType eq periodType.name }
        if (periodStart != null) q.andWhere { BudgetTable.periodStart eq periodStart }
        q.orderBy(BudgetTable.periodStart to SortOrder.DESC).map { it.toBudget() }
    }

    override suspend fun update(budget: Budget): Budget = dbQuery(db) {
        BudgetTable.update({ BudgetTable.id eq budget.id }) {
            it[plannedAmount] = budget.plannedAmountKopecks
            it[periodType] = budget.periodType.name
            it[periodStart] = budget.periodStart
            it[categoryId] = budget.categoryId
            it[updatedAt] = budget.updatedAt
            it[isDeleted] = budget.isDeleted
        }
        budget
    }

    override suspend fun softDelete(id: UUID, now: Instant): Unit = dbQuery(db) {
        BudgetTable.update({ BudgetTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = now
        }
        Unit
    }

    override suspend fun sumExpenses(
        familyId: UUID,
        categoryId: UUID,
        from: Instant,
        to: Instant,
    ): Long = dbQuery(db) {
        val sumCol = TransactionTable.amount.sum()
        TransactionTable
            .select(sumCol)
            .where {
                (TransactionTable.familyId eq familyId) and
                    (TransactionTable.categoryId eq categoryId) and
                    (TransactionTable.type eq TransactionType.EXPENSE.name) and
                    (TransactionTable.isDeleted eq false) and
                    (TransactionTable.occurredAt greaterEq from) and
                    (TransactionTable.occurredAt less to)
            }
            .single()[sumCol] ?: 0L
    }

    private fun ResultRow.toBudget() = Budget(
        id = this[BudgetTable.id],
        familyId = this[BudgetTable.familyId],
        categoryId = this[BudgetTable.categoryId],
        periodType = BudgetPeriodType.valueOf(this[BudgetTable.periodType]),
        periodStart = this[BudgetTable.periodStart],
        plannedAmountKopecks = this[BudgetTable.plannedAmount],
        createdAt = this[BudgetTable.createdAt],
        updatedAt = this[BudgetTable.updatedAt],
        isDeleted = this[BudgetTable.isDeleted],
    )
}
