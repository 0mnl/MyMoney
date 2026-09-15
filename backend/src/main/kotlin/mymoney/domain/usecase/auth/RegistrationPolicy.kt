package mymoney.domain.usecase.auth

/**
 * Решает, разрешено ли заводить аккаунт на этот адрес.
 *
 * [allowedEntries] приходит из `REGISTRATION_ALLOWLIST`. Элемент — либо
 * полный адрес (`ivan@example.com`), либо домен (`@example.com`), который
 * пускает всех его владельцев.
 *
 * Пустой список означает открытую регистрацию: сервер на одного человека и
 * публичный сервис — один и тот же код, и «закрыто по умолчанию» сломало бы
 * dev-окружение, где список задавать неоткуда. Чтобы открытость не включилась
 * молча, `Application.module` пишет в лог, в каком режиме стартовал сервер.
 */
class RegistrationPolicy(allowedEntries: List<String>) {

    private val entries = allowedEntries.map { it.trim().lowercase() }.filter { it.isNotBlank() }

    val isRestricted: Boolean get() = entries.isNotEmpty()

    fun allows(email: String): Boolean {
        if (!isRestricted) return true
        val normalized = email.trim().lowercase()
        val domain = normalized.substringAfter('@', missingDelimiterValue = "")
        return entries.any { entry ->
            if (entry.startsWith("@")) {
                domain.isNotEmpty() && domain == entry.removePrefix("@")
            } else {
                normalized == entry
            }
        }
    }
}
