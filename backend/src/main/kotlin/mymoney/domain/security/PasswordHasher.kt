package mymoney.domain.security

interface PasswordHasher {
    fun hash(plain: String): String
    fun verify(plain: String, storedHash: String): Boolean
}
