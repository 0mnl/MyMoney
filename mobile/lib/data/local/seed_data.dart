import 'package:uuid/uuid.dart';

import '../../domain/model/account.dart';
import '../../domain/model/category.dart';
import '../../domain/model/enums.dart';

/// System categories mirror the backend catalog (see backend
/// SystemCategoriesCatalog.kt). Keep the two in sync when adding rows.
class SystemCategoriesCatalog {
  const SystemCategoriesCatalog._();

  static const _uuid = Uuid();

  static const List<_Def> _defs = [
    // Income
    _Def('Зарплата', CategoryType.income, 'work'),
    _Def('Подработка', CategoryType.income, 'attach_money'),
    _Def('Подарки', CategoryType.income, 'redeem'),
    _Def('Прочие поступления', CategoryType.income, 'trending_up'),

    // Expense — mandatory
    _Def('Продукты', CategoryType.expense, 'shopping_cart', mandatory: true),
    _Def('Жильё', CategoryType.expense, 'home', mandatory: true),
    _Def('Коммунальные услуги', CategoryType.expense, 'bolt', mandatory: true),
    _Def('Связь и интернет', CategoryType.expense, 'wifi', mandatory: true),
    _Def('Транспорт', CategoryType.expense, 'directions_bus', mandatory: true),

    // Expense — regular
    _Def('Кафе и рестораны', CategoryType.expense, 'restaurant'),
    _Def('Здоровье', CategoryType.expense, 'healing'),
    _Def('Одежда', CategoryType.expense, 'checkroom'),
    _Def('Развлечения', CategoryType.expense, 'sports_esports'),
    _Def('Образование', CategoryType.expense, 'school'),
    _Def('Прочие расходы', CategoryType.expense, 'more_horiz'),
  ];

  static List<Category> buildFor(String familyId, DateTime now) => _defs
      .map((d) => Category(
            id: _uuid.v4(),
            familyId: familyId,
            name: d.name,
            type: d.type,
            isMandatory: d.mandatory,
            isSystem: true,
            icon: d.icon,
            createdAt: now,
            updatedAt: now,
          ))
      .toList();

  /// A default "Наличные" account created together with the seed so the
  /// user can add a transaction on first launch without extra setup.
  static Account defaultAccount(String familyId, DateTime now) => Account(
        id: _uuid.v4(),
        familyId: familyId,
        name: 'Наличные',
        type: 'cash',
        createdAt: now,
        updatedAt: now,
      );
}

class _Def {
  const _Def(this.name, this.type, this.icon, {this.mandatory = false});
  final String name;
  final CategoryType type;
  final String icon;
  final bool mandatory;
}
