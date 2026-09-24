import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../utils/responsive.dart';

/// هدر قرمز مشترک همه صفحات با ارتفاع واقعی سیستم.
/// [topPad] باید از MediaQuery گرفته شود تا preferredSize با ارتفاع
/// واقعی status bar/ناچ یکی باشد (وگرنه بدنه زیر هدر می‌رود).
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final double radius;
  final double topPad;

  const GradientAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.bottom,
    this.radius = 24,
    double? topPad,
  }) : topPad = topPad ?? 0;

  /// ساخت راحت با همان context صفحه (پدینگ بالا را خودش می‌خواند).
  factory GradientAppBar.of(
    BuildContext context, {
    required String title,
    Widget? titleWidget,
    bool showBack = true,
    VoidCallback? onBack,
    List<Widget> actions = const [],
    PreferredSizeWidget? bottom,
    double radius = 24,
  }) {
    return GradientAppBar(
      title: title,
      titleWidget: titleWidget,
      showBack: showBack,
      onBack: onBack,
      actions: actions,
      bottom: bottom,
      radius: radius,
      topPad: MediaQuery.paddingOf(context).top,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(topPad +
      kToolbarHeight +
      (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = Responsive.hPad(width, normal: 8, narrow: 4);

    return Container(
      decoration: QandTheme.headerGradient(radius: radius),
      padding: EdgeInsets.only(top: topPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: kToolbarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: onBack ?? () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    const SizedBox(width: 4),
                  Expanded(
                    child: titleWidget ??
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                  ),
                  if (actions.isEmpty)
                    const SizedBox(width: 4)
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: actions),
                ],
              ),
            ),
          ),
          if (bottom != null) bottom!,
        ],
      ),
    );
  }
}
