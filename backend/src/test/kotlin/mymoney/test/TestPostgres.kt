package mymoney.test

import org.testcontainers.containers.PostgreSQLContainer

/**
 * Shared Postgres container reused across the whole JVM lifetime of a test run.
 * Starting a fresh container per test class adds ~5 seconds each — we amortize
 * by sharing. Tests are expected to isolate themselves by using unique
 * emails / IDs, not by wiping the database.
 */
object TestPostgres {
    val container: PostgreSQLContainer<*> = PostgreSQLContainer("postgres:16-alpine")
        .withDatabaseName("mymoney_test")
        .withUsername("test")
        .withPassword("test")
        .apply { start() }
}
