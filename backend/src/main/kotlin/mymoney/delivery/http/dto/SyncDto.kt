package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.model.Account
import mymoney.domain.model.Budget
import mymoney.domain.model.BudgetPeriodType
import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType
import mymoney.domain.model.Debt
import mymoney.domain.model.DebtDirection
import mymoney.domain.model.DebtPayment
import mymoney.domain.model.DebtStatus
import mymoney.domain.model.Family
import mymoney.domain.model.FamilyMember
import mymoney.domain.model.FamilyRole
import mymoney.domain.model.Goal
import mymoney.domain.model.Subscription
import mymoney.domain.model.SubscriptionPeriod
import mymoney.domain.model.SyncBundle
import mymoney.domain.model.SyncPullResult
import mymoney.domain.model.SyncPushOutcome
import mymoney.domain.model.Transaction
import mymoney.domain.model.TransactionType
import java.util.UUID

/**
 * DTOs used only by /v1/sync/{pull,push}. Separate from the CRUD DTOs on
 * purpose — sync must transport every column verbatim, while CRUD DTOs stay
 * shaped for the specific request/response they serve.
 */

@Serializable
data class SyncAccountDto(
    val id: String,
    val familyId: String,
    val name: String,
    val type: String,
    val currency: String,
    val initialBalanceKopecks: Long,
    val creditLimitKopecks: Long? = null,
    val isArchived: Boolean,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class SyncCategoryDto(
    val id: String,
    val familyId: String,
    val parentCategoryId: String? = null,
    val name: String,
    val type: String,
    val isMandatory: Boolean,
    val isSystem: Boolean,
    val icon: String? = null,
    val color: String? = null,
    val isArchived: Boolean,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class SyncTransactionDto(
    val id: String,
    val familyId: String,
    val accountId: String,
    val categoryId: String? = null,
    val type: String,
    val targetAccountId: String? = null,
    val amountKopecks: Long,
    val currency: String,
    val occurredAt: Instant,
    val comment: String? = null,
    val attachmentPhotoPath: String? = null,
    val createdBy: String,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean,
)

@Serializable
data class SyncBudgetDto(
    val id: String,
    val familyId: String,
    val categoryId: String,
    val periodType: String,
    val periodStart: Instant,
    val plannedAmountKopecks: Long,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class SyncGoalDto(
    val id: String,
    val familyId: String,
    val name: String,
    val targetAmountKopecks: Long,
    val currentAmountKopecks: Long,
    val targetDate: Instant? = null,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class SyncFamilyDto(
    val id: String,
    val name: String,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean,
)

@Serializable
data class SyncFamilyMemberDto(
    val id: String,
    val familyId: String,
    val userId: String,
    val role: String,
    val joinedAt: Instant,
    val isDeleted: Boolean,
)

@Serializable
data class SyncDebtDto(
    val id: String,
    val familyId: String,
    val counterpartyName: String,
    val direction: String,
    val amountKopecks: Long,
    val interestRate: Double = 0.0,
    val dueDate: Instant? = null,
    val status: String,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class SyncDebtPaymentDto(
    val id: String,
    val debtId: String,
    val dueDate: Instant,
    val plannedAmountKopecks: Long,
    val isPaid: Boolean,
    val paidAt: Instant? = null,
    val transactionId: String? = null,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class SyncSubscriptionDto(
    val id: String,
    val familyId: String,
    val name: String,
    val amountKopecks: Long,
    val billingPeriod: String,
    val nextChargeDate: Instant,
    val categoryId: String? = null,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class SyncBundleDto(
    val accounts: List<SyncAccountDto> = emptyList(),
    val categories: List<SyncCategoryDto> = emptyList(),
    val transactions: List<SyncTransactionDto> = emptyList(),
    val budgets: List<SyncBudgetDto> = emptyList(),
    val goals: List<SyncGoalDto> = emptyList(),
    val debts: List<SyncDebtDto> = emptyList(),
    val debtPayments: List<SyncDebtPaymentDto> = emptyList(),
    val subscriptions: List<SyncSubscriptionDto> = emptyList(),
    val families: List<SyncFamilyDto> = emptyList(),
    val familyMembers: List<SyncFamilyMemberDto> = emptyList(),
)

@Serializable
data class SyncPullResponse(
    val serverTime: Instant,
    val bundle: SyncBundleDto,
)

@Serializable
data class SyncPushRequest(
    val bundle: SyncBundleDto,
)

@Serializable
data class SyncAcceptedRefDto(val table: String, val id: String)

@Serializable
data class SyncConflictDto(
    val table: String,
    val id: String,
    val serverBundle: SyncBundleDto,
)

@Serializable
data class SyncPushResponse(
    val serverTime: Instant,
    val accepted: List<SyncAcceptedRefDto>,
    val conflicts: List<SyncConflictDto>,
)

// --- Mappers: domain → DTO --------------------------------------------------

fun Account.toSyncDto() = SyncAccountDto(
    id = id.toString(),
    familyId = familyId.toString(),
    name = name,
    type = type,
    currency = currency,
    initialBalanceKopecks = initialBalanceKopecks,
    creditLimitKopecks = creditLimitKopecks,
    isArchived = isArchived,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Category.toSyncDto() = SyncCategoryDto(
    id = id.toString(),
    familyId = familyId.toString(),
    parentCategoryId = parentCategoryId?.toString(),
    name = name,
    type = type.name,
    isMandatory = isMandatory,
    isSystem = isSystem,
    icon = icon,
    color = color,
    isArchived = isArchived,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Transaction.toSyncDto() = SyncTransactionDto(
    id = id.toString(),
    familyId = familyId.toString(),
    accountId = accountId.toString(),
    categoryId = categoryId?.toString(),
    type = type.name,
    targetAccountId = targetAccountId?.toString(),
    amountKopecks = amountKopecks,
    currency = currency,
    occurredAt = occurredAt,
    comment = comment,
    attachmentPhotoPath = attachmentPhotoPath,
    createdBy = createdBy.toString(),
    createdAt = createdAt,
    updatedAt = updatedAt,
    isDeleted = isDeleted,
)

fun Budget.toSyncDto() = SyncBudgetDto(
    id = id.toString(),
    familyId = familyId.toString(),
    categoryId = categoryId.toString(),
    periodType = periodType.name,
    periodStart = periodStart,
    plannedAmountKopecks = plannedAmountKopecks,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Debt.toSyncDto() = SyncDebtDto(
    id = id.toString(),
    familyId = familyId.toString(),
    counterpartyName = counterpartyName,
    direction = direction.name,
    amountKopecks = amountKopecks,
    interestRate = interestRate,
    dueDate = dueDate,
    status = status.name,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun DebtPayment.toSyncDto() = SyncDebtPaymentDto(
    id = id.toString(),
    debtId = debtId.toString(),
    dueDate = dueDate,
    plannedAmountKopecks = plannedAmountKopecks,
    isPaid = isPaid,
    paidAt = paidAt,
    transactionId = transactionId?.toString(),
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Subscription.toSyncDto() = SyncSubscriptionDto(
    id = id.toString(),
    familyId = familyId.toString(),
    name = name,
    amountKopecks = amountKopecks,
    billingPeriod = billingPeriod.name,
    nextChargeDate = nextChargeDate,
    categoryId = categoryId?.toString(),
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Goal.toSyncDto() = SyncGoalDto(
    id = id.toString(),
    familyId = familyId.toString(),
    name = name,
    targetAmountKopecks = targetAmountKopecks,
    currentAmountKopecks = currentAmountKopecks,
    targetDate = targetDate,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun Family.toSyncDto() = SyncFamilyDto(
    id = id.toString(),
    name = name,
    createdAt = createdAt,
    updatedAt = updatedAt,
    isDeleted = isDeleted,
)

fun FamilyMember.toSyncDto() = SyncFamilyMemberDto(
    id = id.toString(),
    familyId = familyId.toString(),
    userId = userId.toString(),
    role = role.name,
    joinedAt = joinedAt,
    isDeleted = isDeleted,
)

fun SyncBundle.toDto() = SyncBundleDto(
    accounts = accounts.map { it.toSyncDto() },
    categories = categories.map { it.toSyncDto() },
    transactions = transactions.map { it.toSyncDto() },
    budgets = budgets.map { it.toSyncDto() },
    goals = goals.map { it.toSyncDto() },
    debts = debts.map { it.toSyncDto() },
    debtPayments = debtPayments.map { it.toSyncDto() },
    subscriptions = subscriptions.map { it.toSyncDto() },
    families = families.map { it.toSyncDto() },
    familyMembers = familyMembers.map { it.toSyncDto() },
)

fun SyncPullResult.toResponse() = SyncPullResponse(
    serverTime = serverTime,
    bundle = bundle.toDto(),
)

fun SyncPushOutcome.toResponse() = SyncPushResponse(
    serverTime = serverTime,
    accepted = accepted.map { SyncAcceptedRefDto(it.table, it.id) },
    conflicts = conflicts.map {
        SyncConflictDto(table = it.table, id = it.id, serverBundle = it.serverBundle.toDto())
    },
)

// --- Mappers: DTO → domain --------------------------------------------------

fun SyncAccountDto.toDomain() = Account(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    name = name,
    type = type,
    currency = currency,
    initialBalanceKopecks = initialBalanceKopecks,
    creditLimitKopecks = creditLimitKopecks,
    isArchived = isArchived,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun SyncCategoryDto.toDomain() = Category(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    parentCategoryId = parentCategoryId?.let { UUID.fromString(it) },
    name = name,
    type = CategoryType.valueOf(type),
    isMandatory = isMandatory,
    isSystem = isSystem,
    icon = icon,
    color = color,
    isArchived = isArchived,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun SyncTransactionDto.toDomain() = Transaction(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    accountId = UUID.fromString(accountId),
    categoryId = categoryId?.let { UUID.fromString(it) },
    type = TransactionType.valueOf(type),
    targetAccountId = targetAccountId?.let { UUID.fromString(it) },
    amountKopecks = amountKopecks,
    currency = currency,
    occurredAt = occurredAt,
    comment = comment,
    attachmentPhotoPath = attachmentPhotoPath,
    createdBy = UUID.fromString(createdBy),
    createdAt = createdAt,
    updatedAt = updatedAt,
    isDeleted = isDeleted,
)

fun SyncBudgetDto.toDomain() = Budget(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    categoryId = UUID.fromString(categoryId),
    periodType = BudgetPeriodType.valueOf(periodType),
    periodStart = periodStart,
    plannedAmountKopecks = plannedAmountKopecks,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun SyncGoalDto.toDomain() = Goal(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    name = name,
    targetAmountKopecks = targetAmountKopecks,
    currentAmountKopecks = currentAmountKopecks,
    targetDate = targetDate,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun SyncFamilyDto.toDomain() = Family(
    id = UUID.fromString(id),
    name = name,
    createdAt = createdAt,
    updatedAt = updatedAt,
    isDeleted = isDeleted,
)

fun SyncFamilyMemberDto.toDomain() = FamilyMember(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    userId = UUID.fromString(userId),
    role = FamilyRole.valueOf(role),
    joinedAt = joinedAt,
    isDeleted = isDeleted,
)

fun SyncDebtDto.toDomain() = Debt(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    counterpartyName = counterpartyName,
    direction = DebtDirection.valueOf(direction),
    amountKopecks = amountKopecks,
    interestRate = interestRate,
    dueDate = dueDate,
    status = DebtStatus.valueOf(status),
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun SyncDebtPaymentDto.toDomain() = DebtPayment(
    id = UUID.fromString(id),
    debtId = UUID.fromString(debtId),
    dueDate = dueDate,
    plannedAmountKopecks = plannedAmountKopecks,
    isPaid = isPaid,
    paidAt = paidAt,
    transactionId = transactionId?.let { UUID.fromString(it) },
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun SyncSubscriptionDto.toDomain() = Subscription(
    id = UUID.fromString(id),
    familyId = UUID.fromString(familyId),
    name = name,
    amountKopecks = amountKopecks,
    billingPeriod = SubscriptionPeriod.valueOf(billingPeriod),
    nextChargeDate = nextChargeDate,
    categoryId = categoryId?.let { UUID.fromString(it) },
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun SyncBundleDto.toDomain() = SyncBundle(
    accounts = accounts.map { it.toDomain() },
    categories = categories.map { it.toDomain() },
    transactions = transactions.map { it.toDomain() },
    budgets = budgets.map { it.toDomain() },
    goals = goals.map { it.toDomain() },
    debts = debts.map { it.toDomain() },
    debtPayments = debtPayments.map { it.toDomain() },
    subscriptions = subscriptions.map { it.toDomain() },
    families = families.map { it.toDomain() },
    familyMembers = familyMembers.map { it.toDomain() },
)
