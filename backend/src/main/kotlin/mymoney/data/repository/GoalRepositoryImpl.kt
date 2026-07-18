package mymoney.data.repository

import kotlinx.datetime.Instant
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.GoalTable
import mymoney.domain.model.Goal
import mymoney.domain.repository.GoalRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class GoalRepositoryImpl(private val db: Database) : GoalRepository {

    override suspend fun create(goal: Goal): Goal = dbQuery(db) {
        GoalTable.insert {
            it[id] = goal.id
            it[familyId] = goal.familyId
            it[name] = goal.name
            it[targetAmount] = goal.targetAmountKopecks
            it[currentAmount] = goal.currentAmountKopecks
            it[targetDate] = goal.targetDate
            it[isDeleted] = goal.isDeleted
            it[createdAt] = goal.createdAt
            it[updatedAt] = goal.updatedAt
        }
        goal
    }

    override suspend fun findById(id: UUID): Goal? = dbQuery(db) {
        GoalTable.selectAll()
            .where { GoalTable.id eq id }
            .singleOrNull()
            ?.toGoal()
    }

    override suspend fun list(familyId: UUID): List<Goal> = dbQuery(db) {
        GoalTable.selectAll()
            .where { (GoalTable.familyId eq familyId) and (GoalTable.isDeleted eq false) }
            .orderBy(GoalTable.createdAt to SortOrder.DESC)
            .map { it.toGoal() }
    }

    override suspend fun update(goal: Goal): Goal = dbQuery(db) {
        GoalTable.update({ GoalTable.id eq goal.id }) {
            it[name] = goal.name
            it[targetAmount] = goal.targetAmountKopecks
            it[currentAmount] = goal.currentAmountKopecks
            it[targetDate] = goal.targetDate
            it[updatedAt] = goal.updatedAt
            it[isDeleted] = goal.isDeleted
        }
        goal
    }

    override suspend fun softDelete(id: UUID, now: Instant): Unit = dbQuery(db) {
        GoalTable.update({ GoalTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = now
        }
        Unit
    }

    private fun ResultRow.toGoal() = Goal(
        id = this[GoalTable.id],
        familyId = this[GoalTable.familyId],
        name = this[GoalTable.name],
        targetAmountKopecks = this[GoalTable.targetAmount],
        currentAmountKopecks = this[GoalTable.currentAmount],
        targetDate = this[GoalTable.targetDate],
        createdAt = this[GoalTable.createdAt],
        updatedAt = this[GoalTable.updatedAt],
        isDeleted = this[GoalTable.isDeleted],
    )
}
