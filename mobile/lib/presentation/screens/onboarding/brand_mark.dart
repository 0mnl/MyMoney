import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The black MyMoney pill from the Splash and Welcome designs.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 125,
      height: 37,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18.5),
      ),
      alignment: Alignment.center,
      child: const Text(
        'MyMoney',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
