import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui.dart';
export 'ui.dart';

// ───────────────────────── رنگ‌ها و ابزارهای کوچک ─────────────────────────


const _faDigits = '۰۱۲۳۴۵۶۷۸۹';
String fa(Object n) => n
    .toString()
    .split('')
    .map((c) {
      final i = '0123456789'.indexOf(c);
      return i < 0 ? c : _faDigits[i];
    })
    .join();

String en(String s) {
  var r = s;
  for (var i = 0; i < 10; i++) {
    r = r.replaceAll(_faDigits[i], '$i');
  }
  return r;
}

String two(int n) => n.toString().padLeft(2, '0');
String dk(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ───────────────────────── تقویم شمسی ─────────────────────────
const jMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
];
const wDays = [
  'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'
];
String wDay(DateTime d) => wDays[d.weekday % 7];

List<int> toJalali(DateTime d) {
  final gy = d.year, gm = d.month, gd = d.day;
  final gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 +
      (365 * gy) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int jm, jd;
  if (days < 186) {
    jm = 1 + days ~/ 31;
    jd = 1 + days % 31;
  } else {
    jm = 7 + (days - 186) ~/ 30;
    jd = 1 + (days - 186) % 30;
  }
  return [jy, jm, jd];
}

DateTime jToG(int jy, int jm, int jd) {
  jy += 1595;
  var days = -355668 +
      (365 * jy) +
      ((jy ~/ 33) * 8) +
      (((jy % 33) + 3) ~/ 4) +
      jd +
      (jm < 7 ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var gd = days + 1;
  final sal = [
    0, 31, ((gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0) ? 29 : 28,
    31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  ];
  var gm = 0;
  while (gm < 13 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return DateTime(gy, gm, gd);
}

String jStr(DateTime d) {
  final j = toJalali(d);
  return '${fa(j[2])} ${jMonths[j[1] - 1]} ${fa(j[0])}';
}

// ───────────────────────── ذخیره‌سازی ─────────────────────────
late SharedPreferences prefs;

class Store extends ChangeNotifier {
  List<Map<String, dynamic>> tasks = [], notes = [], events = [], habits = [], txs = [];
  int cityIdx = 0;

  List<Map<String, dynamic>> _l(String k) {
    final s = prefs.getString(k);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void load() {
    tasks = _l('tasks');
    notes = _l('notes');
    events = _l('events');
    habits = _l('habits');
    txs = _l('txs');
    cityIdx = prefs.getInt('city') ?? 0;
  }

  void save() {
    prefs.setString('tasks', jsonEncode(tasks));
    prefs.setString('notes', jsonEncode(notes));
    prefs.setString('events', jsonEncode(events));
    prefs.setString('habits', jsonEncode(habits));
    prefs.setString('txs', jsonEncode(txs));
    notifyListeners();
  }

  void poke() => notifyListeners();

  int water(String day) => prefs.getInt('w_$day') ?? 0;
  void setWater(String day, int v) {
    prefs.setInt('w_$day', min(30, max(0, v)));
    notifyListeners();
  }

  void setCity(int i) {
    cityIdx = i;
    prefs.setInt('city', i);
    notifyListeners();
  }
}

final store = Store();
String newId() => DateTime.now().microsecondsSinceEpoch.toString();


class Ring extends StatelessWidget {
  Ring(this.p, {super.key, this.size = 84, this.stroke = 9, this.child});
  final double p;
  final double size;
  final double stroke;
  final Widget? child;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(p, stroke),
          child: Center(child: child),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.stroke);
  final double p;
  final double stroke;
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(
        stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    c.drawArc(
        r,
        0,
        2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = wh(.6));
    final v = p.clamp(0.0, 1.0);
    if (v > 0) {
      c.drawArc(
          r,
          -pi / 2,
          2 * pi * v,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = stroke
            ..shader = SweepGradient(
              colors: [kAccentLight, kAccent],
              transform: GradientRotation(-pi / 2),
            ).createShader(r));
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.p != p;
}

class GBtn extends StatelessWidget {
  GBtn(this.label, this.onTap,
      {super.key, this.icon, this.primary = false});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: primary
              ? LinearGradient(colors: [kAccentLight, kAccent])
              : LinearGradient(colors: [wh(.8), wh(.45)]),
          border: Border.all(color: wh(.8)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: primary ? Colors.white : kInk),
            SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: primary ? Colors.white : kInk)),
        ]),
      ),
    );
  }
}

