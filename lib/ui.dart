import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

// ───────────────────────── تم‌ها ─────────────────────────
class ThemeDef {
  const ThemeDef(this.name, this.dark, this.accent, this.accent2);
  final String name;
  final bool dark;
  final Color accent;
  final Color accent2;
}

const themeDefs = [
  ThemeDef('آبی', false, Color(0xFF2F7BFF), Color(0xFF6EA8FF)),
  ThemeDef('سبز', false, Color(0xFF1FA97A), Color(0xFF5FD3A8)),
  ThemeDef('بنفش', false, Color(0xFF7C4DDB), Color(0xFFA98BEA)),
  ThemeDef('سرمه‌ای', false, Color(0xFF2B4A9B), Color(0xFF4F73C9)),
  ThemeDef('مشکی', false, Color(0xFF1C1C1E), Color(0xFF5B5C63)),
  ThemeDef('نارنجی', false, Color(0xFFFF7A1A), Color(0xFFFFA866)),
  ThemeDef('صورتی', false, Color(0xFFE0457B), Color(0xFFF08CAE)),
];

final ValueNotifier<int> accentIdx = ValueNotifier<int>(3);
final ValueNotifier<bool> manualDark = ValueNotifier<bool>(false);
final ValueNotifier<bool> sysTheme = ValueNotifier<bool>(false);
final ValueNotifier<bool> liquidGlass = ValueNotifier<bool>(true);
final ValueNotifier<bool> smartSearch = ValueNotifier<bool>(true);
final ValueNotifier<double> glassLevel = ValueNotifier<double>(0.3);
final ValueNotifier<bool> animBg = ValueNotifier<bool>(true);
final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

bool get isDark => sysTheme.value
    ? PlatformDispatcher.instance.platformBrightness == Brightness.dark
    : manualDark.value;

ThemeDef get tdef {
  final b = themeDefs[min(max(accentIdx.value, 0), themeDefs.length - 1)];
  if (!isDark) return b;
  final a = accentIdx.value == 4
      ? const Color(0xFFD9DBE1)
      : Color.lerp(b.accent2, Colors.white, .2)!;
  return ThemeDef(b.name, true, a, Color.lerp(a, Colors.white, .25)!);
}

Color get kAccent => tdef.accent;
Color get kAccentLight => tdef.accent2;
Color get kInk => isDark ? const Color(0xFFEDEFF5) : const Color(0xFF14161C);
Color get kSub => isDark ? const Color(0xFF9AA1B2) : const Color(0xFF666D7C);
Color get kSurface => isDark ? const Color(0xFF1B1E28) : const Color(0xFFF8F9FD);
Color get kBg => isDark
    ? const Color(0xFF0B0D12)
    : Color.lerp(Colors.white, tdef.accent, .05)!;
Color get kDanger => const Color(0xFFE5484D);

// سفید نیمه‌شفاف؛ در تم تیره کم‌رنگ‌تره
Color wh(double o) => isDark
    ? Color.fromRGBO(255, 255, 255, o * .16)
    : Color.fromRGBO(255, 255, 255, o);

// ───────────────────────── شیشه مایع واقعی ─────────────────────────
class FlatGlass extends InheritedWidget {
  const FlatGlass({super.key, required super.child});
  @override
  bool updateShouldNotify(FlatGlass old) => false;
}

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 26,
    this.onTap,
    this.onLongPress,
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    if (!liquidGlass.value ||
        context.dependOnInheritedWidgetOfExactType<FlatGlass>() != null) {
      final flat = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: kSurface.withAlpha(isDark ? 238 : 245),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: kSub.withAlpha(45), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(isDark ? 60 : 18),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: child,
      );
      if (onTap == null && onLongPress == null) return flat;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: flat,
      );
    }
    final lv = glassLevel.value;
    final dark = isDark;
    final a1 = (dark ? 36 + 70 * lv : 40 + 130 * lv).round().toInt();
    final a2 = (dark ? 12 + 30 * lv : 14 + 76 * lv).round().toInt();
    final hi = dark ? 120 : 235;
    final t = tint ?? Colors.white;
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: kAccent.withAlpha(dark ? 26 : 20),
              blurRadius: 30,
              offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(1.3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(hi),
                  Colors.white.withAlpha(20),
                  Colors.white.withAlpha(10),
                  Colors.white.withAlpha((hi * .7).round()),
                ],
                stops: const [0, .35, .7, 1],
              ),
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(max(0.0, radius - 1.3)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.withAlpha(a1), t.withAlpha(a2)],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
    if (onTap == null && onLongPress == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: card,
    );
  }
}

