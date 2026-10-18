import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alarm.dart';
import 'core.dart';
import 'native.dart';
import 'pages.dart';
import 'settings.dart';

String fmtMs(int ms, {bool cs = false}) {
  final t = ms < 0 ? 0 : ms;
  final m = t ~/ 60000;
  final s = (t ~/ 1000) % 60;
  if (cs) return fa('${two(m)}:${two(s)}.${two((t ~/ 10) % 100)}');
  return fa('${two(m)}:${two(s)}');
}

String fmtHms(int ms) {
  final t = ms < 0 ? 0 : ms;
  final h = t ~/ 3600000;
  final m = (t ~/ 60000) % 60;
  final s = (t ~/ 1000) % 60;
  return fa(h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}');
}

// دکمه گرد با آیکون طراحی‌شده
Widget circleBtn(String icon, VoidCallback f,
    {bool primary = false, double size = 64}) {
  return GestureDetector(
    onTap: f,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: primary
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kAccentLight, kAccent])
            : LinearGradient(colors: [wh(.8), wh(.35)]),
        border: Border.all(color: wh(.9), width: 1.2),
        boxShadow: primary
            ? [
                BoxShadow(
                    color: kAccent.withAlpha(90),
                    blurRadius: 18,
                    offset: Offset(0, 8))
              ]
            : null,
      ),
      child: Center(
          child: AppIcon(icon,
              size: size * .44,
              color: primary ? Colors.white : kInk,
              fill: primary ? Colors.white.withAlpha(60) : kAccent.withAlpha(50))),
    ),
  );
}

// ───────────────────────── کنترلرهای سراسری (با رفتن به صفحه دیگه هم ادامه می‌دن) ──────[...]
class PomoCtl extends ChangeNotifier {
  List<int> mins = [25, 5, 15];
  bool auto = true;
  int mode = 0;
  int remainMs = 25 * 60000;
  int cycle = 0;
  bool running = false;
  DateTime? end;
  Timer? _t;

  PomoCtl() {
    mins = [
      prefs.getInt('pf') ?? 25,
      prefs.getInt('ps') ?? 5,
      prefs.getInt('pl') ?? 15
    ];
    auto = prefs.getBool('pauto') ?? true;
    remainMs = mins[0] * 60000;
  }

  static const names = ['تمرکز', 'استراحت کوتاه', 'استراحت بلند'];
  int get totalMs => mins[mode] * 60000;
  String get todayKey => 'pomo_${dk(DateTime.now())}';
  int get doneToday => prefs.getInt(todayKey) ?? 0;

  void start() {
    end = DateTime.now().add(Duration(milliseconds: remainMs));
    running = true;
    _t?.cancel();
    _t = Timer.periodic(Duration(milliseconds: 250), (_) => _tick());
    Native.schedule(900001, end!, 'پومودورو: ${names[mode]} تموم شد');
    notifyListeners();
  }

  void _tick() {
    final r = end!.difference(DateTime.now()).inMilliseconds;
    if (r <= 0) {
      _finish();
    } else {
      remainMs = r;
      notifyListeners();
    }
  }

  void pause() {
    _t?.cancel();
    running = false;
    Native.cancel(900001);
    notifyListeners();
  }

  void reset() {
    pause();
    remainMs = totalMs;
    notifyListeners();
  }

  void setMode(int m) {
    pause();
    mode = m;
    remainMs = totalMs;
    notifyListeners();
  }

  void skip() {
    pause();
    _next(false);
  }

  void _finish() {
    _t?.cancel();
    running = false;
    HapticFeedback.vibrate();
    if (mode == 0) {
      prefs.setInt(todayKey, doneToday + 1);
      cycle++;
    }
    _next(auto);
  }

  void _next(bool autoStart) {
    if (mode == 0) {
      mode = (cycle > 0 && cycle % 4 == 0) ? 2 : 1;
    } else {
      mode = 0;
    }
    remainMs = totalMs;
    if (autoStart) {
      start();
    } else {
      notifyListeners();
    }
  }

  void setMins(int i, int v) {
    mins[i] = v < 1 ? 1 : (v > 180 ? 180 : v);
    prefs.setInt(['pf', 'ps', 'pl'][i], mins[i]);
    if (!running && mode == i) remainMs = totalMs;
    notifyListeners();
  }

  void setAuto(bool v) {
    auto = v;
    prefs.setBool('pauto', v);
    notifyListeners();
  }
}

class CdtCtl extends ChangeNotifier {
  int totalMs = 5 * 60000;
  int remainMs = 5 * 60000;
  bool running = false;
  DateTime? end;
  Timer? _t;

