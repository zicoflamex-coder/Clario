import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alarm.dart';
import 'core.dart';
import 'native.dart';

// ───────────────────────── آب‌وهوا (Open-Meteo رایگان) ─────────────────────────
const cityNames = [
  'تهران', 'مشهد', 'اصفهان', 'شیراز', 'تبریز', 'کرج', 'اهواز', 'رشت',
  'کرمان', 'یزد', 'ارومیه', 'قم', 'همدان', 'بندرعباس', 'کرمانشاه', 'زاهدان'
];
const cityLat = [
  35.69, 36.30, 32.65, 29.59, 38.08, 35.83, 31.32, 37.28,
  30.28, 31.90, 37.55, 34.64, 34.80, 27.18, 34.31, 29.50
];
const cityLon = [
  51.39, 59.60, 51.67, 52.58, 46.29, 50.99, 48.67, 49.58,
  57.08, 54.37, 45.07, 50.88, 48.51, 56.27, 47.07, 60.86
];

String wxText(int c) {
  if (c == 0) return 'صاف';
  if (c <= 2) return 'کمی ابری';
  if (c == 3) return 'ابری';
  if (c == 45 || c == 48) return 'مه‌آلود';
  if (c >= 51 && c <= 57) return 'نم‌نم باران';
  if (c >= 61 && c <= 67) return 'بارانی';
  if (c >= 71 && c <= 77) return 'برفی';
  if (c >= 80 && c <= 82) return 'رگبار';
  if (c == 85 || c == 86) return 'برف سنگین';
  if (c >= 95) return 'رعد و برق';
  return 'نامشخص';
}

String wxEmoji(int c, bool day) {
  if (c == 0) return day ? '☀️' : '🌙';
  if (c <= 2) return day ? '🌤️' : '☁️';
  if (c == 3) return '☁️';
  if (c == 45 || c == 48) return '🌫️';
  if (c >= 51 && c <= 57) return '🌦️';
  if (c >= 61 && c <= 67) return '🌧️';
  if (c >= 71 && c <= 77) return '❄️';
  if (c >= 80 && c <= 82) return '🌧️';
  if (c == 85 || c == 86) return '🌨️';
  if (c >= 95) return '⛈️';
  return '🌡️';
}

String wxTip(int t) {
  if (t < 5) return 'هوا سرده، گرم بپوش 🧥';
  if (t < 15) return 'یه ژاکت با خودت ببر 🧣';
  if (t < 28) return 'هوا عالیه، برو بیرون 🌿';
  if (t < 35) return 'هوا گرمه، آب بخور 💧';
  return 'خیلی گرمه! زیر سایه بمون 🥵';
}

class Wx extends ChangeNotifier {
  Map<String, dynamic>? d;
  int? aqi;
  bool loading = false;
  bool failed = false;

  Wx() {
    final c = prefs.getString('wx2');
    if (c != null) {
      try {
        d = Map<String, dynamic>.from(jsonDecode(c) as Map);
      } catch (_) {}
    }
  }

