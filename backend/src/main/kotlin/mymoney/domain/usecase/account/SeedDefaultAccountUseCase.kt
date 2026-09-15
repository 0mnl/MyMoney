package mymoney.domain.usecase.account

import kotlinx.datetime.Clock
import mymoney.domain.model.Account
import mymoney.domain.repository.AccountRepository
import java.util.UUID

/**
 * Даёт новой семье один счёт «Наличные», чтобы приложением можно было
 * пользоваться сразу после регистрации.
 *
 * Почему на сервере, а не на клиенте: клиент сеет счёт только в офлайн-режиме
 * (`bootstrapProvider`), а при включённой синхронизации намеренно пропускает
 * сид — всё содержимое семьи должно приезжать с сервера, иначе два устройства
 * создали бы два разных «Наличных» с разными id. Но счёт сервер до сих пор не
 * заводил, и свежезарегистрированный пользователь получал каталог категорий
 * без единого счёта — а экран «Новая операция» требует и то, и другое. То
 * есть добавить операцию было физически нельзя.
 *
 * Валюта — рубль (ADR-0002, ADR-0006), начальный баланс — ноль.
 */
class SeedDefaultAccountUseCase(
    private val accounts: AccountRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(familyId: UUID) {
        val now = clock.now()
        accounts.create(
            Account(
                id = UUID.randomUUID(),
                familyId = familyId,
                name = DEFAULT_ACCOUNT_NAME,
                type = DEFAULT_ACCOUNT_TYPE,
                currency = "RUB",
                initialBalanceKopecks = 0,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }

    companion object {
        /** Совпадает с клиентским офлайн-сидом (`SystemCategoriesCatalog.defaultAccount`). */
        const val DEFAULT_ACCOUNT_NAME = "Наличные"
        const val DEFAULT_ACCOUNT_TYPE = "cash"
    }
}