  bool get idle => !running && remainMs == totalMs;

  void setTotal(int ms) {
    if (running) return;
    totalMs = ms < 1000 ? 1000 : (ms > 359999000 ? 359999000 : ms);
    remainMs = totalMs;
    notifyListeners();
  }

  void start() {
    if (remainMs < 1000) return;
    end = DateTime.now().add(Duration(milliseconds: remainMs));
    running = true;
    _t?.cancel();
    _t = Timer.periodic(Duration(milliseconds: 200), (_) {
      final r = end!.difference(DateTime.now()).inMilliseconds;
      if (r <= 0) {
        _t?.cancel();
        running = false;
        remainMs = totalMs;
        HapticFeedback.vibrate();
        notifyListeners();
      } else {
        remainMs = r;
        notifyListeners();
      }
    });
    Native.schedule(900002, end!, 'تایمر تموم شد ⏱️');
    notifyListeners();
  }

  void pause() {
    _t?.cancel();
    running = false;
    Native.cancel(900002);
    notifyListeners();
  }

  void reset() {
    pause();
    remainMs = totalMs;
    notifyListeners();
  }
}

class SwCtl extends ChangeNotifier {
  final Stopwatch sw = Stopwatch();
  final List<int> laps = [];
  Timer? _t;

  bool get running => sw.isRunning;
  int get ms => sw.elapsedMilliseconds;

  void toggle() {
    if (sw.isRunning) {
      sw.stop();
      _t?.cancel();
    } else {
      sw.start();
      _t = Timer.periodic(Duration(milliseconds: 40), (_) => notifyListeners());
    }
    notifyListeners();
  }

  void lap() {
    if (sw.isRunning) {
      laps.insert(0, sw.elapsedMilliseconds);
      notifyListeners();
    }
  }

  void reset() {
    sw.stop();
    sw.reset();
    _t?.cancel();
    laps.clear();
    notifyListeners();
  }
}

final pomo = PomoCtl();
final cdt = CdtCtl();
final swc = SwCtl();

// ───────────────────────── پومودورو ─────────────────────────
class PomodoroPage extends StatelessWidget {
  PomodoroPage({super.key});

  Widget stepper(String label, int i) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15.5))),
        circleBtn('minus', () => pomo.setMins(i, pomo.mins[i] - 1), size: 38),
        SizedBox(
            width: 70,
            child: Center(
                child: Text('${fa(pomo.mins[i])} دقیقه',
                    style: TextStyle(fontWeight: FontWeight.w900)))),
        circleBtn('plus', () => pomo.setMins(i, pomo.mins[i] + 1),
            size: 38, primary: true),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pomo,
      builder: (c, _) {
        final p = 1 - pomo.remainMs / pomo.totalMs;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            PageTitle('پومودورو'),
            Glass(
              padding: EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => pomo.setMode(i),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          margin: EdgeInsets.symmetric(horizontal: 3),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: pomo.mode == i
                                ? LinearGradient(
                                    colors: [kAccentLight, kAccent])
                                : LinearGradient(colors: [wh(.7), wh(.3)]),
                            border: Border.all(color: wh(.8)),
                          ),
                          child: Center(
                              child: Text(PomoCtl.names[i],
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: pomo.mode == i
                                          ? Colors.white
                                          : kInk))),
                        ),
                      ),
                    ),
                ]),
                SizedBox(height: 24),
                Ring(p,
                    size: 230,
                    stroke: 14,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(fmtMs((pomo.remainMs / 1000).ceil() * 1000),
                          style: TextStyle(
                              fontSize: 52, fontWeight: FontWeight.w900)),
                      Text(PomoCtl.names[pomo.mode],
                          style: TextStyle(
                              color: kSub, fontWeight: FontWeight.w800)),
                    ])),
                SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  circleBtn('reset', pomo.reset),
                  SizedBox(width: 18),
                  circleBtn(pomo.running ? 'pause' : 'play',
                      pomo.running ? pomo.pause : pomo.start,
                      primary: true, size: 82),
                  SizedBox(width: 18),
                  circleBtn('skip', pomo.skip),
                ]),
                SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 12,
                      height: 12,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < pomo.cycle % 4
                            ? kAccent
                            : kSub.withAlpha(60),
                      ),
                    ),
                ]),
                SizedBox(height: 8),
                Text('جلسه‌های تمرکز امروز: ${fa(pomo.doneToday)}',
                    style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
              ]),
            ),
            SizedBox(height: 14),
            Glass(
              child: Column(children: [
                stepper('مدت تمرکز', 0),
                stepper('استراحت کوتاه', 1),
                stepper('استراحت بلند', 2),
                Divider(),
                Row(children: [
                  Expanded(
                      child: Text('شروع خودکار مرحله بعد',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5))),
                  Switch(value: pomo.auto, onChanged: pomo.setAuto),
                ]),
              ]),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                  'وقتی زمان تموم بشه، حتی اگه برنامه بسته باشه آلارم به صدا درمیاد (دسترسی‌ها رو از تنظیمات چک کن).',
                  style: TextStyle(
                      color: kSub,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.7)),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── تایمر ─────────────────────────
