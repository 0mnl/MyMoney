import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Категории')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (allCats) {
          final income = allCats
              .where((c) => c.type == CategoryType.income && !c.isDeleted && !c.isArchived)
              .toList();
          final expense = allCats
              .where((c) => c.type == CategoryType.expense && !c.isDeleted && !c.isArchived)
              .toList();

          return ListView(
            children: [
              _SectionHeader(
                title: 'Доходы',
                onAdd: () => _openAddSheet(context, ref, CategoryType.income),
              ),
              if (income.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Нет категорий доходов',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...income.map((c) => _CategoryTile(
                      category: c,
                      onDelete: () => _confirmDelete(context, ref, c),
                      onEdit: () => _openEditSheet(context, ref, c),
                    )),
              const Divider(height: 1),
              _SectionHeader(
                title: 'Расходы',
                onAdd: () => _openAddSheet(context, ref, CategoryType.expense),
              ),
              if (expense.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Нет категорий расходов',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...expense.map((c) => _CategoryTile(
                      category: c,
                      onDelete: () => _confirmDelete(context, ref, c),
                      onEdit: () => _openEditSheet(context, ref, c),
                    )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddSheet(
    BuildContext context,
    WidgetRef ref,
    CategoryType type,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CategorySheet(type: type),
      ),
    );
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CategorySheet(type: category.type, existing: category),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    if (category.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Системные категории удалить нельзя')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить «${category.name}»?'),
        content: const Text('Категория будет скрыта. Операции по ней сохранятся.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = await ref.read(categoryRepositoryProvider.future);
      await repo.softDelete(category.id);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Добавить'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onDelete,
    required this.onEdit,
  });
  final Category category;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  static const _iconMap = <String, IconData>{
    'work': Icons.work,
    'attach_money': Icons.attach_money,
    'redeem': Icons.redeem,
    'trending_up': Icons.trending_up,
    'shopping_cart': Icons.shopping_cart,
    'home': Icons.home,
    'bolt': Icons.bolt,
    'wifi': Icons.wifi,
    'directions_bus': Icons.directions_bus,
    'restaurant': Icons.restaurant,
    'healing': Icons.healing,
    'checkroom': Icons.checkroom,
    'sports_esports': Icons.sports_esports,
    'school': Icons.school,
    'more_horiz': Icons.more_horiz,
    'category': Icons.category,
  };

  @override
  Widget build(BuildContext context) {
    final iconData = _iconMap[category.icon] ?? Icons.category;
    final color = _parseColor(category.color) ??
        (category.type == CategoryType.income
            ? Colors.green
            : Colors.orange);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(iconData, color: color, size: 20),
      ),
      title: Text(category.name),
      subtitle: category.isSystem ? const Text('Системная') : null,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Переименовать')),
          if (!category.isSystem)
            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
        ],
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    try {
      final val = hex.replaceFirst('#', '');
      return Color(int.parse('FF$val', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// ─── Add / Edit sheet ────────────────────────────────────────────────────────

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.type, this.existing});
  final CategoryType type;
  final Category? existing;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final TextEditingController _nameCtrl;
  String _selectedIcon = 'category';

  static const _icons = <String>[
    'category',
    'shopping_cart',
    'restaurant',
    'home',
    'bolt',
    'wifi',
    'directions_bus',
    'healing',
    'checkroom',
    'sports_esports',
    'school',
    'more_horiz',
    'work',
    'attach_money',
    'redeem',
    'trending_up',
  ];

  static const _iconMap = <String, IconData>{
    'work': Icons.work,
    'attach_money': Icons.attach_money,
    'redeem': Icons.redeem,
    'trending_up': Icons.trending_up,
    'shopping_cart': Icons.shopping_cart,
    'home': Icons.home,
    'bolt': Icons.bolt,
    'wifi': Icons.wifi,
    'directions_bus': Icons.directions_bus,
    'restaurant': Icons.restaurant,
    'healing': Icons.healing,
    'checkroom': Icons.checkroom,
    'sports_esports': Icons.sports_esports,
    'school': Icons.school,
    'more_horiz': Icons.more_horiz,
    'category': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedIcon = widget.existing?.icon ?? 'category';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final typeLabel =
        widget.type == CategoryType.income ? 'доход' : 'расход';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEdit ? 'Изменить категорию' : 'Новая категория ($typeLabel)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          const Text('Иконка', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((key) {
              final isSelected = key == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = key),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _iconMap[key] ?? Icons.category,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    size: 22,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(isEdit ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final repo = await ref.read(categoryRepositoryProvider.future);
    final session = await ref.read(bootstrapProvider.future);
    final now = DateTime.now().toUtc();

    if (widget.existing != null) {
      await repo.update(
        widget.existing!.copyWith(name: name, icon: _selectedIcon, updatedAt: now),
      );
    } else {
      await repo.create(Category(
        id: const Uuid().v4(),
        familyId: session.familyId,
        name: name,
        type: widget.type,
        icon: _selectedIcon,
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }
}
