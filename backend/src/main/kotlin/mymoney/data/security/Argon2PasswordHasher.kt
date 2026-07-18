package mymoney.data.security

import de.mkammerer.argon2.Argon2Factory
import mymoney.domain.security.PasswordHasher

/**
 * argon2id parameters chosen for a defensible baseline on server hardware
 * (see OWASP Password Storage Cheat Sheet, 2024):
 *   - iterations (t):  3
 *   - memory (m):      64 MiB (65536 KiB)
 *   - parallelism (p): 1
 * If auth latency ever becomes a concern, tune these together, not in isolation.
 */
class Argon2PasswordHasher : PasswordHasher {

    private val argon2 = Argon2Factory.create(Argon2Factory.Argon2Types.ARGON2id)
    private val iterations = 3
    private val memoryKib = 65_536
    private val parallelism = 1

    override fun hash(plain: String): String {
        val chars = plain.toCharArray()
        return try {
            argon2.hash(iterations, memoryKib, parallelism, chars)
        } finally {
            argon2.wipeArray(chars)
        }
    }

    override fun verify(plain: String, storedHash: String): Boolean {
        val chars = plain.toCharArray()
        return try {
            argon2.verify(storedHash, chars)
        } finally {
            argon2.wipeArray(chars)
        }
    }
}