class TimerPage extends StatelessWidget {
  TimerPage({super.key});

  Widget unit(String label, int value, int step, int unitMs, int max) {
    final total = cdt.totalMs;
    void change(int d) {
      var h = total ~/ 3600000, m = (total ~/ 60000) % 60, s = (total ~/ 1000) % 60;
      if (unitMs == 3600000) h = (h + d) % 100;
      if (unitMs == 60000) m = (m + d) % 60;
      if (unitMs == 1000) s = (s + d) % 60;
      if (h < 0) h += 100;
      if (m < 0) m += 60;
      if (s < 0) s += 60;
      cdt.setTotal(h * 3600000 + m * 60000 + s * 1000);
    }

    return Expanded(
      child: Column(children: [
        GestureDetector(
            onTap: () => change(step),
            child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    size: 32, color: kAccent))),
        Text(fa(two(value)),
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
        GestureDetector(
            onTap: () => change(-step),
            child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 32, color: kAccent))),
        Text(label,
            style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cdt,
      builder: (c, _) {
        final total = cdt.totalMs;
        final presets = [
          (1, 'یک دقیقه'), (5, 'پنج دقیقه'), (10, 'ده دقیقه'),
          (15, 'پانزده'), (30, 'سی دقیقه'), (60, 'یک ساعت')
        ];
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            PageTitle('تایمر'),
            Glass(
              padding: EdgeInsets.all(20),
              child: Column(children: [
                if (cdt.idle)
                  Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        unit('ساعت', total ~/ 3600000, 1, 3600000, 99),
                        unit('دقیقه', (total ~/ 60000) % 60, 1, 60000, 59),
                        unit('ثانیه', (total ~/ 1000) % 60, 5, 1000, 59),
                      ])
                else
                  Ring(1 - cdt.remainMs / cdt.totalMs,
                      size: 230,
                      stroke: 14,
                      child: Text(fmtHms((cdt.remainMs / 1000).ceil() * 1000),
                          style: TextStyle(
                              fontSize: 44, fontWeight: FontWeight.w900))),
                SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  circleBtn('reset', cdt.reset),
                  SizedBox(width: 18),
                  circleBtn(cdt.running ? 'pause' : 'play',
                      cdt.running ? cdt.pause : cdt.start,
                      primary: true, size: 82),
                ]),
              ]),
            ),
            SizedBox(height: 14),
            Glass(
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in presets)
                      GestureDetector(
                        onTap: () {
                          if (cdt.running) cdt.pause();
                          cdt.totalMs = 0;
                          cdt.setTotal(p.$1 * 60000);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(colors: [wh(.8), wh(.35)]),
                            border: Border.all(color: wh(.9)),
                          ),
                          child: Text(p.$2,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                  ]),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── کرنومتر ─────────────────────────
