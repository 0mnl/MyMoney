import 'package:flutter/material.dart';

/// Maps the icon-name strings we store in Category.icon (mirroring the
/// backend's SystemCategoriesCatalog) to concrete Material IconData.
/// Unknown names fall back to a generic bookmark.
IconData iconForName(String? name) {
  switch (name) {
    case 'work':
      return Icons.work_outline;
    case 'attach_money':
      return Icons.attach_money;
    case 'redeem':
      return Icons.redeem;
    case 'trending_up':
      return Icons.trending_up;
    case 'shopping_cart':
      return Icons.shopping_cart_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'bolt':
      return Icons.bolt;
    case 'wifi':
      return Icons.wifi;
    case 'directions_bus':
      return Icons.directions_bus_outlined;
    case 'restaurant':
      return Icons.restaurant_outlined;
    case 'healing':
      return Icons.healing_outlined;
    case 'checkroom':
      return Icons.checkroom_outlined;
    case 'sports_esports':
      return Icons.sports_esports_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'more_horiz':
      return Icons.more_horiz;
    default:
      return Icons.bookmark_outline;
  }
}