class GIcon extends StatelessWidget {
  GIcon(this.icon, this.onTap, {super.key});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Glass(
        radius: 18,
        padding: EdgeInsets.all(10),
        onTap: onTap,
        child: Icon(icon, color: kAccent, size: 22),
      );
}

class PageTitle extends StatelessWidget {
  PageTitle(this.t, {super.key, this.trailing});
  final String t;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 10),
        child: Row(children: [
          Expanded(
              child: Text(t,
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

Future<String?> askText(BuildContext context, String title,
    {String hint = '', String initial = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text('انصراف')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: Text('تایید')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      content: Text(msg, style: TextStyle(fontSize: 16)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('خیر')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('بله، حذف کن')),
      ],
    ),
  );
  return r ?? false;
}

Future<void> alarmBuzz() async {
  for (var i = 0; i < 3; i++) {
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
    await Future.delayed(Duration(milliseconds: 600));
  }
}


int habitStreak(List days) {
  final set = days.toSet();
  var d = dayOnly(DateTime.now());
  if (!set.contains(dk(d))) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (set.contains(dk(d))) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

// ───────────────────────── یادداشت‌ها ─────────────────────────
class NotesPage extends StatelessWidget {
  NotesPage({super.key});

  void openNote(BuildContext context, Map<String, dynamic> n) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => NoteEditor(note: n)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        return Column(children: [
          PageTitle('یادداشت‌ها',
              trailing: GIcon(Icons.add_rounded, () {
                final n = <String, dynamic>{
                  'id': newId(),
                  'title': '',
                  'body': '',
                  'ts': DateTime.now().toIso8601String(),
                };
                store.notes.insert(0, n);
                store.save();
                openNote(context, n);
              })),
          Expanded(
            child: store.notes.isEmpty
                ? Center(
                    child: Text('یادداشتی نداری. با + یکی بساز 📝',
                        style: TextStyle(
                            color: kSub,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(18, 4, 18, 120),
                    itemCount: store.notes.length,
                    itemBuilder: (c, i) {
                      final n = store.notes[i];
                      final title = (n['title'] as String).trim();
                      final body = (n['body'] as String).trim();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Glass(
                          onTap: () => openNote(context, n),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title.isEmpty ? 'بدون عنوان' : title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17)),
                                  if (body.isNotEmpty) ...[
                                    SizedBox(height: 6),
                                    Text(body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: kSub,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                  SizedBox(height: 8),
                                  Text(
                                      jStr(DateTime.parse(n['ts'] as String)),
                                      style: TextStyle(
                                          color: kAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }
}

class NoteEditor extends StatefulWidget {
  NoteEditor({super.key, required this.note});
  final Map<String, dynamic> note;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController tc =
      TextEditingController(text: widget.note['title'] as String);
  late final TextEditingController bc =
      TextEditingController(text: widget.note['body'] as String);

  void sync() {
    widget.note['title'] = tc.text;
    widget.note['body'] = bc.text;
    widget.note['ts'] = DateTime.now().toIso8601String();
    store.save();
  }

  @override
  void dispose() {
    final empty = tc.text.trim().isEmpty && bc.text.trim().isEmpty;
    tc.dispose();
    bc.dispose();
    if (empty) store.notes.remove(widget.note);
    WidgetsBinding.instance.addPostFrameCallback((_) => store.save());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: Backdrop()),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(children: [
              Row(children: [
                GIcon(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                Spacer(),
                GIcon(Icons.delete_rounded, () async {
                  if (await confirm(context, 'این یادداشت حذف بشه؟')) {
                    tc.clear();
                    bc.clear();
                    if (context.mounted) Navigator.pop(context);
                  }
                }),
              ]),
              SizedBox(height: 14),
              Expanded(
                child: Glass(
                  padding: EdgeInsets.all(20),
                  child: Column(children: [
                    TextField(
                      controller: tc,
                      onChanged: (_) => sync(),
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                      decoration: InputDecoration.collapsed(
                          hintText: 'عنوان'),
                    ),
                    Divider(height: 24),
                    Expanded(
                      child: TextField(
                        controller: bc,
                        onChanged: (_) => sync(),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(fontSize: 16, height: 1.7),
                        decoration: InputDecoration.collapsed(
                            hintText: 'هر چی تو ذهنته بنویس...'),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────── مناسبت‌ها ─────────────────────────
class EventsPage extends StatelessWidget {
  EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final today = dayOnly(DateTime.now());
        final list = [...store.events];
        list.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
        return Column(children: [
          PageTitle('مناسبت‌ها',
              trailing: GIcon(Icons.add_rounded, () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: kSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30))),
                  builder: (_) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AddEventSheet()),
                );
              })),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('تولد، سالگرد، امتحان... هر چی مهمه اضافه کن 🎂',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: kSub,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(18, 4, 18, 120),
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final e = list[i];
                      final d = DateTime.parse(e['date'] as String);
                      final diff = dayOnly(d).difference(today).inDays;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Glass(
                          onLongPress: () async {
                            if (await confirm(
                                context, 'مناسبت «${e['title']}» حذف بشه؟')) {
                              store.events.removeWhere((x) => x['id'] == e['id']);
                              store.save();
                            }
                          },
                          child: Row(children: [
                            Text(e['emoji'] as String? ?? '📅',
                                style: TextStyle(fontSize: 34)),
                            SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(e['title'] as String,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17)),
                                  Text(jStr(d),
                                      style: TextStyle(
                                          color: kSub,
                                          fontWeight: FontWeight.w600)),
                                ])),
                            Column(children: [
                              Text(
                                  diff == 0
                                      ? 'امروز'
                                      : fa(diff.abs()),
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: diff < 0 ? kSub : kAccent)),
                              if (diff != 0)
                                Text(diff < 0 ? 'روز پیش' : 'روز دیگر',
                                    style: TextStyle(
                                        color: kSub,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }
}

class AddEventSheet extends StatefulWidget {
  AddEventSheet({super.key});
  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final title = TextEditingController();
  late final List<int> j = toJalali(DateTime.now());
  late final y = TextEditingController(text: fa(j[0]));
  late final m = TextEditingController(text: fa(j[1]));
  late final d = TextEditingController(text: fa(j[2]));
  String emoji = '🎂';
  String? err;
  static const emojis = ['🎂', '💍', '🎓', '✈️', '🎉', '📝', '❤️', '📅'];

  @override
  void dispose() {
    title.dispose();
    y.dispose();
    m.dispose();
    d.dispose();
    super.dispose();
  }

  void submit() {
    final yy = int.tryParse(en(y.text.trim()));
    final mm = int.tryParse(en(m.text.trim()));
    final dd = int.tryParse(en(d.text.trim()));
    if (title.text.trim().isEmpty) {
      setState(() => err = 'عنوان رو بنویس');
      return;
    }
    if (yy == null ||
        mm == null ||
        dd == null ||
        mm < 1 ||
        mm > 12 ||
        dd < 1 ||
        dd > 31) {
      setState(() => err = 'تاریخ درست نیست');
      return;
    }
    final g = jToG(yy, mm, dd);
    store.events.add({
      'id': newId(),
      'title': title.text.trim(),
      'emoji': emoji,
      'date': dk(g),
    });
    store.save();
    Navigator.pop(context);
  }

  Widget numField(TextEditingController c, String label) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 22, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('مناسبت جدید',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        SizedBox(height: 14),
        TextField(
          controller: title,
          decoration: InputDecoration(
              labelText: 'عنوان (مثلا تولد مریم)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        SizedBox(height: 12),
        Row(children: [
          numField(d, 'روز'),
          SizedBox(width: 8),
          numField(m, 'ماه (۱ تا ۱۲)'),
          SizedBox(width: 8),
          numField(y, 'سال'),
        ]),
        SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final e in emojis)
            GestureDetector(
              onTap: () => setState(() => emoji = e),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: emoji == e ? kAccent.withAlpha(0x33) : Colors.transparent,
                  border: Border.all(
                      color: emoji == e ? kAccent : Colors.transparent),
                ),
                child: Text(e, style: TextStyle(fontSize: 24)),
              ),
            ),
        ]),
        if (err != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(err!, style: TextStyle(color: Color(0xFFE5484D))),
          ),
        SizedBox(height: 14),
        SizedBox(
            width: double.infinity,
            child: Center(child: GBtn('ذخیره', submit, primary: true))),
      ]),
    );
  }
}



// ───────────────────────── تنظیمات سراسری UI ─────────────────────────
final ValueNotifier<int> tabIdx = ValueNotifier<int>(0);

void applyUiPrefs() {
  accentIdx.value = prefs.getInt('accent') ?? 3;
  manualDark.value = prefs.getBool('dark') ?? false;
  sysTheme.value = prefs.getBool('systheme') ?? false;
  liquidGlass.value = prefs.getBool('liquid') ?? true;
  smartSearch.value = prefs.getBool('smart') ?? true;
  glassLevel.value = prefs.getDouble('glass') ?? 0.3;
  animBg.value = prefs.getBool('anim') ?? true;
  textScale.value = prefs.getDouble('tscale') ?? 1.0;
}