  Future<String?> _get(String url) async {
    try {
      final c = HttpClient()..connectionTimeout = Duration(seconds: 8);
      final req = await c.getUrl(Uri.parse(url));
      final res = await req.close().timeout(Duration(seconds: 12));
      if (res.statusCode != 200) {
        c.close();
        return null;
      }
      final b = await res.transform(utf8.decoder).join();
      c.close();
      return b;
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final lat = cityLat[store.cityIdx], lon = cityLon[store.cityIdx];
    final body = await _get(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,surface_pressure,is_day'
        '&hourly=temperature_2m,weather_code'
        '&daily=temperature_2m_max,temperature_2m_min,weather_code'
        '&forecast_days=7&timezone=auto');
    if (body == null) {
      failed = true;
    } else {
      try {
        d = jsonDecode(body) as Map<String, dynamic>;
        failed = false;
        prefs.setString('wx2', body);
      } catch (_) {
        failed = true;
      }
    }
    final a = await _get(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=us_aqi&timezone=auto');
    if (a != null) {
      try {
        aqi = (((jsonDecode(a) as Map)['current'] as Map)['us_aqi'] as num)
            .round();
      } catch (_) {}
    }
    loading = false;
    notifyListeners();
  }

  Map<String, dynamic>? get cur =>
      d == null ? null : Map<String, dynamic>.from(d!['current'] as Map);
}

final wx = Wx();

void pickCity(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kSurface,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: EdgeInsets.all(14),
        children: [
          for (var i = 0; i < cityNames.length; i++)
            ListTile(
              title: Text(cityNames[i],
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: i == store.cityIdx
                  ? Icon(Icons.check_circle_rounded, color: kAccent)
                  : null,
              onTap: () {
                store.setCity(i);
                wx.load();
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}

// ───────────────────────── کارها ─────────────────────────
const catNames = ['شخصی', 'کار', 'مطالعه', 'خرید', 'سلامت', 'سفر'];
const catColors = [
  Color(0xFF0A84FF), Color(0xFFFF9500), Color(0xFFFF3B30),
  Color(0xFFAF52DE), Color(0xFF34C759), Color(0xFFFF2D55)
];
const prioNames = ['پایین', 'متوسط', 'بالا'];
const prioColors = [Color(0xFF34C759), Color(0xFFFF9500), Color(0xFFFF3B30)];

int _i(dynamic v, int d) => v is int ? v : d;

class TasksPage extends StatelessWidget {
  TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final list = [...store.tasks];
        list.sort((a, b) {
          final d = (a['done'] == true ? 1 : 0) - (b['done'] == true ? 1 : 0);
          if (d != 0) return d;
          return _i(b['prio'], 1) - _i(a['prio'], 1);
        });
        final today = dayOnly(DateTime.now());
        return Stack(children: [
          list.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ClarioMascot(size: 140, mood: 'sleep'),
                    SizedBox(height: 16),
                    Text('هنوز کاری ثبت نکردی!',
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('کارهات رو بسپار به کلاریو',
                        style: TextStyle(
                            fontSize: 16,
                            color: kSub,
                            fontWeight: FontWeight.w700)),
                  ]),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, top + 96, 16, 190),
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final t = list[i];
                    final done = t['done'] == true;
                    final cat = _i(t['cat'], 0).clamp(0, 5).toInt();
                    final chk = (t['check'] as List?) ?? [];
                    final chkDone =
                        chk.where((e) => (e as Map)['d'] == true).length;
                    final dueS = (t['due'] as String?) ?? '';
                    DateTime? due;
                    if (dueS.isNotEmpty) due = DateTime.tryParse(dueS);
                    final overdue =
                        due != null && !done && dayOnly(due).isBefore(today);
                    final at = alarmAt(t);
                    final parts = <String>[
                      if (due != null) jStr(due),
                      if (t['alarm'] == true && at != null)
                        '⏰ ${timeStr(at)}',
                      if (chk.isNotEmpty)
                        '${fa(chkDone)}/${fa(chk.length)} مورد',
                    ];
                    Widget bg(Alignment al) => Container(
                          decoration: BoxDecoration(
                              color: kDanger.withAlpha(70),
                              borderRadius: BorderRadius.circular(26)),
                          alignment: al,
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: AppIcon('trash', size: 26, color: kDanger),
                        );
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey(t['id']),
                        background: bg(Alignment.centerRight),
                        secondaryBackground: bg(Alignment.centerLeft),
                        onDismissed: (_) {
                          cancelTaskAlarm(t);
                          store.tasks.removeWhere((e) => e['id'] == t['id']);
                          store.save();
                        },
                        child: Glass(
                          radius: 24,
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          onTap: () => Navigator.push(
                              c,
                              MaterialPageRoute(
                                  builder: (_) => TaskForm(task: t))),
                          child: Row(children: [
                            GestureDetector(
                              onTap: () {
                                t['done'] = !done;
                                store.save();
                                syncTaskAlarm(t);
                              },
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done ? catColors[cat] : null,
                                  border: Border.all(
                                      color: catColors[cat], width: 2.4),
                                ),
                                child: done
                                    ? Icon(Icons.check_rounded,
                                        size: 19, color: Colors.white)
                                    : null,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['title'] as String,
                                        style: TextStyle(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w800,
                                            color: done ? kSub : kInk,
                                            decoration: done
                                                ? TextDecoration.lineThrough
                                                : null)),
                                    if (parts.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(parts.join('  •  '),
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    overdue ? kDanger : kSub)),
                                      ),
                                  ]),
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: prioColors[
                                      _i(t['prio'], 1).clamp(0, 2).toInt()]),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Glass(
              radius: 30,
              padding: EdgeInsets.fromLTRB(20, 10, 12, 10),
              child: Row(children: [
                AppIcon('tasks', size: 30, color: kAccent),
                SizedBox(width: 12),
                Expanded(
                    child: Text('لیست کارها',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900))),
                GestureDetector(
                  onTap: () => openPage(c, AlarmsPage()),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: kAccent.withAlpha(28),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      AppIcon('alarm', size: 22, color: kAccent),
                      SizedBox(width: 6),
                      Text('آلارم‌ها',
                          style: TextStyle(
                              color: kAccent, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 118,
            child: GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => TaskForm())),
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                      colors: [kAccentLight, kAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: kAccent.withAlpha(95),
                        blurRadius: 20,
                        offset: Offset(0, 8))
                  ],
                ),
                child: AppIcon('plus', size: 34, color: Colors.white,
                    fill: Color(0x00FFFFFF)),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class TaskForm extends StatefulWidget {
  TaskForm({super.key, this.task});
  final Map<String, dynamic>? task;
  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final title = TextEditingController();
  final note = TextEditingController();
  final chkCtl = TextEditingController();
  int prio = 1;
  int cat = 0;
  DateTime? due;
  bool alarm = false;
  DateTime? alarmTime;
  List<Map<String, dynamic>> files = [];
  final loc = TextEditingController();
  final cost = TextEditingController();
  List<Map<String, dynamic>> check = [];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      title.text = t['title'] as String;
      note.text = (t['note'] as String?) ?? '';
      prio = _i(t['prio'], 1).clamp(0, 2).toInt();
      cat = _i(t['cat'], 0).clamp(0, 5).toInt();
      final ds = (t['due'] as String?) ?? '';
      if (ds.isNotEmpty) due = DateTime.tryParse(ds);
      alarm = t['alarm'] == true;
      files = ((t['files'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      loc.text = (t['loc'] as String?) ?? '';
      cost.text = (t['cost'] as String?) ?? '';
      alarmTime = DateTime.tryParse((t['at'] as String?) ?? '');
      check = ((t['check'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    chkCtl.dispose();
    loc.dispose();
    cost.dispose();
    super.dispose();
  }

  void addCheck() {
    final v = chkCtl.text.trim();
    if (v.isEmpty) return;
    setState(() => check.add({'t': v, 'd': false}));
    chkCtl.clear();
  }

  void save() {
    if (title.text.trim().isEmpty) {
      toast(context, 'عنوان کار رو بنویس');
      return;
    }
    final t = widget.task ??
        <String, dynamic>{'id': newId(), 'done': false};
    t['title'] = title.text.trim();
    t['note'] = note.text.trim();
    t['prio'] = prio;
    t['cat'] = cat;
    t['due'] = due == null ? '' : dk(due!);
    t['check'] = check;
    t['files'] = files;
    t['loc'] = loc.text.trim();
    t['cost'] = cost.text.trim();
    t['alarm'] = alarm && alarmTime != null;
    t['at'] = (alarm && alarmTime != null) ? alarmTime!.toIso8601String() : '';
    if (widget.task == null) store.tasks.insert(0, t);
    store.save();
    syncTaskAlarm(t);
    if (t['alarm'] == true && !alarmTime!.isAfter(DateTime.now())) {
      toast(context, 'زمان آلارم گذشته؛ آلارم فعال نشد');
    }
    Navigator.pop(context);
  }

  Widget label(String s) => Padding(
        padding: EdgeInsets.fromLTRB(8, 18, 8, 8),
        child: Text(s,
            style: TextStyle(
                color: kSub, fontWeight: FontWeight.w800, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        Positioned.fill(child: Backdrop()),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(children: [
                GIcon(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                Expanded(
                    child: Center(
                        child: Text(
                            widget.task == null ? 'تسک جدید' : 'ویرایش تسک',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)))),
                SizedBox(width: 44),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  SizedBox(height: 10),
                  Glass(
                    child: Column(children: [
                      TextField(
                        controller: title,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration.collapsed(
                            hintText: 'عنوان کار'),
                      ),
                      Divider(height: 22),
                      TextField(
                        controller: note,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration.collapsed(
                            hintText: 'یادداشت/توضیحات…'),
                      ),
                    ]),
                  ),
                  label('اولویت'),
                  Glass(
                    radius: 22,
                    padding: EdgeInsets.all(5),
                    child: Row(children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => prio = i),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(17),
                                color: prio == i ? kSurface : null,
                                boxShadow: prio == i
                                    ? [
                                        BoxShadow(
                                            color: Color(0x22000000),
                                            blurRadius: 8)
                                      ]
                                    : null,
                              ),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: prioColors[i])),
                                    SizedBox(width: 6),
                                    Text(prioNames[i],
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ]),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  label('چک‌لیست'),
                  Glass(
                    child: Column(children: [
                      for (var i = 0; i < check.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            GestureDetector(
                              onTap: () => setState(
                                  () => check[i]['d'] = !(check[i]['d'] == true)),
                              child: Icon(
                                  check[i]['d'] == true
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: kAccent),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                                child: Text(check[i]['t'] as String,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        decoration: check[i]['d'] == true
                                            ? TextDecoration.lineThrough
                                            : null))),
                            GestureDetector(
                                onTap: () => setState(() => check.removeAt(i)),
                                child: Icon(Icons.close_rounded,
                                    color: kSub, size: 20)),
                          ]),
                        ),
                      Row(children: [
                        GestureDetector(
                          onTap: addCheck,
                          child: Icon(Icons.add_circle_rounded,
                              color: kAccent, size: 34),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: chkCtl,
                            onSubmitted: (_) => addCheck(),
                            decoration: InputDecoration.collapsed(
                                hintText: 'اینجا بنویسید…'),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                  label('پیوست‌ها'),
                  Glass(
                    child: Column(children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final f = await Native.pickFile();
                          if (f != null) setState(() => files.add(f));
                        },
                        child: Row(children: [
                          iconBadge('clip', Color(0xFF607D8B), size: 42),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text('افزودن فایل',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16))),
                          Text('${fa(files.length)} فایل',
                              style: TextStyle(
                                  color: kSub, fontWeight: FontWeight.w700)),
                          Icon(Icons.chevron_left_rounded, color: kSub),
                        ]),
                      ),
                      for (var i = 0; i < files.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(children: [
                            AppIcon('note', size: 22, color: kAccent),
                            SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    Native.openFile(files[i]['uri'] as String),
                                child: Text(files[i]['name'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: kAccent,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            GestureDetector(
                                onTap: () => setState(() => files.removeAt(i)),
                                child: AppIcon('close', size: 20, color: kSub)),
                          ]),
                        ),
                    ]),
                  ),
                  label('زمان‌بندی'),
                  Glass(
                    onTap: () async {
                      final d = await pickJDate(context, init: due);
                      if (d != null) setState(() => due = d);
                    },
                    child: Row(children: [
                      Container(
                        padding: EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.calendar_month_rounded,
                            color: Colors.white, size: 22),
                      ),
                      SizedBox(width: 12),
                      Text('تاریخ انجام',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Spacer(),
                      Text(due == null ? 'انتخاب نشده' : jStr(due!),
                          style: TextStyle(
                              color: kSub, fontWeight: FontWeight.w700)),
                      if (due != null)
                        GestureDetector(
                            onTap: () => setState(() => due = null),
                            child: Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.close_rounded,
                                    color: kSub, size: 20))),
                    ]),
                  ),
                  label('آلارم'),
                  Glass(
                    child: Column(children: [
                      Row(children: [
                        iconBadge('alarm', Color(0xFFFF9500), size: 42),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text('آلارم برای این کار',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16))),
                        Switch(
                          value: alarm,
                          onChanged: (v) async {
                            if (!v) {
                              setState(() => alarm = false);
                              return;
                            }
                            final at = await pickAlarmDateTime(context,
                                init: alarmTime ?? due);
                            if (at != null) {
                              setState(() {
                                alarm = true;
                                alarmTime = at;
                              });
                            }
                          },
                        ),
                      ]),
                      if (alarm && alarmTime != null)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final at = await pickAlarmDateTime(context,
                                init: alarmTime);
                            if (at != null) setState(() => alarmTime = at);
                          },
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Row(children: [
                              Text('${jStr(alarmTime!)}  •  ${timeStr(alarmTime!)}',
                                  style: TextStyle(
                                      color: kAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                              Spacer(),
                              Text('تغییر زمان',
                                  style: TextStyle(
                                      color: kSub,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                  label('مکان و هزینه'),
                  Glass(
                    child: Column(children: [
                      Row(children: [
                        iconBadge('pin', Color(0xFF34C759), size: 42),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: loc,
                            decoration: InputDecoration(
                                hintText: 'موقعیت مکانی',
                                border: InputBorder.none),
                          ),
                        ),
                      ]),
                      Divider(height: 8),
                      Row(children: [
                        iconBadge('finance', Color(0xFFFF9500), size: 42),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: cost,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                hintText: 'هزینه (تومان)',
                                border: InputBorder.none),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                  label('دسته‌بندی'),
                  Glass(
                    child: Column(children: [
                      Row(children: [
                        Text(catNames[cat],
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ]),
                      SizedBox(height: 12),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        for (var i = 0; i < catColors.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => cat = i),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: catColors[i],
                                  border: cat == i
                                      ? Border.all(color: kInk, width: 2.5)
                                      : null),
                              child: cat == i
                                  ? Icon(Icons.check_rounded,
                                      color: Colors.white)
                                  : null,
                            ),
                          ),
                      ]),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: save,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                            colors: [kAccentLight, kAccent]),
                      ),
                      child: Center(
                          child: Text('ذخیره',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900))),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('لغو',
                          style: TextStyle(
                              color: kSub,
                              fontSize: 17,
                              fontWeight: FontWeight.w800))),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ───────────────────────── مالی ─────────────────────────
String money(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return fa('${n < 0 ? '−' : ''}$b');
}

class FinancePage extends StatelessWidget {
  FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        var bal = 0;
        for (final t in store.txs) {
          final a = _i(t['amt'], 0);
          bal += t['in'] == true ? a : -a;
        }
        final goal = prefs.getInt('goal') ?? 0;
        final p = goal > 0 ? (bal / goal).clamp(0.0, 1.0).toDouble() : 0.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            PageTitle('مالی',
                trailing: GIcon(Icons.add_rounded, () {
                  showModalBottomSheet(
                    context: c,
                    isScrollControlled: true,
                    backgroundColor: kSurface,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(30))),
                    builder: (_) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: AddTxSheet()),
                  );
                })),
            Glass(
              child: SizedBox(
                width: double.infinity,
                child: Column(children: [
                  Text('موجودی',
                      style: TextStyle(
                          color: kSub,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  Text(money(bal),
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: bal < 0 ? Color(0xFFE5484D) : kInk)),
                  Text('تومان',
                      style:
                          TextStyle(color: kSub, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            SizedBox(height: 14),
            Glass(
              onTap: () async {
                final v = await askText(c, 'هدف مالی (تومان)',
                    hint: 'مثلا ۵٬۰۰۰٬۰۰۰');
                if (v == null) return;
                final n =
                    int.tryParse(en(v.replaceAll(RegExp(r'[,٬\s]'), '')));
                if (n != null) {
                  prefs.setInt('goal', n);
                  store.poke();
                }
              },
              child: Row(children: [
                Ring(p,
                    size: 74,
                    stroke: 8,
                    child: Text('${fa((p * 100).round())}٪',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14))),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('هدف مالی',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 17)),
                        SizedBox(height: 4),
                        Text(
                            goal > 0
                                ? 'هدف: ${money(goal)} تومان'
                                : 'برای انتخاب هدف بزن',
                            style: TextStyle(
                                color: kSub, fontWeight: FontWeight.w700)),
                      ]),
                ),
              ]),
            ),
            SizedBox(height: 14),
            if (store.txs.isEmpty)
              Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                    child: Text('هنوز تراکنشی ثبت نکردی 💸',
                        style: TextStyle(
                            color: kSub,
                            fontWeight: FontWeight.w700,
                            fontSize: 16))),
              ),
            for (final t in store.txs.reversed)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Glass(
                  radius: 22,
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  onLongPress: () async {
                    if (await confirm(c, 'این تراکنش حذف بشه؟')) {
                      store.txs.removeWhere((e) => e['id'] == t['id']);
                      store.save();
                    }
                  },
                  child: Row(children: [
                    Icon(
                        t['in'] == true
                            ? Icons.arrow_circle_down_rounded
                            : Icons.arrow_circle_up_rounded,
                        color: t['in'] == true
                            ? Color(0xFF1FA67A)
                            : Color(0xFFE5484D)),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(t['title'] as String,
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16))),
                    Text('${t['in'] == true ? '+' : '−'}${money(_i(t['amt'], 0))}',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: t['in'] == true
                                ? Color(0xFF1FA67A)
                                : Color(0xFFE5484D))),
                  ]),
                ),
              ),
            if (store.txs.isNotEmpty)
              Center(
                  child: Text('برای حذف، روی تراکنش نگه دار',
                      style: TextStyle(color: kSub, fontSize: 11))),
          ],
        );
      },
    );
  }
}

class AddTxSheet extends StatefulWidget {
  AddTxSheet({super.key});
  @override
  State<AddTxSheet> createState() => _AddTxSheetState();
}

class _AddTxSheetState extends State<AddTxSheet> {
  final title = TextEditingController();
  final amt = TextEditingController();
  bool income = false;
  String? err;

  @override
  void dispose() {
    title.dispose();
    amt.dispose();
    super.dispose();
  }

  void submit() {
    final a = int.tryParse(en(amt.text.replaceAll(RegExp(r'[,٬\s]'), '')));
    if (title.text.trim().isEmpty || a == null || a <= 0) {
      setState(() => err = 'عنوان و مبلغ رو درست وارد کن');
      return;
    }
    store.txs.add({
      'id': newId(),
      'title': title.text.trim(),
      'amt': a,
      'in': income,
      'date': dk(DateTime.now()),
    });
    store.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 22, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('تراکنش جدید',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        SizedBox(height: 14),
        TextField(
          controller: title,
          decoration: InputDecoration(
              labelText: 'عنوان',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        SizedBox(height: 12),
        TextField(
          controller: amt,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: 'مبلغ (تومان)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        SizedBox(height: 12),
        Row(children: [
          for (final e in [(false, 'هزینه'), (true, 'درآمد')])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => income = e.$1),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: income == e.$1 ? kAccent : kAccent.withAlpha(0x14),
                  ),
                  child: Center(
                      child: Text(e.$2,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: income == e.$1 ? Colors.white : kInk))),
                ),
              ),
            ),
        ]),
        if (err != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(err!, style: TextStyle(color: Color(0xFFE5484D))),
          ),
        SizedBox(height: 14),
        GBtn('ذخیره', submit, primary: true),
      ]),
    );
  }
}