class Backdrop extends StatefulWidget {
  const Backdrop({super.key});
  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 36));

  void _sync() {
    if (animBg.value) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    animBg.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    animBg.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  Widget blob(double a, double size, Color col, {bool ring = false}) {
    return Align(
      alignment: Alignment(sin(a) * .9, cos(a * 1.3) * .8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ring ? null : RadialGradient(colors: [col, col.withAlpha(0)]),
          border: ring ? Border.all(color: col, width: 14) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (c, _) {
        final t = _c.value * 2 * pi;
        final ac = kAccent;
        final dark = isDark;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF090B10), Color(0xFF111522), Color(0xFF0B0D12)]
                  : [
                      Color.lerp(Colors.white, ac, .07)!,
                      Color.lerp(Colors.white, ac, .13)!,
                      Color.lerp(Colors.white, ac, .05)!,
                    ],
            ),
          ),
          child: Stack(children: [
            blob(t, 420, ac.withAlpha(dark ? 120 : 95)),
            blob(t + 2.1, 360, kAccentLight.withAlpha(dark ? 100 : 90)),
            blob(t + 4.2, 330, ac.withAlpha(dark ? 80 : 70)),
            blob(t + 1.0, 190, ac.withAlpha(dark ? 70 : 55), ring: true),
            blob(t + 3.5, 130, kAccentLight.withAlpha(dark ? 80 : 70), ring: true),
          ]),
        );
      },
    );
  }
}

