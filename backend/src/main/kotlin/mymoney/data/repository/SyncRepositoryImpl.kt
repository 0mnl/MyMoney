package mymoney.data.repository

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.AccountTable
import mymoney.data.db.tables.BudgetTable
import mymoney.data.db.tables.CategoryTable
import mymoney.data.db.tables.DebtTable
import mymoney.data.db.tables.FamilyMemberTable
import mymoney.data.db.tables.FamilyTable
import mymoney.data.db.tables.GoalTable
import mymoney.data.db.tables.SubscriptionTable
import mymoney.data.db.tables.TransactionTable
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.model.AcceptedRef
import mymoney.domain.model.Account
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType
import mymoney.domain.model.Debt
import mymoney.domain.model.DebtDirection
import mymoney.domain.model.DebtStatus
import mymoney.domain.model.Family
import mymoney.domain.model.FamilyMember
import mymoney.domain.model.FamilyRole
import mymoney.domain.model.Goal
import mymoney.domain.model.Subscription
import mymoney.domain.model.SubscriptionPeriod
import mymoney.domain.model.SyncBundle
import mymoney.domain.model.SyncConflict
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionType
import mymoney.domain.repository.SyncRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class SyncRepositoryImpl(private val db: Database) : SyncRepository {

    override suspend fun pullChanged(familyId: UUID, since: Instant?): SyncBundle = dbQuery(db) {
        SyncBundle(
            families = FamilyTable
                .selectAll()
                .where {
                    (FamilyTable.id eq familyId).let {
                        if (since != null) it and (FamilyTable.updatedAt greater since) else it
                    }
                }
                .map { it.toFamily() },
            familyMembers = FamilyMemberTable
                .selectAll()
                .where { FamilyMemberTable.familyId eq familyId }
                .map { it.toFamilyMember() },
            accounts = AccountTable
                .selectAll()
                .where {
                    (AccountTable.familyId eq familyId).let {
                        if (since != null) it and (AccountTable.updatedAt greater since) else it
                    }
                }
                .map { it.toAccount() },
            categories = CategoryTable
                .selectAll()
                .where {
                    (CategoryTable.familyId eq familyId).let {
                        if (since != null) it and (CategoryTable.updatedAt greater since) else it
                    }
                }
                .map { it.toCategory() },
            transactions = TransactionTable
                .selectAll()
                .where {
                    (TransactionTable.familyId eq familyId).let {
                        if (since != null) it and (TransactionTable.updatedAt greater since) else it
                    }
                }
                .map { it.toTransaction() },
            budgets = BudgetTable
                .selectAll()
                .where {
                    (BudgetTable.familyId eq familyId).let {
                        if (since != null) it and (BudgetTable.updatedAt greater since) else it
                    }
                }
                .map { it.toBudget() },
            goals = GoalTable
                .selectAll()
                .where {
                    (GoalTable.familyId eq familyId).let {
                        if (since != null) it and (GoalTable.updatedAt greater since) else it
                    }
                }
                .map { it.toGoal() },
            debts = DebtTable
                .selectAll()
                .where {
                    (DebtTable.familyId eq familyId).let {
                        if (since != null) it and (DebtTable.updatedAt greater since) else it
                    }
                }
                .map { it.toDebt() },
            subscriptions = SubscriptionTable
                .selectAll()
                .where {
                    (SubscriptionTable.familyId eq familyId).let {
                        if (since != null) it and (SubscriptionTable.updatedAt greater since) else it
                    }
                }
                .map { it.toSubscription() },
        )
    }

    /**
     * LWW upsert per entity. Order matters — parent categories, accounts and
     * categories are pushed before transactions/budgets/goals because those
     * carry FKs to the former. Family and FamilyMember are NOT accepted via
     * sync — they mutate through /auth and /family endpoints only.
     */
    override suspend fun pushLww(familyId: UUID, bundle: SyncBundle): SyncRepository.PushResult = dbQuery(db) {
        val accepted = mutableListOf<AcceptedRef>()
        val conflicts = mutableListOf<SyncConflict>()

        // Categories: parents first so child FKs resolve on insert.
        val (parents, children) = bundle.categories.partition { it.parentCategoryId == null }
        for (c in parents + children) upsertCategory(familyId, c, accepted, conflicts)

        for (a in bundle.accounts) upsertAccount(familyId, a, accepted, conflicts)
        for (t in bundle.transactions) upsertTransaction(familyId, t, accepted, conflicts)
        for (b in bundle.budgets) upsertBudget(familyId, b, accepted, conflicts)
        for (g in bundle.goals) upsertGoal(familyId, g, accepted, conflicts)
        for (d in bundle.debts) upsertDebt(familyId, d, accepted, conflicts)
        for (s in bundle.subscriptions) upsertSubscription(familyId, s, accepted, conflicts)

        SyncRepository.PushResult(accepted, conflicts)
    }

    private fun upsertAccount(
        familyScope: UUID,
        row: Account,
        accepted: MutableList<AcceptedRef>,
        conflicts: MutableList<SyncConflict>,
    ) {
        if (row.familyId != familyScope) throw ForbiddenException("Account belongs to a different family")
        val existing = AccountTable.selectAll().where { AccountTable.id eq row.id }.singleOrNull()
        if (existing == null) {
            AccountTable.insert {
                it[id] = row.id
                it[familyId] = row.familyId
                it[name] = row.name
                it[type] = row.type
                it[currency] = row.currency
                it[initialBalance] = row.initialBalanceKopecks
                it[isArchived] = row.isArchived
                it[isDeleted] = row.isDeleted
                it[createdAt] = row.createdAt
                it[updatedAt] = row.updatedAt
            }
            accepted += AcceptedRef(TABLE_ACCOUNT, row.id.toString())
            return
        }
        val serverUpdated = existing[AccountTable.updatedAt]
        if (serverUpdated > row.updatedAt) {
            conflicts += SyncConflict(
                table = TABLE_ACCOUNT,
                id = row.id.toString(),
                serverBundle = SyncBundle(accounts = listOf(existing.toAccount())),
            )
            return
        }
        AccountTable.update({ AccountTable.id eq row.id }) {
            it[name] = row.name
            it[type] = row.type
            it[currency] = row.currency
            it[initialBalance] = row.initialBalanceKopecks
            it[isArchived] = row.isArchived
            it[isDeleted] = row.isDeleted
            it[updatedAt] = row.updatedAt
        }
        accepted += AcceptedRef(TABLE_ACCOUNT, row.id.toString())
    }

    private fun upsertCategory(
        familyScope: UUID,
        row: Category,
        accepted: MutableList<AcceptedRef>,
        conflicts: MutableList<SyncConflict>,
    ) {
        if (row.familyId != familyScope) throw ForbiddenException("Category belongs to a different family")
        val existing = CategoryTable.selectAll().where { CategoryTable.id eq row.id }.singleOrNull()
        if (existing == null) {
            CategoryTable.insert {
                it[id] = row.id
                it[familyId] = row.familyId
                it[parentCategoryId] = row.parentCategoryId
                it[name] = row.name
                it[type] = row.type.name
                it[isMandatory] = row.isMandatory
                it[isSystem] = row.isSystem
                it[icon] = row.icon
                it[color] = row.color
                it[isArchived] = row.isArchived
                it[isDeleted] = row.isDeleted
                it[createdAt] = row.createdAt
                it[updatedAt] = row.updatedAt
            }
            accepted += AcceptedRef(TABLE_CATEGORY, row.id.toString())
            return
        }
        val serverUpdated = existing[CategoryTable.updatedAt]
        if (serverUpdated > row.updatedAt) {
            conflicts += SyncConflict(
                table = TABLE_CATEGORY,
                id = row.id.toString(),
                serverBundle = SyncBundle(categories = listOf(existing.toCategory())),
            )
            return
        }
        CategoryTable.update({ CategoryTable.id eq row.id }) {
            it[parentCategoryId] = row.parentCategoryId
            it[name] = row.name
            it[type] = row.type.name
            it[isMandatory] = row.isMandatory
            it[icon] = row.icon
            it[color] = row.color
            it[isArchived] = row.isArchived
            it[isDeleted] = row.isDeleted
            it[updatedAt] = row.updatedAt
            // isSystem intentionally not overwritten (server-owned attribute).
        }
        accepted += AcceptedRef(TABLE_CATEGORY, row.id.toString())
    }

    private fun upsertTransaction(
        familyScope: UUID,
        row: Transaction,
        accepted: MutableList<AcceptedRef>,
        conflicts: MutableList<SyncConflict>,
    ) {
        if (row.familyId != familyScope) throw ForbiddenException("Transaction belongs to a different family")
        val existing = TransactionTable.selectAll().where { TransactionTable.id eq row.id }.singleOrNull()
        if (existing == null) {
            TransactionTable.insert {
                it[id] = row.id
                it[familyId] = row.familyId
                it[accountId] = row.accountId
                it[categoryId] = row.categoryId
                it[type] = row.type.name
                it[targetAccountId] = row.targetAccountId
                it[amount] = row.amountKopecks
                it[currency] = row.currency
                it[occurredAt] = row.occurredAt
                it[comment] = row.comment
                it[attachmentPhotoPath] = row.attachmentPhotoPath
                it[createdBy] = row.createdBy
                it[createdAt] = row.createdAt
                it[updatedAt] = row.updatedAt
                it[isDeleted] = row.isDeleted
            }
            accepted += AcceptedRef(TABLE_TRANSACTION, row.id.toString())
            return
        }
        val serverUpdated = existing[TransactionTable.updatedAt]
        if (serverUpdated > row.updatedAt) {
            conflicts += SyncConflict(
                table = TABLE_TRANSACTION,
                id = row.id.toString(),
                serverBundle = SyncBundle(transactions = listOf(existing.toTransaction())),
            )
            return
        }
        TransactionTable.update({ TransactionTable.id eq row.id }) {
            it[accountId] = row.accountId
            it[categoryId] = row.categoryId
            it[type] = row.type.name
            it[targetAccountId] = row.targetAccountId
            it[amount] = row.amountKopecks
            it[currency] = row.currency
            it[occurredAt] = row.occurredAt
            it[comment] = row.comment
            it[attachmentPhotoPath] = row.attachmentPhotoPath
            it[updatedAt] = row.updatedAt
            it[isDeleted] = row.isDeleted
        }
        accepted += AcceptedRef(TABLE_TRANSACTION, row.id.toString())
    }

    private fun upsertBudget(
        familyScope: UUID,
        row: Budget,
        accepted: MutableList<AcceptedRef>,
        conflicts: MutableList<SyncConflict>,
    ) {
        if (row.familyId != familyScope) throw ForbiddenException("Budget belongs to a different family")
        val existing = BudgetTable.selectAll().where { BudgetTable.id eq row.id }.singleOrNull()
        if (existing == null) {
            BudgetTable.insert {
                it[id] = row.id
                it[familyId] = row.familyId
                it[periodType] = row.periodType.name
                it[periodStart] = row.periodStart
                it[categoryId] = row.categoryId
                it[plannedAmount] = row.plannedAmountKopecks
                it[isDeleted] = row.isDeleted
                it[createdAt] = row.createdAt
                it[updatedAt] = row.updatedAt
            }
            accepted += AcceptedRef(TABLE_BUDGET, row.id.toString())
            return
        }
        val serverUpdated = existing[BudgetTable.updatedAt]
        if (serverUpdated > row.updatedAt) {
            conflicts += SyncConflict(
                table = TABLE_BUDGET,
                id = row.id.toString(),
                serverBundle = SyncBundle(budgets = listOf(existing.toBudget())),
            )
            return
        }
        BudgetTable.update({ BudgetTable.id eq row.id }) {
            it[periodType] = row.periodType.name
            it[periodStart] = row.periodStart
            it[categoryId] = row.categoryId
            it[plannedAmount] = row.plannedAmountKopecks
            it[isDeleted] = row.isDeleted
            it[updatedAt] = row.updatedAt
        }
        accepted += AcceptedRef(TABLE_BUDGET, row.id.toString())
    }

    private fun upsertGoal(
        familyScope: UUID,
        row: Goal,
        accepted: MutableList<AcceptedRef>,
        conflicts: MutableList<SyncConflict>,
    ) {
        if (row.familyId != familyScope) throw ForbiddenException("Goal belongs to a different family")
        val existing = GoalTable.selectAll().where { GoalTable.id eq row.id }.singleOrNull()
        if (existing == null) {
            GoalTable.insert {
                it[id] = row.id
                it[familyId] = row.familyId
                it[name] = row.name
                it[targetAmount] = row.targetAmountKopecks
                it[currentAmount] = row.currentAmountKopecks
                it[targetDate] = row.targetDate
                it[isDeleted] = row.isDeleted
                it[createdAt] = row.createdAt
                it[updatedAt] = row.updatedAt
            }
            accepted += AcceptedRef(TABLE_GOAL, row.id.toString())
            return
        }
        val serverUpdated = existing[GoalTable.updatedAt]
        if (serverUpdated > row.updatedAt) {
            conflicts += SyncConflict(
                table = TABLE_GOAL,
                id = row.id.toString(),
                serverBundle = SyncBundle(goals = listOf(existing.toGoal())),
            )
            return
        }
        GoalTable.update({ GoalTable.id eq row.id }) {
            it[name] = row.name
            it[targetAmount] = row.targetAmountKopecks
            it[currentAmount] = row.currentAmountKopecks
            it[targetDate] = row.targetDate
            it[isDeleted] = row.isDeleted
            it[updatedAt] = row.updatedAt
        }
        accepted += AcceptedRef(TABLE_GOAL, row.id.toString())
    }

    private fun upsertDebt(
        familyScope: UUID,
        row: Debt,
        accepted: MutableList<AcceptedRef>,
        conflicts: MutableList<SyncConflict>,
    ) {
        if (row.familyId != familyScope) throw ForbiddenException("Debt belongs to a different family")
        val existing = DebtTable.selectAll().where { DebtTable.id eq row.id }.singleOrNull()
        if (existing == null) {
            DebtTable.insert {
                it[id] = row.id
                it[familyId] = row.familyId
                it[counterpartyName] = row.counterpartyName
                it[direction] = row.direction.name
                it[amount] = row.amountKopecks
                it[dueDate] = row.dueDate
                it[status] = row.status.name
                it[isDeleted] = row.isDeleted
                it[createdAt] = row.createdAt
                it[updatedAt] = row.updatedAt
            }
            accepted += AcceptedRef(TABLE_DEBT, row.id.toString())
            return
        }
        val serverUpdated = existing[DebtTable.updatedAt]
        if (serverUpdated > row.updatedAt) {
            conflicts += SyncConflict(
                table = TABLE_DEBT,
                id = row.id.toString(),
                serverBundle = SyncBundle(debts = listOf(existing.toDebt())),
            )
            return
        }
        DebtTable.update({ DebtTable.id eq row.id }) {
            it[counterpartyName] = row.counterpartyName
            it[direction] = row.direction.name
            it[amount] = row.amountKopecks
            it[dueDate] = row.dueDate
            it[status] = row.status.name
            it[isDeleted] = row.isDeleted
            it[updatedAt] = row.updatedAt
        }
        accepted += AcceptedRef(TABLE_DEBT, row.id.toString())
    }

    private fun upsertSubscription(
        familyScope: UUID,
        row: Subscription,
        accepted: MutableList<AcceptedRef>,
        conflicts: MutableList<SyncConflict>,
    ) {
        if (row.familyId != familyScope) throw ForbiddenException("Subscription belongs to a different family")
        val existing = SubscriptionTable.selectAll().where { SubscriptionTable.id eq row.id }.singleOrNull()
        if (existing == null) {
            SubscriptionTable.insert {
                it[id] = row.id
                it[familyId] = row.familyId
                it[name] = row.name
                it[amount] = row.amountKopecks
                it[billingPeriod] = row.billingPeriod.name
                it[nextChargeDate] = row.nextChargeDate
                it[categoryId] = row.categoryId
                it[isDeleted] = row.isDeleted
                it[createdAt] = row.createdAt
                it[updatedAt] = row.updatedAt
            }
            accepted += AcceptedRef(TABLE_SUBSCRIPTION, row.id.toString())
            return
        }
        val serverUpdated = existing[SubscriptionTable.updatedAt]
        if (serverUpdated > row.updatedAt) {
            conflicts += SyncConflict(
                table = TABLE_SUBSCRIPTION,
                id = row.id.toString(),
                serverBundle = SyncBundle(subscriptions = listOf(existing.toSubscription())),
            )
            return
        }
        SubscriptionTable.update({ SubscriptionTable.id eq row.id }) {
            it[name] = row.name
            it[amount] = row.amountKopecks
            it[billingPeriod] = row.billingPeriod.name
            it[nextChargeDate] = row.nextChargeDate
            it[categoryId] = row.categoryId
            it[isDeleted] = row.isDeleted
            it[updatedAt] = row.updatedAt
        }
        accepted += AcceptedRef(TABLE_SUBSCRIPTION, row.id.toString())
    }

    // --- ResultRow → domain mappers ---------------------------------------

    private fun ResultRow.toFamily() = Family(
        id = this[FamilyTable.id],
        name = this[FamilyTable.name],
        createdAt = this[FamilyTable.createdAt],
        updatedAt = this[FamilyTable.updatedAt],
        isDeleted = this[FamilyTable.isDeleted],
    )

    private fun ResultRow.toFamilyMember() = FamilyMember(
        id = this[FamilyMemberTable.id],
        familyId = this[FamilyMemberTable.familyId],
        userId = this[FamilyMemberTable.userId],
        role = FamilyRole.valueOf(this[FamilyMemberTable.role]),
        joinedAt = this[FamilyMemberTable.joinedAt],
        isDeleted = this[FamilyMemberTable.isDeleted],
    )

    private fun ResultRow.toAccount() = Account(
        id = this[AccountTable.id],
        familyId = this[AccountTable.familyId],
        name = this[AccountTable.name],
        type = this[AccountTable.type],
        currency = this[AccountTable.currency],
        initialBalanceKopecks = this[AccountTable.initialBalance],
        isArchived = this[AccountTable.isArchived],
        isDeleted = this[AccountTable.isDeleted],
        createdAt = this[AccountTable.createdAt],
        updatedAt = this[AccountTable.updatedAt],
    )

    private fun ResultRow.toCategory() = Category(
        id = this[CategoryTable.id],
        familyId = this[CategoryTable.familyId],
        parentCategoryId = this[CategoryTable.parentCategoryId],
        name = this[CategoryTable.name],
        type = CategoryType.valueOf(this[CategoryTable.type]),
        isMandatory = this[CategoryTable.isMandatory],
        isSystem = this[CategoryTable.isSystem],
        icon = this[CategoryTable.icon],
        color = this[CategoryTable.color],
        isArchived = this[CategoryTable.isArchived],
        isDeleted = this[CategoryTable.isDeleted],
        createdAt = this[CategoryTable.createdAt],
        updatedAt = this[CategoryTable.updatedAt],
    )

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

    private fun ResultRow.toBudget() = Budget(
        id = this[BudgetTable.id],
        familyId = this[BudgetTable.familyId],
        categoryId = this[BudgetTable.categoryId],
        periodType = BudgetPeriodType.valueOf(this[BudgetTable.periodType]),
        periodStart = this[BudgetTable.periodStart],
        plannedAmountKopecks = this[BudgetTable.plannedAmount],
        isDeleted = this[BudgetTable.isDeleted],
        createdAt = this[BudgetTable.createdAt],
        updatedAt = this[BudgetTable.updatedAt],
    )

    private fun ResultRow.toGoal() = Goal(
        id = this[GoalTable.id],
        familyId = this[GoalTable.familyId],
        name = this[GoalTable.name],
        targetAmountKopecks = this[GoalTable.targetAmount],
        currentAmountKopecks = this[GoalTable.currentAmount],
        targetDate = this[GoalTable.targetDate],
        isDeleted = this[GoalTable.isDeleted],
        createdAt = this[GoalTable.createdAt],
        updatedAt = this[GoalTable.updatedAt],
    )

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

    private fun ResultRow.toSubscription() = Subscription(
        id = this[SubscriptionTable.id],
        familyId = this[SubscriptionTable.familyId],
        name = this[SubscriptionTable.name],
        amountKopecks = this[SubscriptionTable.amount],
        billingPeriod = SubscriptionPeriod.valueOf(this[SubscriptionTable.billingPeriod]),
        nextChargeDate = this[SubscriptionTable.nextChargeDate],
        categoryId = this[SubscriptionTable.categoryId],
        isDeleted = this[SubscriptionTable.isDeleted],
        createdAt = this[SubscriptionTable.createdAt],
        updatedAt = this[SubscriptionTable.updatedAt],
    )

    companion object {
        const val TABLE_ACCOUNT = "account"
        const val TABLE_CATEGORY = "category"
        const val TABLE_TRANSACTION = "transaction"
        const val TABLE_BUDGET = "budget"
        const val TABLE_GOAL = "goal"
        const val TABLE_DEBT = "debt"
        const val TABLE_SUBSCRIPTION = "subscription"
    }
}

// Suppress unused-Clock helper warning: Clock is imported to keep parity with other
// repositories and left available for future serverTime injection.
@Suppress("unused")
private val clockRef: Clock = Clock.System