class StopwatchPage extends StatelessWidget {
  StopwatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: swc,
      builder: (c, _) {
        final laps = swc.laps;
        final splits = <int>[
          for (var i = 0; i < laps.length; i++)
            laps[i] - (i + 1 < laps.length ? laps[i + 1] : 0)
        ];
        int? best, worst;
        if (splits.length >= 3) {
          best = splits.reduce((a, b) => a < b ? a : b);
          worst = splits.reduce((a, b) => a > b ? a : b);
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            PageTitle('کرنومتر'),
            Glass(
              padding: EdgeInsets.all(24),
              child: Column(children: [
                Text(fmtMs(swc.ms, cs: true),
                    style: TextStyle(
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  circleBtn('reset', swc.reset),
                  SizedBox(width: 18),
                  circleBtn(swc.running ? 'pause' : 'play', swc.toggle,
                      primary: true, size: 82),
                  SizedBox(width: 18),
                  circleBtn('flag', swc.lap),
                ]),
              ]),
            ),
            SizedBox(height: 14),
            if (laps.isNotEmpty)
              Glass(
                child: Column(children: [
                  for (var i = 0; i < laps.length; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Text('دور ${fa(laps.length - i)}',
                            style: TextStyle(
                                color: kSub, fontWeight: FontWeight.w800)),
                        Spacer(),
                        Text(fmtMs(splits[i], cs: true),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: splits[i] == best
                                    ? Color(0xFF1FA67A)
                                    : splits[i] == worst
                                        ? kDanger
                                        : kInk)),
                        SizedBox(width: 18),
                        Text(fmtMs(laps[i], cs: true),
                            style: TextStyle(
                                color: kSub, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
              ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── عادت‌ساز ─────────────────────────
class HabitsPage extends StatelessWidget {
  HabitsPage({super.key});

  void toggle(Map<String, dynamic> h, String day) {
    final days = List<String>.from(h['days'] as List);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    h['days'] = days;
    store.save();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final now = dayOnly(DateTime.now());
        final today = dk(now);
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            PageTitle('عادت‌ساز',
                trailing: GIcon(Icons.add_rounded, () async {
                  final v = await askText(c, 'عادت جدید',
                      hint: 'مثلا: مطالعه ۲۰ دقیقه');
                  if (v != null && v.isNotEmpty) {
                    store.habits.add({'id': newId(), 'name': v, 'days': []});
                    store.save();
                  }
                })),
            if (store.habits.isEmpty)
              Padding(
                padding: EdgeInsets.all(40),
                child: Column(children: [
                  Text('🌱', style: TextStyle(fontSize: 70)),
                  SizedBox(height: 10),
                  Text('اولین عادتت رو بساز',
                      style: TextStyle(
                          color: kSub,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            for (final h in store.habits)
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Glass(
                  child: Column(children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => toggle(h, today),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: (h['days'] as List).contains(today)
                                ? LinearGradient(
                                    colors: [kAccentLight, kAccent])
                                : null,
                            border: Border.all(color: kAccent, width: 2.2),
                          ),
                          child: (h['days'] as List).contains(today)
                              ? Icon(Icons.check_rounded,
                                  color: Colors.white)
                              : null,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final v = await askText(c, 'تغییر نام عادت',
                                initial: h['name'] as String);
                            if (v != null && v.isNotEmpty) {
                              h['name'] = v;
                              store.save();
                            }
                          },
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h['name'] as String,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17)),
                                Text(
                                    '🔥 ${fa(habitStreak(h['days'] as List))} روز پیاپی',
                                    style: TextStyle(
                                        color: kSub,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5)),
                              ]),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (await confirm(
                              c, 'عادت «${h['name']}» حذف بشه؟')) {
                            store.habits.remove(h);
                            store.save();
                          }
                        },
                        child: AppIcon('trash', size: 22, color: kDanger),
                      ),
                    ]),
                    SizedBox(height: 14),
                    Row(children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Builder(builder: (_) {
                            final d = DateTime(now.year, now.month, now.day - i);
                            final on = (h['days'] as List).contains(dk(d));
                            return GestureDetector(
                              onTap: () => toggle(h, dk(d)),
                              child: Column(children: [
                                Text(wDay(d).substring(0, 1),
                                    style: TextStyle(
                                        color: kSub,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: on ? kAccent : null,
                                    border: Border.all(
                                        color: on ? kAccent : kSub.withAlpha(90),
                                        width: 1.6),
                                  ),
                                  child: on
                                      ? Icon(Icons.check_rounded,
                                          size: 16, color: Colors.white)
                                      : null,
                                ),
                              ]),
                            );
                          }),
                        ),
                    ]),
                  ]),
                ),
              ),
            if (store.habits.isNotEmpty)
              Center(
                  child: Text('روی دایره‌ها بزن تا روزهای قبل رو هم ویرایش کنی',
                      style: TextStyle(color: kSub, fontSize: 11.5))),
          ],
        );
      },
    );
  }
}