// ───────────────────────── آیکون‌های طراحی‌شده ─────────────────────────
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 24, this.color, this.fill});
  final String name;
  final double size;
  final Color? color;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kInk;
    final f = fill ?? (color ?? kAccent).withAlpha(60);
    return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _IconPainter(name, c, f)));
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.n, this.c, this.f);
  final String n;
  final Color c;
  final Color f;

  @override
  void paint(Canvas cv, Size s) {
    cv.scale(s.width / 24, s.height / 24);
    final st = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    final fl = Paint()
      ..style = PaintingStyle.fill
      ..color = f;
    final sol = Paint()
      ..style = PaintingStyle.fill
      ..color = c;
    void fs(Path p) {
      cv.drawPath(p, fl);
      cv.drawPath(p, st);
    }

    void ks(Path p) {
      cv.drawPath(p, Paint()..color = kBg);
      fs(p);
    }

    void ln(double a, double b, double x, double y) =>
        cv.drawLine(Offset(a, b), Offset(x, y), st);
    Path rr(double x, double y, double w, double h, double r) => Path()
      ..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)));
    Path ci(double x, double y, double r) =>
        Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    void dot(double x, double y, double r) =>
        cv.drawCircle(Offset(x, y), r, sol);
    Path cloud(double dy) {
      var p = Path()
        ..addOval(Rect.fromCircle(center: Offset(8, 15 + dy), radius: 3.8));
      final parts = [
        Path()
          ..addOval(Rect.fromCircle(center: Offset(12.8, 12.4 + dy), radius: 5)),
        Path()
          ..addOval(Rect.fromCircle(center: Offset(17, 15.2 + dy), radius: 3.4)),
        Path()..addRect(Rect.fromLTRB(8, 15 + dy, 17, 18.8 + dy)),
      ];
      for (final o in parts) {
        p = Path.combine(PathOperation.union, p, o);
      }
      return p;
    }

    switch (n) {
      case 'today':
        fs(rr(3.5, 5, 17, 15.5, 4));
        ln(3.5, 10, 20.5, 10);
        ln(8, 3, 8, 6.5);
        ln(16, 3, 16, 6.5);
        dot(12, 15, 1.5);
        break;
      case 'tasks':
        fs(rr(5, 4.5, 14, 16.5, 3.5));
        cv.drawPath(rr(9, 3, 6, 3.5, 1.5), st);
        cv.drawPath(
            Path()
              ..moveTo(8.5, 13)
              ..lineTo(11, 15.5)
              ..lineTo(15.5, 10.5),
            st);
        break;
      case 'tools':
        fs(rr(4, 4, 7, 7, 2.2));
        cv.drawPath(rr(13, 4, 7, 7, 2.2), st);
        cv.drawPath(rr(4, 13, 7, 7, 2.2), st);
        fs(rr(13, 13, 7, 7, 2.2));
        break;
      case 'weather':
        fs(cloud(1.5));
        cv.drawCircle(const Offset(8, 7), 2.6, st);
        ln(8, 2.2, 8, 3);
        ln(2.8, 7, 3.6, 7);
        ln(4.3, 3.3, 5, 4);
        ln(11.7, 3.3, 11, 4);
        break;
      case 'settings':
        ln(4, 6, 20, 6);
        ln(4, 12, 20, 12);
        ln(4, 18, 20, 18);
        ks(ci(9, 6, 2.4));
        ks(ci(15, 12, 2.4));
        ks(ci(8, 18, 2.4));
        break;
      case 'plus':
        ln(12, 5, 12, 19);
        ln(5, 12, 19, 12);
        break;
      case 'search':
        fs(ci(10.5, 10.5, 6));
        ln(15, 15, 20, 20);
        break;
      case 'pomodoro':
        fs(ci(12, 13.5, 7.5));
        fs(Path()
          ..moveTo(12, 6.2)
          ..cubicTo(13.5, 3.5, 16, 3.5, 17.5, 4.5)
          ..cubicTo(16.5, 6.7, 14, 7.2, 12, 6.2)
          ..close());
        break;
      case 'timer':
        fs(Path()
          ..moveTo(8, 3.5)
          ..lineTo(16, 3.5)
          ..lineTo(16, 7)
          ..quadraticBezierTo(16, 10.5, 12, 12)
          ..quadraticBezierTo(16, 13.5, 16, 17)
          ..lineTo(16, 20.5)
          ..lineTo(8, 20.5)
          ..lineTo(8, 17)
          ..quadraticBezierTo(8, 13.5, 12, 12)
          ..quadraticBezierTo(8, 10.5, 8, 7)
          ..close());
        ln(6.5, 3.5, 17.5, 3.5);
        ln(6.5, 20.5, 17.5, 20.5);
        break;
      case 'stopwatch':
        fs(ci(12, 13.5, 7.5));
        ln(10, 3, 14, 3);
        ln(12, 3, 12, 6);
        ln(12, 13.5, 14.8, 10.8);
        ln(18, 6.5, 19.5, 8);
        break;
      case 'habit':
        ln(12, 21, 12, 12.5);
        ln(7.5, 21, 16.5, 21);
        fs(Path()
          ..moveTo(12, 14)
          ..cubicTo(8, 14, 5.5, 11.5, 5.5, 8)
          ..cubicTo(9.5, 8, 12, 10, 12, 14)
          ..close());
        fs(Path()
          ..moveTo(12, 11.5)
          ..cubicTo(12, 7.5, 14.5, 4.5, 18.5, 4.5)
          ..cubicTo(18.5, 8.5, 16, 11.5, 12, 11.5)
          ..close());
        break;
      case 'event':
        fs(rr(4, 10, 16, 10.5, 2.5));
        fs(rr(3, 7, 18, 4, 1.5));
        ln(12, 7, 12, 20.5);
        cv.drawPath(
            Path()
              ..moveTo(12, 7)
              ..cubicTo(9, 7, 7.5, 3.8, 10, 3.8)
              ..cubicTo(11.5, 3.8, 12, 5.5, 12, 7)
              ..cubicTo(12, 5.5, 12.5, 3.8, 14, 3.8)
              ..cubicTo(16.5, 3.8, 15, 7, 12, 7),
            st);
        break;
      case 'calendar':
        fs(rr(3.5, 4.5, 17, 16, 4));
        ln(3.5, 9.5, 20.5, 9.5);
        for (final x in [8.0, 12.0, 16.0]) {
          for (final y in [13.0, 17.0]) {
            dot(x, y, 1.1);
          }
        }
        break;
      case 'finance':
        fs(rr(3, 7, 18, 13, 3.5));
        cv.drawPath(
            Path()
              ..moveTo(5.5, 7)
              ..lineTo(15.5, 3.8)
              ..lineTo(16.8, 7),
            st);
        fs(rr(13.5, 11.8, 7.5, 4.6, 2.3));
        dot(16.4, 14.1, 1.1);
        break;
      case 'note':
        fs(rr(5, 3.5, 14, 17, 3));
        ln(8.5, 9, 15.5, 9);
        ln(8.5, 12.5, 15.5, 12.5);
        ln(8.5, 16, 12.5, 16);
        break;
      case 'alarm':
        fs(ci(12, 13, 7));
        ln(12, 9.5, 12, 13);
        ln(12, 13, 14.5, 14.5);
        ln(4, 5.5, 7, 3.3);
        ln(20, 5.5, 17, 3.3);
        break;
      case 'palette':
        fs(ci(12, 12, 8.5));
        dot(8.5, 10.5, 1.2);
        dot(12, 7.8, 1.2);
        dot(15.5, 10.5, 1.2);
        dot(15.5, 15, 1.2);
        break;
      case 'widgets':
        fs(rr(3.5, 3.5, 17, 7, 2.5));
        cv.drawPath(rr(3.5, 13.5, 7.5, 7, 2.5), st);
        fs(rr(13.5, 13.5, 7, 7, 2.5));
        break;
      case 'backup':
        fs(cloud(-2.5));
        ln(12, 20.5, 12, 13);
        ln(9.2, 15.5, 12, 12.7);
        ln(14.8, 15.5, 12, 12.7);
        break;
      case 'restore':
        fs(cloud(-2.5));
        ln(12, 12.5, 12, 20.5);
        ln(9.2, 17.8, 12, 20.6);
        ln(14.8, 17.8, 12, 20.6);
        break;
      case 'trash':
        fs(rr(6, 8, 12, 12.5, 2.5));
        ln(4.5, 6.5, 19.5, 6.5);
        cv.drawPath(
            Path()
              ..moveTo(9.5, 6.5)
              ..lineTo(9.5, 4.5)
              ..lineTo(14.5, 4.5)
              ..lineTo(14.5, 6.5),
            st);
        ln(10, 11.5, 10, 17);
        ln(14, 11.5, 14, 17);
        break;
      case 'shield':
        fs(Path()
          ..moveTo(12, 3)
          ..lineTo(19.5, 6)
          ..lineTo(19.5, 11.5)
          ..cubicTo(19.5, 16, 16.5, 19.5, 12, 21)
          ..cubicTo(7.5, 19.5, 4.5, 16, 4.5, 11.5)
          ..lineTo(4.5, 6)
          ..close());
        cv.drawPath(
            Path()
              ..moveTo(8.8, 12)
              ..lineTo(11.1, 14.3)
              ..lineTo(15.3, 9.7),
            st);
        break;
      case 'info':
        fs(ci(12, 12, 8.5));
        ln(12, 11, 12, 16.5);
        dot(12, 7.9, 1.2);
        break;
      case 'pin':
        fs(Path()
          ..moveTo(12, 21)
          ..cubicTo(6, 14.5, 5, 11.5, 5, 9.5)
          ..cubicTo(5, 5.6, 8, 3, 12, 3)
          ..cubicTo(16, 3, 19, 5.6, 19, 9.5)
          ..cubicTo(19, 11.5, 18, 14.5, 12, 21)
          ..close());
        cv.drawCircle(const Offset(12, 9.5), 2.4, st);
        break;
      case 'bell':
        fs(Path()
          ..moveTo(5, 18.5)
          ..lineTo(6.5, 17)
          ..lineTo(6.5, 11)
          ..cubicTo(6.5, 7.5, 9, 5, 12, 5)
          ..cubicTo(15, 5, 17.5, 7.5, 17.5, 11)
          ..lineTo(17.5, 17)
          ..lineTo(19, 18.5)
          ..close());
        ln(12, 3.2, 12, 5);
        ln(10, 21, 14, 21);
        break;
      case 'drag':
        for (final x in [9.0, 15.0]) {
          for (final y in [6.0, 12.0, 18.0]) {
            dot(x, y, 1.5);
          }
        }
        break;
      case 'resize':
        ln(14, 4, 20, 4);
        ln(20, 4, 20, 10);
        ln(20, 4, 13.5, 10.5);
        ln(10, 20, 4, 20);
        ln(4, 20, 4, 14);
        ln(4, 20, 10.5, 13.5);
        break;
      case 'clip':
        cv.drawPath(
            Path()
              ..moveTo(16.5, 8)
              ..lineTo(9.2, 15.3)
              ..cubicTo(8, 16.5, 8, 18.1, 9.2, 19.1)
              ..cubicTo(10.2, 20.1, 11.9, 20.1, 13, 19)
              ..lineTo(19, 13)
              ..cubicTo(20.8, 11.2, 20.8, 8.6, 19, 6.8)
              ..cubicTo(17.2, 5, 14.6, 5, 12.8, 6.8)
              ..lineTo(6.2, 13.4),
            st);
        break;
      case 'globe':
        fs(ci(12, 12, 8.5));
        cv.drawOval(Rect.fromCenter(center: const Offset(12, 12), width: 8, height: 17), st);
        ln(3.5, 12, 20.5, 12);
        break;
      case 'send':
        fs(Path()
          ..moveTo(20.5, 3.5)
          ..lineTo(3.5, 10.5)
          ..lineTo(10.2, 13.2)
          ..lineTo(13, 20.5)
          ..close());
        ln(10.2, 13.2, 20.5, 3.5);
        break;
      case 'camera':
        fs(rr(3.5, 4.5, 17, 15, 5));
        cv.drawCircle(const Offset(12, 12), 3.8, st);
        dot(16.8, 7.9, 1.1);
        break;
      case 'megaphone':
        fs(Path()
          ..moveTo(4, 10)
          ..lineTo(9.5, 10)
          ..lineTo(18, 5)
          ..lineTo(18, 19)
          ..lineTo(9.5, 14)
          ..lineTo(4, 14)
          ..close());
        ln(7, 14, 8.3, 19.5);
        break;
      case 'minus':
        ln(5, 12, 19, 12);
        break;
      case 'close':
        ln(6, 6, 18, 18);
        ln(18, 6, 6, 18);
        break;
      case 'check':
        cv.drawPath(
            Path()
              ..moveTo(6, 12.5)
              ..lineTo(10.2, 16.7)
              ..lineTo(18, 7.8),
            st);
        break;
      case 'battery':
        fs(rr(3, 8, 16, 9, 2.5));
        ln(21, 11, 21, 14);
        cv.drawPath(
            Path()
              ..moveTo(11.5, 9.8)
              ..lineTo(8.8, 12.8)
              ..lineTo(11.4, 12.8)
              ..lineTo(10.5, 15.3)
              ..lineTo(13.4, 12)
              ..lineTo(10.8, 12)
              ..close(),
            sol);
        break;
      case 'drop':
        fs(Path()
          ..moveTo(12, 3.5)
          ..cubicTo(12, 3.5, 5.5, 10.5, 5.5, 14.5)
          ..cubicTo(5.5, 18.5, 8.3, 20.8, 12, 20.8)
          ..cubicTo(15.7, 20.8, 18.5, 18.5, 18.5, 14.5)
          ..cubicTo(18.5, 10.5, 12, 3.5, 12, 3.5)
          ..close());
        break;
      case 'sparkle':
        fs(Path()
          ..moveTo(12, 3)
          ..cubicTo(12.6, 8, 14, 9.4, 19, 10.2)
          ..cubicTo(14, 11, 12.6, 12.4, 12, 17.5)
          ..cubicTo(11.4, 12.4, 10, 11, 5, 10.2)
          ..cubicTo(10, 9.4, 11.4, 8, 12, 3)
          ..close());
        break;
      case 'moon':
        fs(Path()
          ..moveTo(19.5, 14.5)
          ..cubicTo(14.5, 17, 8, 14, 8, 8.5)
          ..cubicTo(8, 6.5, 8.8, 4.8, 10, 3.8)
          ..cubicTo(5.5, 4.5, 3.5, 9, 5, 13.5)
          ..cubicTo(6.8, 18.5, 12.5, 20.5, 16.5, 18.5)
          ..cubicTo(18, 17.7, 19, 16.3, 19.5, 14.5)
          ..close());
        break;
      case 'play':
        fs(Path()
          ..moveTo(8, 5.5)
          ..lineTo(18.5, 12)
          ..lineTo(8, 18.5)
          ..close());
        break;
      case 'pause':
        fs(rr(6.5, 5, 3.8, 14, 1.4));
        fs(rr(13.7, 5, 3.8, 14, 1.4));
        break;
      case 'reset':
        cv.drawPath(
            Path()
              ..moveTo(5, 12)
              ..cubicTo(5, 8, 8.2, 5, 12, 5)
              ..cubicTo(15.8, 5, 19, 8.2, 19, 12)
              ..cubicTo(19, 15.8, 15.8, 19, 12, 19)
              ..cubicTo(9.6, 19, 7.5, 17.8, 6.3, 16),
            st);
        ln(5, 6.5, 5, 12);
        ln(5, 12, 10.5, 12);
        break;
      case 'skip':
        fs(Path()
          ..moveTo(5, 5.5)
          ..lineTo(14, 12)
          ..lineTo(5, 18.5)
          ..close());
        ln(18, 5.5, 18, 18.5);
        break;
      case 'flag':
        ln(6, 3.5, 6, 21);
        fs(Path()
          ..moveTo(6, 5)
          ..lineTo(18.5, 5)
          ..lineTo(15.5, 9)
          ..lineTo(18.5, 13)
          ..lineTo(6, 13)
          ..close());
        break;
      default:
        fs(ci(12, 12, 8));
    }
  }

  @override
  bool shouldRepaint(_IconPainter o) => o.n != n || o.c != c || o.f != f;
}

