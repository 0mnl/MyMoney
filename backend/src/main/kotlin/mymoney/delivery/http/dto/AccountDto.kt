package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.model.Account

@Serializable
data class AccountDto(
    val id: String,
    val familyId: String,
    val name: String,
    val type: String,
    val currency: String,
    val initialBalance: Long,      // kopecks
    val creditLimit: Long? = null, // kopecks, null для не-кредитных счетов (Bible v2 §7.2)
    val isArchived: Boolean,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class CreateAccountRequest(
    val id: String,               // client-generated UUID (see ADR-0005)
    val name: String,
    val type: String,
    val currency: String = "RUB",
    val initialBalance: Long = 0L,
    val creditLimit: Long? = null,
)

@Serializable
data class UpdateAccountRequest(
    val name: String,
    val type: String,
    val currency: String,
    val initialBalance: Long,
    val creditLimit: Long? = null,
)

@Serializable
data class ArchiveAccountRequest(
    val archived: Boolean,
)

fun Account.toDto() = AccountDto(
    id = id.toString(),
    familyId = familyId.toString(),
    name = name,
    type = type,
    currency = currency,
    initialBalance = initialBalanceKopecks,
    creditLimit = creditLimitKopecks,
    isArchived = isArchived,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)
