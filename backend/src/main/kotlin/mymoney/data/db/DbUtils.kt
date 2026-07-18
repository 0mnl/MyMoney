package mymoney.data.db

import kotlinx.coroutines.Dispatchers
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.transactions.experimental.newSuspendedTransaction

/**
 * Runs [block] inside an Exposed transaction on Dispatchers.IO so the calling
 * coroutine is not blocked. All repository methods route their SQL through
 * this helper.
 */
suspend fun <T> dbQuery(db: Database, block: suspend () -> T): T =
    newSuspendedTransaction(Dispatchers.IO, db) { block() }