// ───────────────────────── تقویم شمسی ─────────────────────────
class MonthGrid extends StatelessWidget {
  MonthGrid({
    super.key,
    required this.jy,
    required this.jm,
    this.marks = const <String>{},
    this.onDay,
    this.cell = 44,
  });
  final int jy;
  final int jm;
  final Set<String> marks;
  final void Function(DateTime)? onDay;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final first = jToG(jy, jm, 1);
    final next = jToG(jm == 12 ? jy + 1 : jy, jm == 12 ? 1 : jm + 1, 1);
    final len = DateTime.utc(next.year, next.month, next.day)
        .difference(DateTime.utc(first.year, first.month, first.day))
        .inDays;
    final offset = (first.weekday + 1) % 7;
    final today = dk(DateTime.now());
    final rows = ((offset + len) / 7).ceil();
    final heads = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    Widget dayCell(int col, int day) {
      if (day < 1 || day > len) return SizedBox(height: cell);
      final g = DateTime(first.year, first.month, first.day + day - 1);
      final isToday = dk(g) == today;
      final fri = col == 6;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDay == null ? null : () => onDay!(g),
        child: SizedBox(
          height: cell,
          child: Center(
            child: Container(
              width: cell * .84,
              height: cell * .84,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: isToday ? kAccent : null),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fa(day),
                        style: TextStyle(
                            fontSize: cell < 26 ? 9.5 : (cell < 38 ? 12 : 15),
                            fontWeight: FontWeight.w800,
                            color: isToday
                                ? Colors.white
                                : fri
                                    ? kDanger
                                    : kInk)),
                    if (marks.contains(dk(g)))
                      Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday
                                  ? Colors.white
                                  : Color(0xFFFF9500))),
                  ]),
            ),
          ),
        ),
      );
    }

    return Column(children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
              child: Center(
                  child: Text(heads[i],
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: i == 6 ? kDanger : kSub)))),
      ]),
      SizedBox(height: 4),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var col = 0; col < 7; col++)
            Expanded(child: dayCell(col, r * 7 + col - offset + 1)),
        ]),
    ]);
  }
}

class CalendarPage extends StatefulWidget {
  CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late int jy;
  late int jm;

  @override
  void initState() {
    super.initState();
    final j = toJalali(DateTime.now());
    jy = j[0];
    jm = j[1];
  }

  void move(int d) {
    setState(() {
      jm += d;
      if (jm > 12) {
        jm = 1;
        jy++;
      }
      if (jm < 1) {
        jm = 12;
        jy--;
      }
    });
  }

  void showDay(BuildContext c, DateTime g) {
    final k = dk(g);
    final evs = store.events.where((e) => e['date'] == k).toList();
    final tks = store.tasks.where((t) => t['due'] == k).toList();
    showModalBottomSheet(
      context: c,
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(18),
          children: [
            Text('${wDay(g)}، ${jStr(g)}',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text('${g.year}/${two(g.month)}/${two(g.day)}',
                style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
            SizedBox(height: 14),
            if (evs.isEmpty && tks.isEmpty)
              Text('برای این روز چیزی ثبت نشده',
                  style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
            for (final e in evs)
              ListTile(
                leading: Text(e['emoji'] as String? ?? '📅',
                    style: TextStyle(fontSize: 26)),
                title: Text(e['title'] as String,
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('رویداد'),
              ),
            for (final t in tks)
              ListTile(
                leading: Icon(
                    t['done'] == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: kAccent),
                title: Text(t['title'] as String,
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('کار'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final marks = <String>{
          ...store.events.map((e) => e['date'] as String),
          ...store.tasks
              .map((t) => (t['due'] as String?) ?? '')
              .where((e) => e.isNotEmpty),
        };
        final now = toJalali(DateTime.now());
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            PageTitle('تقویم شمسی',
                trailing: GBtn('امروز', () {
                  setState(() {
                    jy = now[0];
                    jm = now[1];
                  });
                })),
            Glass(
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                      onTap: () => move(1),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 36, color: kAccent)),
                  Expanded(
                      child: Center(
                          child: Text('${jMonths[jm - 1]} ${fa(jy)}',
                              style: TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w900)))),
                  GestureDetector(
                      onTap: () => move(-1),
                      child: Icon(Icons.chevron_left_rounded,
                          size: 36, color: kAccent)),
                ]),
                SizedBox(height: 8),
                MonthGrid(
                    jy: jy,
                    jm: jm,
                    marks: marks,
                    onDay: (g) => showDay(c, g)),
              ]),
            ),
            SizedBox(height: 10),
            Center(
                child: Text('نقطه نارنجی یعنی اون روز رویداد یا کار داره',
                    style: TextStyle(color: kSub, fontSize: 12))),
          ],
        );
      },
    );
  }
}

// ───────────────────────── صفحه ابزارها ─────────────────────────
class ToolsPage extends StatelessWidget {
  ToolsPage({super.key});

  Widget tile(BuildContext c, String icon, Color col, String t, String s,
      Widget page) {
    return Glass(
      onTap: () => openPage(c, page),
      child: SizedBox(
        width: double.infinity,
