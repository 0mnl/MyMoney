import 'package:flutter/material.dart';

/// Набор токенов и виджетов дизайна главного экрана.
///
/// До этого файла стиль макета жил константами внутри `home_tab.dart`,
/// `settings_screen.dart` и `profile_screen.dart`, а остальные экраны рисовались
/// дефолтным Material — с `AppBar`, `Card` и `FloatingActionButton`. Здесь
/// собраны те же самые значения (цвета, радиусы, тени, типографика), чтобы
/// любой экран собирался из готовых блоков и выглядел продолжением «Главной»,
/// а не отдельным приложением.
///
/// Правило простое: новый экран не объявляет своих цветов и `TextStyle`,
/// а берёт [MmColors] / [MmType] и складывается из [MmScreen], [MmCard],
/// [MmGroupCard], [MmListRow] и форм в [MmSheet].
abstract final class MmColors {
  static const bg = Color(0xFFF4EDE3);
  static const surface = Colors.white;

  static const label = Colors.black;

  /// Полупрозрачный вторичный ярлык из макета («Всего на счетах»).
  static const labelSecondary = Color(0x993C3C43);
  static const labelTertiary = Color(0xFF8E8E93);
  static const labelSubtle = Color(0x7F6B6B6B);
  static const grey = Color(0xFF9E9E9E);

  static const divider = Color(0x1F000000);

  /// Заливка круглой иконки в строке списка и служебных подложек.
  static const fill = Color(0x14000000);
  static const segmentTrack = Color(0x1E767680);

  /// Цвет ссылок «Все» в заголовках секций.
  static const link = Color(0xFF892029);

  static const red = Color(0xFFFF383C);
  static const green = Color(0xFF34C759);
  static const blue = Color(0xFF0088FF);
  static const indigo = Color(0xFF6155F5);
  static const brown = Color(0xFFAC7F5E);
  static const yellow = Color(0xFFFFCC00);
  static const cyan = Color(0xFF00C0E8);
  static const pink = Color(0xFFFF2D55);
  static const orange = Color(0xFFFF9500);
  static const purple = Color(0xFF9C27B0);

  /// Палитра диаграмм и любых «по категориям» раскрасок. Один порядок на всё
  /// приложение: цвет категории на «Главной» и в «Статистике» должен совпадать.
  static const chart = <Color>[indigo, brown, yellow, cyan, pink, blue];

  /// Мягкие подложки под иконки в строках меню.
  static const tintBlue = Color(0xFFE8F0FF);
  static const tintOrange = Color(0xFFFFF3E0);
  static const tintGreen = Color(0xFFE7F8EE);
  static const tintRed = Color(0xFFFDECEC);
  static const tintPurple = Color(0xFFF3E5F5);
  static const tintIndigo = Color(0xFFEFEFFB);
  static const tintGrey = Color(0xFFEEEEEE);
  static const tintYellow = Color(0xFFFFF8E1);
  static const tintCyan = Color(0xFFE3F7FB);
}

/// Типографика макета. Значения (размер, вес, `height`, `letterSpacing`)
/// перенесены из «Главной» один в один.
abstract final class MmType {
  static const _family = 'SF Pro';

  static const largeTitle = TextStyle(
    color: MmColors.label,
    fontSize: 34,
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    height: 1.21,
    letterSpacing: 0.40,
  );

  static const title = TextStyle(
    color: MmColors.label,
    fontSize: 28,
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    height: 1.21,
    letterSpacing: 0.38,
  );

  static const section = TextStyle(
    color: MmColors.label,
    fontSize: 22,
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    height: 1.27,
    letterSpacing: -0.26,
  );

  static const headline = TextStyle(
    color: MmColors.label,
    fontSize: 20,
    fontFamily: _family,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.45,
  );

  static const body = TextStyle(
    color: MmColors.label,
    fontSize: 17,
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    height: 1.29,
    letterSpacing: -0.43,
  );

  static const bodyStrong = TextStyle(
    color: MmColors.label,
    fontSize: 17,
    fontFamily: _family,
    fontWeight: FontWeight.w600,
    height: 1.29,
    letterSpacing: -0.43,
  );

  static const subhead = TextStyle(
    color: MmColors.labelTertiary,
    fontSize: 15,
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: -0.23,
  );