// نشان گرد آیکون (برای منوها و تنظیمات)
Widget iconBadge(String icon, Color col, {double size = 46}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [col.withAlpha(52), col.withAlpha(22)],
        ),
        border: Border.all(color: col.withAlpha(60), width: 1),
      ),
      child: Center(
          child: AppIcon(icon, size: size * .54, color: col, fill: col.withAlpha(70))),
    );


// ───────────────────────── شخصیت و لوگوی Clario ─────────────────────────
Path _dropPath(double w, double h) => Path()
  ..moveTo(.5 * w, .05 * h)
  ..cubicTo(.5 * w, .05 * h, .17 * w, .42 * h, .17 * w, .64 * h)
  ..cubicTo(.17 * w, .82 * h, .32 * w, .95 * h, .5 * w, .95 * h)
  ..cubicTo(.68 * w, .95 * h, .83 * w, .82 * h, .83 * w, .64 * h)
  ..cubicTo(.83 * w, .42 * h, .5 * w, .05 * h, .5 * w, .05 * h)
  ..close();

Path _sparkPath(double cx, double cy, double r) => Path()
  ..moveTo(cx, cy - r)
  ..quadraticBezierTo(cx, cy, cx + r, cy)
  ..quadraticBezierTo(cx, cy, cx, cy + r)
  ..quadraticBezierTo(cx, cy, cx - r, cy)
  ..quadraticBezierTo(cx, cy, cx, cy - r)
  ..close();

