package mymoney.domain.usecase.auth

private val EMAIL_REGEX = Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
private const val MIN_PASSWORD_LENGTH = 8

fun isValidEmail(email: String): Boolean = EMAIL_REGEX.matches(email.trim())

fun isValidPassword(password: String): Boolean = password.length >= MIN_PASSWORD_LENGTH

fun normalizeEmail(email: String): String = email.trim().lowercase()