  static const caption = TextStyle(
    color: MmColors.labelTertiary,
    fontSize: 13,
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    height: 1.38,
    letterSpacing: -0.08,
  );

  static const footnote = TextStyle(
    color: MmColors.label,
    fontSize: 13.33,
    fontFamily: _family,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: -0.08,
  );

  /// Сумма в строке операции.
  static const amount = TextStyle(
    fontSize: 20,
    fontFamily: _family,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.45,
  );
}

/// Тени макета: большая карточка (баланс, профиль) и малая (счёт, кнопка).
abstract final class MmShadows {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x3F000000), blurRadius: 48, offset: Offset(0, 8)),
  ];

  static const tile = <BoxShadow>[
    BoxShadow(color: Color(0x3F000000), blurRadius: 25, offset: Offset(0, 3)),
  ];

  /// Тень «таблетки» нижней навигации: чуть заметное свечение + контур.
  static const pill = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 8)),
    BoxShadow(color: Color(0xFFE8E8E8), blurRadius: 0, spreadRadius: 0.5),
  ];
}

/// Отступ снизу под плавающей нижней навигацией.
///
/// Панель не занимает места в лейауте (`Scaffold.bottomNavigationBar` рисуется
/// поверх бежевого фона), поэтому каждый скроллящийся таб обязан сам оставить
/// под неё место — иначе последняя строка списка уезжает под «таблетку».
const double kMmTabBottomInset = 130;

/// Каркас экрана: бежевый фон, безопасная зона, крупный заголовок.
///
/// [embedded] — экран внутри `HomeShell` (таб). Тогда это не `Scaffold`:
/// свой `Scaffold` в `IndexedStack` перекрыл бы нижнюю навигацию оболочки.
/// Пушнутые экраны, наоборот, поднимают собственный `Scaffold` — им нужны
/// снекбары и модальные листы.
class MmScreen extends StatelessWidget {
  const MmScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.embedded = false,
    this.trailing,
    this.headerBottom,
  });

  final String title;

  /// Скроллящееся содержимое. Раскрывается на всю высоту под заголовком,
  /// поэтому внутри ожидается `ListView` / `SingleChildScrollView`.
  final Widget child;

  final String? subtitle;
  final bool embedded;

  /// Кнопка действия справа от заголовка (обычно [MmCircleButton] с «+»).
  final Widget? trailing;

  /// Постоянная часть под заголовком: фильтры, сегмент-контрол, поиск.
  final Widget? headerBottom;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(embedded ? 20 : 16, 12, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!embedded) ...[
                  MmCircleButton(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: embedded ? MmType.largeTitle : MmType.title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.subhead,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
          if (headerBottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: headerBottom!,
            ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );

    if (embedded) {
      return ColoredBox(color: MmColors.bg, child: content);
    }
    return Scaffold(backgroundColor: MmColors.bg, body: content);
  }
}

/// Круглая кнопка 44×44 — «назад» в шапке и добавление на экранах-списках.
class MmCircleButton extends StatelessWidget {
  const MmCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = MmColors.surface,
    this.iconColor = const Color(0xFF1A1A1A),
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: MmShadows.pill,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Крупная белая карточка со скруглением 34 и мягкой тенью.
class MmCard extends StatelessWidget {
  const MmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(19, 17, 19, 17),
    this.onTap,
    this.onLongPress,
    this.radius = 34,
    this.shadows = MmShadows.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final decorated = Ink(
      decoration: BoxDecoration(
        color: MmColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null && onLongPress == null) {
      return Container(
        decoration: BoxDecoration(
          color: MmColors.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadows,
        ),
        padding: padding,
        child: child,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radius),
        child: decorated,
      ),
    );
  }
}

/// Группа строк одним белым блоком со скруглением 14 — как в «Настройках».
class MmGroupCard extends StatelessWidget {
  const MmGroupCard({
    super.key,
    required this.children,
    this.title,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 16),
  });

  final List<Widget> children;

  /// Необязательный заголовок группы над карточкой.
  final String? title;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title!.toUpperCase(), style: MmType.caption),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: MmColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка меню внутри [MmGroupCard]: иконка на подложке, заголовок,