// شخصیت: mood = happy | sleep | wow
class ClarioMascot extends StatelessWidget {
  const ClarioMascot({super.key, this.size = 120, this.mood = 'happy'});
  final double size;
  final String mood;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MascotPainter(mood, kAccent, kAccentLight)),
      );
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.mood, this.a, this.a2);
  final String mood;
  final Color a;
  final Color a2;

  @override
  void paint(Canvas cv, Size s) {
    final w = s.width, h = s.height;
    final body = _dropPath(w, h);
    // سایه روی زمین
    cv.drawOval(
        Rect.fromCenter(center: Offset(.5 * w, .975 * h), width: .46 * w, height: .05 * h),
        Paint()..color = Colors.black.withAlpha(36));
    // بدنه شیشه‌ای
    cv.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(a2, Colors.white, .35)!, a],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));
    cv.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .02
          ..color = Colors.white.withAlpha(170));
    // درخشش
    cv.save();
    cv.translate(.36 * w, .42 * h);
    cv.rotate(-.5);
    cv.drawOval(Rect.fromCenter(center: Offset.zero, width: .13 * w, height: .27 * h),
        Paint()..color = Colors.white.withAlpha(125));
    cv.restore();
    cv.drawCircle(Offset(.30 * w, .64 * h), .018 * w, Paint()..color = Colors.white.withAlpha(150));
    // چشم‌ها
    final ink = Paint()..color = const Color(0xFF14224A);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * .027
      ..color = const Color(0xFF14224A);
    if (mood == 'sleep') {
      for (final x in [.39, .61]) {
        cv.drawPath(
            Path()
              ..moveTo((x - .055) * w, .60 * h)
              ..quadraticBezierTo(x * w, .645 * h, (x + .055) * w, .60 * h),
            line);
      }
    } else {
      for (final x in [.39, .61]) {
        cv.drawOval(
            Rect.fromCenter(center: Offset(x * w, .61 * h), width: .085 * w, height: .12 * h), ink);
        cv.drawCircle(Offset((x + .012) * w, .575 * h), .017 * w, Paint()..color = Colors.white);
        cv.drawCircle(Offset((x - .01) * w, .64 * h), .008 * w, Paint()..color = Colors.white.withAlpha(190));
      }
    }
    // دهان
    if (mood == 'wow') {
      cv.drawOval(Rect.fromCenter(center: Offset(.5 * w, .75 * h), width: .055 * w, height: .07 * h), ink);
    } else {
      cv.drawPath(
          Path()
            ..moveTo(.43 * w, .715 * h)
            ..quadraticBezierTo(.5 * w, .80 * h, .57 * w, .715 * h),
          line);
    }
    // گونه‌ها
    final cheek = Paint()..color = const Color(0xFFFF7FA8).withAlpha(105);
    cv.drawCircle(Offset(.29 * w, .72 * h), .045 * w, cheek);
    cv.drawCircle(Offset(.71 * w, .72 * h), .045 * w, cheek);
    // ستاره‌های درخشان
    final sp = Paint()..color = Colors.white;
    final spl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .012
      ..color = a2;
    cv.drawPath(_sparkPath(.86 * w, .17 * h, .09 * w), sp);
    cv.drawPath(_sparkPath(.86 * w, .17 * h, .09 * w), spl);
    cv.drawPath(_sparkPath(.13 * w, .30 * h, .055 * w), sp);
    cv.drawPath(_sparkPath(.13 * w, .30 * h, .055 * w), spl);
  }

  @override
  bool shouldRepaint(_MascotPainter o) => o.mood != mood || o.a != a || o.a2 != a2;
}

