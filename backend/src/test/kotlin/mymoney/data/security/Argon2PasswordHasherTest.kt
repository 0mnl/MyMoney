package mymoney.data.security

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class Argon2PasswordHasherTest {

    private val hasher = Argon2PasswordHasher()

    @Test
    fun `hash then verify with the same password returns true`() {
        val hash = hasher.hash("correct horse battery staple")
        assertTrue(hasher.verify("correct horse battery staple", hash))
    }

    @Test
    fun `verify with wrong password returns false`() {
        val hash = hasher.hash("secret")
        assertFalse(hasher.verify("wrong", hash))
    }

    @Test
    fun `two hashes of the same password differ due to random salt`() {
        val a = hasher.hash("same")
        val b = hasher.hash("same")
        assertNotEquals(a, b)
        assertTrue(hasher.verify("same", a))
        assertTrue(hasher.verify("same", b))
    }
}
