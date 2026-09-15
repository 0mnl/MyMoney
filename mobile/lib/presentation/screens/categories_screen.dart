import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';
import '../theme/app_ui.dart';
import '../widgets/category_icon.dart';

/// Показываемый тип категорий. Раньше оба списка жили на одном экране друг
/// под другом; переключатель короче и совпадает с тем, как выбирается тип
/// в «Новой операции».
final _typeProvider = StateProvider<CategoryType>((_) => CategoryType.expense);

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final type = ref.watch(_typeProvider);

    return MmScreen(
      title: 'Категории',
      trailing: MmCircleButton(
        icon: Icons.add,
        tooltip: 'Новая категория',
        onTap: () => categoriesAsync.whenData((all) {
          _openSheet(
            context,
            type: type,
            all: all.where((c) => !c.isDeleted).toList(),
          );
        }),
      ),
      headerBottom: MmSegmented<CategoryType>(
        items: const [
          (CategoryType.expense, 'Расходы'),
          (CategoryType.income, 'Доходы'),
        ],
        selected: type,
        onChanged: (v) => ref.read(_typeProvider.notifier).state = v,
      ),
      child: categoriesAsync.when(
        loading: () => const MmLoading(),
        error: (e, _) => MmError(e),
        data: (allCats) {
          final all = allCats.where((c) => !c.isDeleted).toList();
          final visible =
              all.where((c) => !c.isArchived && c.type == type).toList();
          final archived =
              all.where((c) => c.isArchived && c.type == type).toList();

          if (visible.isEmpty && archived.isEmpty) {
            return MmEmptyState(
              icon: Icons.category_outlined,
              title: type == CategoryType.expense
                  ? 'Нет категорий расходов'
                  : 'Нет категорий доходов',
              message: 'Категории помогают понять, куда уходят деньги.',
              actionLabel: 'Добавить категорию',
              onAction: () => _openSheet(context, type: type, all: all),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              ..._buildTree(context, ref, visible, all),

              // Архив показываем здесь же: иначе заархивированную категорию
              // нельзя было бы вернуть — она исчезала из всех списков.
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 12),
                const MmSectionHeader(title: 'В архиве'),
                const SizedBox(height: 12),
                Opacity(
                  opacity: 0.55,
                  child: Column(
                    children: _buildTree(context, ref, archived, all),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Нажатие — редактирование, долгое нажатие — удаление. '
                  'Системные категории удалить нельзя.',
                  style: MmType.caption,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Раскладывает плоский список в два уровня: родители, под каждым — его
  /// подкатегории с отступом. Глубже двух уровней не идём: схема это
  /// позволяет, но продукт — нет (Bible § 7.3), и рекурсия здесь только
  /// добавила бы способов запутать пользователя.
  List<Widget> _buildTree(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
    List<Category> all,
  ) {
    final byParent = <String, List<Category>>{};
    final roots = <Category>[];
    for (final c in categories) {
      final parent = c.parentCategoryId;
      if (parent == null) {
        roots.add(c);
      } else {
        byParent.putIfAbsent(parent, () => []).add(c);
      }
    }

    // Родитель мог быть удалён или заархивирован — иначе его дети пропали бы
    // из списка совсем и отредактировать их стало бы нечем.
    final rootIds = roots.map((c) => c.id).toSet();
    for (final entry in byParent.entries.toList()) {
      if (!rootIds.contains(entry.key)) {
        roots.addAll(entry.value);
        byParent.remove(entry.key);
      }
    }

    final widgets = <Widget>[];
    for (final root in roots) {
      final children = byParent[root.id] ?? const <Category>[];
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: MmCard(
            radius: 24,
            shadows: MmShadows.tile,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              children: [
                _CategoryRow(
                  category: root,
                  childCount: children.length,
                  showDivider: children.isNotEmpty,
                  onTap: () => _openSheet(
                    context,
                    type: root.type,
                    all: all,
                    existing: root,
                  ),
                  onLongPress: () => _confirmDelete(context, ref, root, children),
                ),
                for (var i = 0; i < children.length; i++)
                  _CategoryRow(
                    category: children[i],
                    childCount: 0,
                    indented: true,
                    showDivider: i != children.length - 1,
                    onTap: () => _openSheet(
                      context,
                      type: children[i].type,
                      all: all,
                      existing: children[i],
                    ),
                    onLongPress: () =>
                        _confirmDelete(context, ref, children[i], const []),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  static Future<void> _openSheet(
    BuildContext context, {
    required CategoryType type,
    required List<Category> all,
    Category? existing,
  }) {
    return mmShowSheet<void>(
      context,
      child: _CategorySheet(type: type, allCategories: all, existing: existing),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
    List<Category> children,
  ) async {
    if (category.isSystem) {
      mmSnack(context, 'Системные категории удалить нельзя');
      return;
    }

    // Удаление родителя оставило бы подкатегории висеть на несуществующем
    // parentCategoryId. Поднимаем их на верхний уровень — данные целы,
    // и пользователь предупреждён заранее.
    final childNote = children.isEmpty
        ? ''
        : ' Подкатегорий: ${children.length}. Они станут самостоятельными, '
            'а не удалятся вместе с родителем.';

    final ok = await mmConfirm(
      context,
      title: 'Удалить «${category.name}»?',
      message: 'Категория будет скрыта. Операции по ней сохранятся.$childNote',
    );
    if (!ok) return;

    final repo = await ref.read(categoryRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    for (final child in children) {
      await repo.update(child.copyWith(clearParent: true, updatedAt: now));
    }
    await repo.softDelete(category.id);
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.childCount,
    required this.onTap,
    required this.onLongPress,
    required this.showDivider,
    this.indented = false,
  });

  final Category category;
  final int childCount;
  final bool indented;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(category.color) ??
        (category.type == CategoryType.income
            ? MmColors.green
            : MmColors.orange);

    final notes = <String>[
      if (category.isSystem) 'Системная',
      if (childCount > 0) 'Подкатегорий: $childCount',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.fromLTRB(indented ? 24 : 0, 10, 0, 10),
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: MmColors.divider, width: 1),
                  ),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconForName(category.icon), color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MmType.body,
                          ),
                        ),
                        if (category.isMandatory) ...[
                          const SizedBox(width: 6),
                          const _MandatoryBadge(),
                        ],
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(notes.join(' • '), style: MmType.caption),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: MmColors.grey),
            ],
          ),
        ),
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

/// Метка обязательной категории (Bible § 7.3): траты, которые нельзя
/// урезать при планировании — аренда, коммуналка, кредит.
class _MandatoryBadge extends StatelessWidget {
  const _MandatoryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MmColors.tintIndigo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'обязательная',
        style: MmType.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: MmColors.indigo,
        ),
      ),
    );
  }
}

// ─── Форма создания / редактирования ─────────────────────────────────────────

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({
    required this.type,
    required this.allCategories,
    this.existing,
  });

  final CategoryType type;
  final Category? existing;
  final List<Category> allCategories;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final TextEditingController _nameCtrl;
  late String _selectedIcon;
  late String? _parentId;
  late bool _isMandatory;
  late bool _archived;

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

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _selectedIcon = existing?.icon ?? 'category';
    _parentId = existing?.parentCategoryId;
    _isMandatory = existing?.isMandatory ?? false;
    _archived = existing?.isArchived ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Кандидаты в родители: того же типа, корневые, и не сама категория.
  /// Категория с детьми в родители не годится — это дало бы третий уровень.
  List<Category> get _parentCandidates {
    final existing = widget.existing;
    final hasChildren = existing != null &&
        widget.allCategories.any((c) => c.parentCategoryId == existing.id);
    if (hasChildren) return const [];

    return widget.allCategories
        .where((c) =>
            c.type == widget.type &&
            c.parentCategoryId == null &&
            !c.isArchived &&
            c.id != existing?.id,)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final typeLabel = widget.type == CategoryType.income ? 'доход' : 'расход';
    final candidates = _parentCandidates;

    // Родитель мог исчезнуть из кандидатов (например, у него появились дети) —
    // тогда подсвечивать нечего, и выбор просто показывается пустым.
    final parentValue =
        candidates.any((c) => c.id == _parentId) ? _parentId : null;

    return MmSheet(
      title: isEdit ? 'Изменить категорию' : 'Новая категория ($typeLabel)',
      primaryLabel: isEdit ? 'Сохранить' : 'Создать',
      onPrimary: _save,
      children: [
        MmField(
          label: 'Название',
          controller: _nameCtrl,
          autofocus: !isEdit,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (candidates.isNotEmpty)
          MmChipsField<String?>(
            label: 'Родительская категория',
            items: [
              (null, 'Без родителя'),
              for (final c in candidates) (c.id, c.name),
            ],
            selected: parentValue,
            onSelected: (v) => setState(() => _parentId = v),
          ),
        if (widget.type == CategoryType.expense)
          MmSwitchRow(
            title: 'Обязательная',
            subtitle: 'Траты, которые нельзя урезать: аренда, коммуналка, кредит',
            value: _isMandatory,
            onChanged: (v) => setState(() => _isMandatory = v),
          ),
        if (isEdit)
          MmSwitchRow(
            title: 'В архиве',
            subtitle: 'Не предлагается при вводе операции, история сохраняется',
            value: _archived,
            onChanged: (v) => setState(() => _archived = v),
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Иконка', style: MmType.caption),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in _icons)
              GestureDetector(
                onTap: () => setState(() => _selectedIcon = key),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: key == _selectedIcon
                        ? MmColors.blue
                        : MmColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: key == _selectedIcon
                          ? MmColors.blue
                          : MmColors.divider,
                    ),
                  ),
                  child: Icon(
                    iconForName(key),
                    color:
                        key == _selectedIcon ? Colors.white : MmColors.label,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      mmSnack(context, 'Введите название категории');
      return;
    }

    final repo = await ref.read(categoryRepositoryProvider.future);
    final now = DateTime.now().toUtc();
    final existing = widget.existing;

    if (existing != null) {
      await repo.update(
        existing.copyWith(
          name: name,
          icon: _selectedIcon,
          parentCategoryId: _parentId,
          clearParent: _parentId == null,
          isMandatory: _isMandatory,
          isArchived: _archived,
          updatedAt: now,
        ),
      );
    } else {
      final session = await ref.read(bootstrapProvider.future);
      await repo.create(
        Category(
          id: const Uuid().v4(),
          familyId: session.familyId,
          parentCategoryId: _parentId,
          name: name,
          type: widget.type,
          isMandatory: _isMandatory,
          icon: _selectedIcon,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }
}
