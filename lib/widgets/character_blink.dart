import 'dart:math' as math;
import 'package:flutter/material.dart';

/// کاراکتر چشمک‌زن قند (تابلوی دایره‌ای با نوشته قند).
///
/// - ورود (یک‌بار در هر اجرا): کاراکتر کوچک و پایینِ دایره شروع می‌کند و با
///   فنر می‌پرد بالا توی دایره؛ قاب دایره ثابت می‌ماند.
/// - بعد از ورود: اگر فایل متحرک `assets/images/chef_wink.webp` در باندل
///   باشد، لوپ چشمک پخش می‌شود؛ وگرنه همان `assets/images/chef.png` ثابت.
///
/// هیچ تغییری در خودِ آرت‌ورک داده نمی‌شود؛ فقط لایه نمایش است.
class BlinkingCharacter extends StatefulWidget {
  final double size;
  const BlinkingCharacter({super.key, required this.size});

  @override
  State<BlinkingCharacter> createState() => _BlinkingCharacterState();
}

class _BlinkingCharacterState extends State<BlinkingCharacter>
    with TickerProviderStateMixin {
  /// ورود فقط یک‌بار در هر اجرای اپ پخش می‌شود (دفعه‌های بعد مستقیم لوپ چشمک).
  static bool _entrancePlayed = false;

  /// ثابت‌های ورود.
  static const double enterFromScale = 0.55;
  static const double enterFromSlide = 0.5; // کسری از اندازه (از پایین دایره)

  late final AnimationController _float;
  late final AnimationController _enter;
  bool _showWink = false;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    if (_entrancePlayed) {
      _enter.value = 1;
      _showWink = true;
    } else {
      _enter.forward().then((_) {
        if (!mounted) return;
        setState(() => _showWink = true);
        _entrancePlayed = true;
      });
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, child) {
        final dy = math.sin(_float.value * 2 * math.pi) * 3.5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: AnimatedBuilder(
        animation: _enter,
        builder: (_, child) {
          final t = _enter.value;
          final scale = enterFromScale +
              (1 - enterFromScale) * Curves.elasticOut.transform(t);
          final slide = (1 - Curves.easeOutCubic.transform(t)) *
              enterFromSlide *
              widget.size;
          final opacity = (t / 0.35).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, slide),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        // قاب دایره ثابت می‌ماند؛ کاراکتر از قایم‌شده می‌پرد بالا توش.
        child: ClipOval(child: _artwork()),
      ),
    );
  }

  Widget _artwork() {
    // حین ورود ثابت، بعدش لوپ چشمک (تازه از اول شروع می‌شود).
    if (!_showWink) return _staticArt();
    return Image.asset(
      'assets/images/chef_wink.webp',
      height: widget.size,
      width: widget.size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // اگر فایل متحرک نباشد → همان تصویر ثابت.
      errorBuilder: (_, __, ___) => _staticArt(),
    );
  }

  Widget _staticArt() {
    return Image.asset(
      'assets/images/chef.png',
      height: widget.size,
      width: widget.size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        height: widget.size,
        width: widget.size,
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Center(
          child: Text('👩‍🍳', style: TextStyle(fontSize: widget.size * 0.45)),
        ),
      ),
    );
  }
}