// ───────────────────────── صفحه آب‌وهوا ─────────────────────────
class WeatherPage extends StatelessWidget {
  WeatherPage({super.key});

  Color aqiColor(int a) {
    if (a <= 50) return Color(0xFF34C759);
    if (a <= 100) return Color(0xFFFFCC00);
    if (a <= 150) return Color(0xFFFF9500);
    if (a <= 200) return Color(0xFFFF3B30);
    return Color(0xFFAF52DE);
  }

  String aqiText(int a) {
    if (a <= 50) return 'پاک';
    if (a <= 100) return 'سالم (قابل قبول)';
    if (a <= 150) return 'ناسالم برای گروه‌های حساس';
    if (a <= 200) return 'ناسالم';
    return 'خیلی ناسالم';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wx,
      builder: (c, _) {
        final d = wx.d;
        final cu = wx.cur;
        final top = MediaQuery.of(c).padding.top;
        final day = cu == null || cu['is_day'] == 1;
        final c1 = day ? Color(0xFF2F6FD6) : Color(0xFF241766);
        final c2 = day ? Color(0xFF8EC5FF) : Color(0xFF7B5BD6);
        final t = cu == null ? 0 : (cu['temperature_2m'] as num).round();
        final code = cu == null ? 0 : (cu['weather_code'] as num).toInt();
        final now = DateTime.now();

        Widget hourly() {
          final times = ((d!['hourly'] as Map)['time'] as List).cast<String>();
          final temps = ((d['hourly'] as Map)['temperature_2m'] as List);
          final codes = ((d['hourly'] as Map)['weather_code'] as List);
          final curT = cu!['time'] as String;
          var i = times.indexWhere((x) => x.compareTo(curT) >= 0);
          if (i < 0) i = 0;
          final idx = [
            for (var k = 0; k < 5; k++)
              if (i + k * 3 < times.length) i + k * 3
          ];
          return Row(children: [
            for (final k in idx)
              Expanded(
                child: Column(children: [
                  Text(
                      wxEmoji((codes[k] as num).toInt(), () {
                        final h = int.parse(times[k].substring(11, 13));
                        return h >= 6 && h < 19;
                      }()),
                      style: TextStyle(fontSize: 34)),
                  SizedBox(height: 4),
                  Text(fa(times[k].substring(11, 16)),
                      style: TextStyle(
                          color: kSub,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                  Text('${fa((temps[k] as num).round())}°',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                ]),
              ),
          ]);
        }

        Widget detail(String e, String v, String l) => Expanded(
              child: Column(children: [
                Text(e, style: TextStyle(fontSize: 24)),
                SizedBox(height: 4),
                Text(v,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                Text(l,
                    style: TextStyle(
                        color: kSub,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ]),
            );

        return ListView(
          padding: EdgeInsets.only(bottom: 120),
          children: [
            Container(
              height: 380,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c1, c2]),
              ),
              child: Stack(children: [
                Positioned(
                  top: top + 14,
                  right: 22,
                  child: GestureDetector(
                    onTap: () => pickCity(c),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(children: [
                            Text(cityNames[store.cityIdx],
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900)),
                            SizedBox(width: 6),
                            Icon(Icons.location_on_rounded,
                                color: Colors.white),
                          ]),
                          Text('${wDay(now)}، ${jStr(now)}',
                              style: TextStyle(
                                  color: wh(.85),
                                  fontWeight: FontWeight.w700)),
                        ]),
                  ),
                ),
                Positioned(
                  top: top + 16,
                  left: 20,
                  child: wx.loading
                      ? SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : GestureDetector(
                          onTap: wx.load,
                          child: Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 30)),
                ),
                Positioned(
                  left: 24,
                  top: top + 90,
                  child: Text(cu == null ? '' : wxEmoji(code, day),
                      style: TextStyle(fontSize: 96)),
                ),
                Positioned(
                  right: 22,
                  top: top + 80,
                  child: Text(cu == null ? '—' : '${fa(t)}°',
                      style: TextStyle(
                          fontSize: 120,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
                Positioned(
                  right: 24,
                  bottom: 50,
                  child: Text(
                      cu == null
                          ? (wx.failed ? 'اینترنت وصل نیست' : 'در حال دریافت…')
                          : wxText(code),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            Container(
              color: c2,
              child: Container(
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: EdgeInsets.fromLTRB(16, 22, 16, 10),
                child: d == null || cu == null
                    ? Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                            child: Text('برای دیدن جزئیات به اینترنت وصل شو',
                                style: TextStyle(
                                    color: kSub, fontWeight: FontWeight.w700))))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                              child: Text('وضعیت امروز',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900))),
                          SizedBox(height: 14),
                          hourly(),
                          SizedBox(height: 18),
                          Glass(
                            child: Row(children: [
                              detail(
                                  '💧',
                                  '${fa((cu['relative_humidity_2m'] as num).round())}٪',
                                  'رطوبت'),
                              detail(
                                  '💨',
                                  fa((cu['wind_speed_10m'] as num).round()),
                                  'باد (km/h)'),
                              detail(
                                  '⏲️',
                                  fa((cu['surface_pressure'] as num).round()),
                                  'فشار'),
                            ]),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
                            child: Text('کیفیت هوا',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900)),
                          ),
                          Glass(
                            child: wx.aqi == null
                                ? Text('اطلاعاتی در دسترس نیست',
                                    style: TextStyle(color: kSub))
                                : Row(children: [
                                    Container(
                                      width: 78,
                                      height: 78,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: aqiColor(wx.aqi!).withAlpha(40),
                                        border: Border.all(
                                            color: aqiColor(wx.aqi!), width: 3),
                                      ),
                                      child: Center(
                                          child: Text(fa(wx.aqi!),
                                              style: TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w900,
                                                  color: aqiColor(wx.aqi!)))),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(aqiText(wx.aqi!),
                                                style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w900,
                                                    color: aqiColor(wx.aqi!))),
                                            SizedBox(height: 4),
                                            Text(
                                                'شاخص AQI شهر: ${cityNames[store.cityIdx]}',
                                                style: TextStyle(
                                                    color: kSub,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.5)),
                                          ]),
                                    ),
                                  ]),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
                            child: Text('پیش‌بینی روزانه',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900)),
                          ),
                          for (var i = 0;
                              i < ((d['daily'] as Map)['time'] as List).length;
                              i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Glass(
                                radius: 20,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                child: Row(children: [
                                  Expanded(
                                    child: Text(
                                        i == 0
                                            ? 'امروز'
                                            : wDay(DateTime.parse(
                                                ((d['daily'] as Map)['time']
                                                    as List)[i] as String)),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                  ),
                                  Text(
                                      wxEmoji(
                                          (((d['daily'] as Map)['weather_code']
                                                  as List)[i] as num)
                                              .toInt(),
                                          true),
                                      style: TextStyle(fontSize: 26)),
                                  SizedBox(width: 18),
                                  Text(
                                      '${fa((((d['daily'] as Map)['temperature_2m_max'] as List)[i] as num).round())}°  /  ${fa((((d['daily'] as Map)['temperature_2m_min'] as List)[i] as num).round())}°',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900)),
                                ]),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
