package mymoney.domain.usecase.auth

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RegistrationPolicyTest {

    @Test
    fun `empty allowlist lets everyone register`() {
        val policy = RegistrationPolicy(emptyList())

        assertFalse(policy.isRestricted)
        assertTrue(policy.allows("anyone@example.com"))
    }

    @Test
    fun `exact address is matched case-insensitively`() {
        val policy = RegistrationPolicy(listOf("Ivan@Example.COM"))

        assertTrue(policy.allows("ivan@example.com"))
        assertTrue(policy.allows("  IVAN@EXAMPLE.COM  "))
        assertFalse(policy.allows("maria@example.com"))
    }

    @Test
    fun `domain entry admits every address of that domain`() {
        val policy = RegistrationPolicy(listOf("@example.com"))

        assertTrue(policy.allows("ivan@example.com"))
        assertTrue(policy.allows("maria@example.com"))
        assertFalse(policy.allows("ivan@other.com"))
    }

    @Test
    fun `domain entry does not match a lookalike suffix`() {
        val policy = RegistrationPolicy(listOf("@example.com"))

        // Наивная проверка через endsWith пропустила бы эти два адреса —
        // а они принадлежат совершенно другим владельцам доменов.
        assertFalse(policy.allows("ivan@notexample.com"))
        assertFalse(policy.allows("ivan@example.com.evil.net"))
    }

    @Test
    fun `blank entries in the list are ignored`() {
        // REGISTRATION_ALLOWLIST="a@x.com, ,b@x.com," — типичный результат
        // ручного редактирования .env. Пустой элемент не должен превращаться
        // в правило, совпадающее с чем попало.
        val policy = RegistrationPolicy(listOf("a@x.com", " ", "b@x.com", ""))

        assertTrue(policy.isRestricted)
        assertTrue(policy.allows("a@x.com"))
        assertTrue(policy.allows("b@x.com"))
        assertFalse(policy.allows("c@x.com"))
    }
}
