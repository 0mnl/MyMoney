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
)

@Serializable
data class UpdateAccountRequest(
    val name: String,
    val type: String,
    val currency: String,
    val initialBalance: Long,
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
    isArchived = isArchived,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)
