package mymoney.data.repository

import kotlinx.datetime.Clock
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.DebtTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Debt
import mymoney.domain.model.DebtDirection
import mymoney.domain.model.DebtStatus
import mymoney.domain.repository.DebtRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.andWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class DebtRepositoryImpl(private val db: Database) : DebtRepository {

    override suspend fun create(debt: Debt): Debt = dbQuery(db) {
        DebtTable.insert {
            it[id] = debt.id
            it[familyId] = debt.familyId
            it[counterpartyName] = debt.counterpartyName
            it[direction] = debt.direction.name
            it[amount] = debt.amountKopecks
            it[dueDate] = debt.dueDate
            it[status] = debt.status.name
            it[isDeleted] = debt.isDeleted
            it[createdAt] = debt.createdAt
            it[updatedAt] = debt.updatedAt
        }
        debt
    }

    override suspend fun findById(id: UUID): Debt? = dbQuery(db) {
        DebtTable.selectAll().where { DebtTable.id eq id }.singleOrNull()?.toDebt()
    }

    override suspend fun list(familyId: UUID, openOnly: Boolean): List<Debt> = dbQuery(db) {
        val q = DebtTable.selectAll()
            .where { (DebtTable.familyId eq familyId) and (DebtTable.isDeleted eq false) }
        if (openOnly) q.andWhere { DebtTable.status eq DebtStatus.OPEN.name }
        q.orderBy(DebtTable.createdAt to SortOrder.DESC).map { it.toDebt() }
    }

    override suspend fun update(debt: Debt): Debt = dbQuery(db) {
        val updated = DebtTable.update({ DebtTable.id eq debt.id }) {
            it[counterpartyName] = debt.counterpartyName
            it[direction] = debt.direction.name
            it[amount] = debt.amountKopecks
            it[dueDate] = debt.dueDate
            it[status] = debt.status.name
            it[isDeleted] = debt.isDeleted
            it[updatedAt] = debt.updatedAt
        }
        if (updated == 0) throw NotFoundException("debt", debt.id.toString())
        debt
    }

    override suspend fun softDelete(id: UUID): Unit = dbQuery(db) {
        val now = Clock.System.now()
        val updated = DebtTable.update({ DebtTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = now
        }
        if (updated == 0) throw NotFoundException("debt", id.toString())
    }

    private fun ResultRow.toDebt() = Debt(
        id = this[DebtTable.id],
        familyId = this[DebtTable.familyId],
        counterpartyName = this[DebtTable.counterpartyName],
        direction = DebtDirection.valueOf(this[DebtTable.direction]),
        amountKopecks = this[DebtTable.amount],
        dueDate = this[DebtTable.dueDate],
        status = DebtStatus.valueOf(this[DebtTable.status]),
        isDeleted = this[DebtTable.isDeleted],
        createdAt = this[DebtTable.createdAt],
        updatedAt = this[DebtTable.updatedAt],
    )
}
