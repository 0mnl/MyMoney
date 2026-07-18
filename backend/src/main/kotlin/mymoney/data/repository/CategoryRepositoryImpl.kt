package mymoney.data.repository

import kotlinx.datetime.Clock
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.CategoryTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType
import mymoney.domain.repository.CategoryRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.andWhere
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class CategoryRepositoryImpl(private val db: Database) : CategoryRepository {

    override suspend fun create(category: Category): Category = dbQuery(db) {
        CategoryTable.insert {
            it[id] = category.id
            it[familyId] = category.familyId
            it[parentCategoryId] = category.parentCategoryId
            it[name] = category.name
            it[type] = category.type.name
            it[isMandatory] = category.isMandatory
            it[isSystem] = category.isSystem
            it[icon] = category.icon
            it[color] = category.color
            it[isArchived] = category.isArchived
            it[isDeleted] = category.isDeleted
            it[createdAt] = category.createdAt
            it[updatedAt] = category.updatedAt
        }
        category
    }

    override suspend fun findById(id: UUID): Category? = dbQuery(db) {
        CategoryTable.selectAll()
            .where { CategoryTable.id eq id }
            .singleOrNull()
            ?.toCategory()
    }

    override suspend fun listByFamily(
        familyId: UUID,
        type: CategoryType?,
        includeArchived: Boolean,
    ): List<Category> = dbQuery(db) {
        val base = CategoryTable.selectAll()
            .where { (CategoryTable.familyId eq familyId) and (CategoryTable.isDeleted eq false) }
        if (!includeArchived) base.andWhere { CategoryTable.isArchived eq false }
        if (type != null) base.andWhere { CategoryTable.type eq type.name }
        base.orderBy(CategoryTable.isSystem to SortOrder.DESC, CategoryTable.name to SortOrder.ASC)
            .map { it.toCategory() }
    }

    override suspend fun update(category: Category): Category = dbQuery(db) {
        val updated = CategoryTable.update({ CategoryTable.id eq category.id }) {
            it[name] = category.name
            // Type and parent are intentionally immutable — enforced by the use case,
            // repeated here as a defensive last line so a rogue caller cannot mutate them.
            it[isMandatory] = category.isMandatory
            it[icon] = category.icon
            it[color] = category.color
            it[isArchived] = category.isArchived
            it[isDeleted] = category.isDeleted
            it[updatedAt] = category.updatedAt
        }
        if (updated == 0) throw NotFoundException("category", category.id.toString())
        category
    }

    override suspend fun softDelete(id: UUID): Unit = dbQuery(db) {
        val now = Clock.System.now()
        val updated = CategoryTable.update({ CategoryTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = now
        }
        if (updated == 0) throw NotFoundException("category", id.toString())
    }

    override suspend fun hasActiveChildren(parentId: UUID): Boolean = dbQuery(db) {
        !CategoryTable.selectAll()
            .where { (CategoryTable.parentCategoryId eq parentId) and (CategoryTable.isDeleted eq false) }
            .limit(1)
            .empty()
    }

    private fun ResultRow.toCategory() = Category(
        id = this[CategoryTable.id],
        familyId = this[CategoryTable.familyId],
        parentCategoryId = this[CategoryTable.parentCategoryId],
        name = this[CategoryTable.name],
        type = CategoryType.valueOf(this[CategoryTable.type]),
        isMandatory = this[CategoryTable.isMandatory],
        isSystem = this[CategoryTable.isSystem],
        icon = this[CategoryTable.icon],
        color = this[CategoryTable.color],
        isArchived = this[CategoryTable.isArchived],
        isDeleted = this[CategoryTable.isDeleted],
        createdAt = this[CategoryTable.createdAt],
        updatedAt = this[CategoryTable.updatedAt],
    )
}