// لوگو: مربع شیشه‌ای با قطره و حرف C
class ClarioLogo extends StatelessWidget {
  const ClarioLogo({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter(kAccent, kAccentLight)),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.a, this.a2);
  final Color a;
  final Color a2;

  @override
  void paint(Canvas cv, Size s) {
    final w = s.width, h = s.height;
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * .26));
    cv.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(a, Colors.black, .45)!, a2],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));
    cv.save();
    cv.clipRRect(rr);
    cv.drawCircle(Offset(.2 * w, .12 * h), .46 * w, Paint()..color = Colors.white.withAlpha(60));
    cv.drawCircle(Offset(.95 * w, .98 * h), .5 * w, Paint()..color = Colors.white.withAlpha(30));
    cv.restore();
    cv.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .02
          ..color = Colors.white.withAlpha(110));
    // قطره
    cv.save();
    cv.translate(.2 * w, .16 * h);
    cv.scale(.6, .6);
    final d = _dropPath(w, h);
    cv.drawPath(
        d,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white.withAlpha(215)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));
    // حرف C داخل قطره
    final c = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * .075
      ..color = Color.lerp(a, Colors.black, .2)!;
    cv.drawArc(Rect.fromCenter(center: Offset(.5 * w, .63 * h), width: .3 * w, height: .3 * h),
        .62, 5.0, false, c);
    cv.restore();
    cv.drawPath(_sparkPath(.80 * w, .22 * h, .075 * w), Paint()..color = Colors.white.withAlpha(235));
  }

  @override
  bool shouldRepaint(_LogoPainter o) => o.a != a || o.a2 != a2;
}
