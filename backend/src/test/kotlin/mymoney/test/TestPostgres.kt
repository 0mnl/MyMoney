package mymoney.test

import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName

/**
 * Shared Postgres for the whole JVM lifetime of a test run.
 *
 * By default spins up a Testcontainers PostgreSQL. When the environment
 * cannot host TC (e.g. Docker Desktop on Windows exposes only the
 * `dockerDesktopLinuxEngine` pipe, which TC 1.20.4 does not detect),
 * setting `TEST_DB_URL` (plus `TEST_DB_USER`, `TEST_DB_PASSWORD`) makes
 * tests reuse an externally-managed Postgres instead.
 *
 * Tests isolate themselves by using unique emails / IDs, not by wiping
 * the database — this contract holds in both modes.
 */
object TestPostgres {

    private val externalUrl: String? = System.getenv("TEST_DB_URL")

    val container: PostgreSQLContainer<*> = if (externalUrl != null) {
        ExternalPostgresContainer(
            url = externalUrl,
            user = System.getenv("TEST_DB_USER") ?: "postgres",
            password = System.getenv("TEST_DB_PASSWORD") ?: "postgres",
        )
    } else {
        PostgreSQLContainer<Nothing>("postgres:16-alpine").apply {
            withDatabaseName("mymoney_test")
            withUsername("test")
            withPassword("test")
            start()
        }
    }

    /**
     * Adapter that satisfies the [PostgreSQLContainer] surface used by tests
     * (`jdbcUrl`, `username`, `password`) without actually starting a
     * container — it just points at an already-running Postgres.
     */
    private class ExternalPostgresContainer(
        private val url: String,
        private val user: String,
        private val password: String,
    ) : PostgreSQLContainer<ExternalPostgresContainer>(
        DockerImageName.parse("postgres:16-alpine"),
    ) {
        override fun start() { /* no-op — external DB */ }
        override fun stop() { /* no-op — external DB */ }
        override fun getJdbcUrl(): String = url
        override fun getUsername(): String = user
        override fun getPassword(): String = password
    }
}