/// необязательное значение справа и шеврон.
class MmMenuRow extends StatelessWidget {
  const MmMenuRow({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.isLast = false,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: MmColors.divider, width: 1),
                  ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.body,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.caption,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  textAlign: TextAlign.right,
                  style: MmType.subhead.copyWith(color: MmColors.grey),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: MmColors.grey, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Заголовок секции с необязательной ссылкой-действием справа («Все»).
class MmSectionHeader extends StatelessWidget {
  const MmSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: MmType.section)),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  actionLabel!,
                  style: MmType.body.copyWith(color: MmColors.link),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Сегмент-контрол «таблеткой» — тот же, что переключает период на «Главной».
class MmSegmented<T> extends StatelessWidget {
  const MmSegmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  /// Пары «значение — подпись» в порядке отображения.
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MmColors.segmentTrack,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(item.$1),
                child: Container(
                  height: 28,
                  alignment: Alignment.center,
                  decoration: item.$1 == selected
                      ? BoxDecoration(
                          color: MmColors.surface,
                          borderRadius: BorderRadius.circular(1000),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 20,
                              offset: Offset(0, 2),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.footnote.copyWith(
                      fontWeight: item.$1 == selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Строка списка в стиле «Последних операций»: круглая иконка, заголовок с
/// подписью и сумма справа.
class MmListRow extends StatelessWidget {
  const MmListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingColor = MmColors.label,
    this.trailingStyle,
    this.trailingBelow,
    this.onTap,
    this.onLongPress,
    this.iconColor = MmColors.label,
    this.iconBackground = MmColors.fill,
    this.showDivider = true,
    this.strikeThrough = false,
    this.leading,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color trailingColor;

  /// По умолчанию справа стоит сумма. Когда там не деньги (номер платежа,
  /// счётчик), крупный «денежный» стиль перетягивает внимание — этот параметр
  /// позволяет его понизить.
  final TextStyle? trailingStyle;

  /// Мелкая подпись под суммой (статус, процент, дата).
  final String? trailingBelow;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color iconColor;
  final Color iconBackground;
  final bool showDivider;
  final bool strikeThrough;

  /// Замена круглой иконке — например, чекбокс в графике платежей.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: MmColors.divider, width: 1),
                  ),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading ??
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.body.copyWith(
                        decoration:
                            strikeThrough ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.subhead.copyWith(
                          color: MmColors.labelSubtle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trailingText!,
                      textAlign: TextAlign.right,
                      style: (trailingStyle ?? MmType.amount)
                          .copyWith(color: trailingColor),
                    ),
                    if (trailingBelow != null)
                      Text(
                        trailingBelow!,
                        textAlign: TextAlign.right,
                        style: MmType.caption,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Полоса прогресса со скруглением — бюджеты, цели, график платежей.
class MmProgressBar extends StatelessWidget {
  const MmProgressBar({
    super.key,
    required this.value,
    this.color = MmColors.blue,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: MmColors.fill,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Пустое состояние: иконка, объяснение и кнопка первого шага.
class MmEmptyState extends StatelessWidget {
  const MmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: MmColors.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: MmColors.labelTertiary),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: MmType.headline),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: MmType.subhead),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              MmPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Основная кнопка-«таблетка» на всю ширину.
class MmPrimaryButton extends StatelessWidget {
  const MmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = MmColors.blue,
    this.textColor = Colors.white,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: enabled ? color : color.withValues(alpha: 0.4),
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(1000),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: textColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: MmType.bodyStrong.copyWith(color: textColor),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Второстепенная кнопка: белая «таблетка» с тенью.
class MmSecondaryButton extends StatelessWidget {
  const MmSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.textColor = MmColors.label,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: MmColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(1000),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(label, style: MmType.bodyStrong.copyWith(color: textColor)),
          ],
        ),
      ),
    );
  }
}

/// Небольшая «таблетка»-фильтр (тип операции, направление долга).
class MmChip extends StatelessWidget {
  const MmChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.selectedColor = MmColors.blue,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? selectedColor : MmColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? selectedColor : MmColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : MmColors.label,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: MmType.footnote.copyWith(
                color: selected ? Colors.white : MmColors.label,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Формы и модальные окна ──────────────────────────────────────────────────

/// Открывает модальный лист в оформлении макета.
///
/// Отступ под клавиатуру ставится здесь, а не в каждой форме: без него поле
/// ввода уезжает под клавиатуру, и это ровно та ошибка, которую забывают
/// повторить в новом экране.
Future<T?> mmShowSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MmColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: child,
    ),
  );
}

/// Содержимое модального листа: полоска-ручка, заголовок, поля и кнопка.
class MmSheet extends StatelessWidget {
  const MmSheet({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.primaryColor = MmColors.blue,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MmColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: MmType.section),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: MmType.subhead),
            ],
            const SizedBox(height: 16),
            ...children,
            if (primaryLabel != null) ...[
              const SizedBox(height: 20),
              MmPrimaryButton(
                label: primaryLabel!,
                onPressed: onPrimary,
                color: primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Поле ввода: подпись сверху, белая «карточка» с текстом внутри.
class MmField extends StatelessWidget {
  const MmField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.keyboardType,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.onChanged,
    this.maxLines = 1,
    this.textStyle,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MmType.caption),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: MmColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    keyboardType: keyboardType,
                    textCapitalization: textCapitalization,
                    onChanged: onChanged,
                    maxLines: maxLines,
                    style: textStyle ?? MmType.body,
                    decoration: InputDecoration.collapsed(
                      hintText: hint,
                      hintStyle: MmType.body.copyWith(color: MmColors.grey),
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    suffix!,
                    style: MmType.body.copyWith(color: MmColors.grey),
                  ),
                ],
              ],
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(helper!, style: MmType.caption),
            ),
          ],
        ],
      ),
    );
  }
}

