import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../theme/app_theme.dart';

/// The application's official logo, with a graceful fallback (a navy
/// crest placeholder with an apartment glyph) if the asset can't be
/// loaded. Shared so the login and home screens render identical marks.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.textPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.apartment_rounded,
            color: AppColors.surface,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// Official masthead lock-up — logo, application name, tagline and a
/// short brass rule. Used by the login and home screens so both carry
/// exactly the same branding, typography and spacing.
class AppBrandHeader extends StatelessWidget {
  final double logoSize;
  final EdgeInsetsGeometry padding;

  const AppBrandHeader({
    super.key,
    this.logoSize = 96,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          AppLogo(size: logoSize),
          const SizedBox(height: 12),
          Text(
            AppInfo.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            AppInfo.tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 56,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