/// Строка-выбор внутри формы: подпись, текущее значение, шеврон.
class MmPickerRow extends StatelessWidget {
  const MmPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.icon,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// Крестик справа — когда значение можно не задавать (срок, дата цели).
  final VoidCallback? onClear;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MmType.caption),
          const SizedBox(height: 6),
          Material(
            color: MmColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: MmColors.grey),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: Text(value, style: MmType.body)),
                    if (onClear != null)
                      GestureDetector(
                        onTap: onClear,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8, right: 4),
                          child: Icon(Icons.close,
                              size: 18, color: MmColors.grey,),
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right,
                          size: 20, color: MmColors.grey,),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Переключатель в форме: заголовок, пояснение, `Switch`.
class MmSwitchRow extends StatelessWidget {
  const MmSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: MmColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: MmType.body),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: MmType.caption),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: MmColors.green,
              activeTrackColor: MmColors.green.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ряд «таблеток» выбора одного значения из списка.
class MmChipsField<T> extends StatelessWidget {
  const MmChipsField({
    super.key,
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.emptyHint,
  });

  final String label;
  final List<(T, String)> items;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MmType.caption),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              emptyHint ?? 'Нет вариантов',
              style: MmType.subhead.copyWith(color: MmColors.red),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  MmChip(
                    label: item.$2,
                    selected: item.$1 == selected,
                    onTap: () => onSelected(item.$1),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Диалог подтверждения в оформлении макета.
///
/// Возвращает `true` только при явном подтверждении: закрытие тапом мимо
/// трактуется как отказ, поэтому удаление никогда не срабатывает случайно.
Future<bool> mmConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Удалить',
  String cancelLabel = 'Отмена',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: MmColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: MmType.headline),
      content: message == null
          ? null
          : Text(message, style: MmType.subhead.copyWith(color: MmColors.label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelLabel,
            style: MmType.body.copyWith(color: MmColors.labelTertiary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: MmType.bodyStrong.copyWith(
              color: destructive ? MmColors.red : MmColors.blue,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Короткое сообщение в едином оформлении (как `showUnderDevelopment`).
void mmSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
}

/// Единый способ открыть экран поверх текущего.
Future<T?> mmPush<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => screen),
  );
}

/// Загрузка/ошибка в оформлении экрана — чтобы `when(...)` не расползался
/// по экранам тремя разными видами.
class MmLoading extends StatelessWidget {
  const MmLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: MmColors.link),
        ),
      );
}

class MmError extends StatelessWidget {
  const MmError(this.error, {super.key});
  final Object error;

  @override
  Widget build(BuildContext context) => MmEmptyState(
        icon: Icons.error_outline,
        title: 'Что-то пошло не так',
        message: '$error',
      );
}
