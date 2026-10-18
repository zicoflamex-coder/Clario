import 'dart:math';

import 'package:flutter/material.dart';

import 'alarm.dart';
import 'core.dart';
import 'layout.dart';
import 'pages.dart';
import 'settings.dart';
import 'tools.dart';

int _n(dynamic v, int d) => v is int ? v : d;

Widget roundBtn(String icon, VoidCallback f) => GestureDetector(
      onTap: f,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [wh(.9), wh(.35)]),
          border: Border.all(color: wh(.9), width: 1.2),
        ),
        child: Center(child: AppIcon(icon, size: 26, color: kAccent)),
      ),
    );

// ───────────────────────── جستجوی واقعی ─────────────────────────
String norm(String s) =>
    en(s).replaceAll('ي', 'ی').replaceAll('ك', 'ک').toLowerCase();

class SearchBox extends StatefulWidget {
  SearchBox({super.key});
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final ctl = TextEditingController();
  final focus = FocusNode();

  @override
  void dispose() {
    ctl.dispose();
    focus.dispose();
    super.dispose();
  }

  void clear() {
    ctl.clear();
    focus.unfocus();
    setState(() {});
  }

  void addTask(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    store.tasks.insert(0, {
      'id': newId(),
      'title': t,
      'note': '',
      'done': false,
      'prio': 1,
      'due': '',
      'check': [],
      'cat': 0,
      'alarm': false,
      'at': '',
    });
    store.save();
    clear();
    toast(context, 'به کارها اضافه شد ✅');
  }

  List<Map<String, dynamic>> results(String q) {
    final k = norm(q.trim());
    final out = <Map<String, dynamic>>[];
    bool m(Object? s) => s != null && norm(s.toString()).contains(k);
    for (final t in store.tasks) {
      final inCheck = ((t['check'] as List?) ?? []).any((e) => m((e as Map)['t']));
      if (m(t['title']) || m(t['note']) || inCheck) {
        out.add({'k': 'کار', 'i': 'tasks', 'title': t['title'], 'o': t});
      }
    }
    for (final n in store.notes) {
      if (m(n['title']) || m(n['body'])) {
        out.add({
          'k': 'یادداشت',
          'i': 'note',
          'title': ((n['title'] as String).trim().isEmpty
              ? (n['body'] as String)
              : n['title']),
          'o': n
        });
      }
    }
    for (final e in store.events) {
      if (m(e['title'])) {
        out.add({'k': 'رویداد', 'i': 'event', 'title': e['title'], 'o': e});
      }
    }
    for (final h in store.habits) {
      if (m(h['name'])) {
        out.add({'k': 'عادت', 'i': 'habit', 'title': h['name'], 'o': h});
      }
    }
    for (final t in store.txs) {
      if (m(t['title'])) {
        out.add({'k': 'مالی', 'i': 'finance', 'title': t['title'], 'o': t});
      }
    }
    return out;
  }

  void open(Map<String, dynamic> r) {
    final o = r['o'] as Map<String, dynamic>;
    switch (r['k']) {
      case 'کار':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => TaskForm(task: o)));
        break;
      case 'یادداشت':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => NoteEditor(note: o)));
        break;
      case 'رویداد':
        openPage(context, EventsPage());
        break;
      case 'عادت':
        openPage(context, HabitsPage());
        break;
      default:
        openPage(context, FinancePage());
    }
    clear();
  }

  @override
  Widget build(BuildContext context) {
    final q = ctl.text;
    final res = q.trim().isEmpty ? <Map<String, dynamic>>[] : results(q);
    return Column(children: [
      Glass(
        radius: 30,
        padding: EdgeInsets.fromLTRB(18, 0, 10, 0),
        child: Row(children: [
          AppIcon('search', size: 24, color: kAccent),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctl,
              focusNode: focus,
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) {
                if (res.isEmpty) addTask(v);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                  hintText: 'جستجو در کارها، یادداشت‌ها و...',
                  border: InputBorder.none),
            ),
          ),
          if (q.isNotEmpty)
            GestureDetector(
                onTap: clear,
                child: Padding(
                    padding: EdgeInsets.all(10),
                    child: AppIcon('close', size: 20, color: kSub))),
        ]),
      ),
      if (q.trim().isNotEmpty) ...[
        SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 340),
          child: Glass(
            radius: 24,
            padding: EdgeInsets.all(6),
            child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
              if (res.isEmpty)
                Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('نتیجه‌ای پیدا نشد',
                      style: TextStyle(
                          color: kSub, fontWeight: FontWeight.w700)),
                ),
              for (final r in res.take(8))
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => open(r),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(children: [
                      AppIcon(r['i'] as String, size: 24, color: kAccent),
                      SizedBox(width: 12),
                      Expanded(
                          child: Text(r['title'].toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15))),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: kAccent.withAlpha(28),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(r['k'] as String,
                            style: TextStyle(
                                color: kAccent,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5)),
                      ),
                    ]),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => addTask(q),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(children: [
                    AppIcon('plus', size: 24, color: kAccent),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('افزودن «${q.trim()}» به کارها',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: kAccent))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }
}

// ───────────────────────── محتوای ویجت‌ها ─────────────────────────
Widget wTitle(String icon, String text) => Row(children: [
      AppIcon(icon, size: 20, color: kAccent),
      SizedBox(width: 7),
      Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 13.5, color: kSub))),
    ]);

void toggleTask(Map<String, dynamic> t) {
  t['done'] = !(t['done'] == true);
  store.save();
  syncTaskAlarm(t);
}

void toggleHabitToday(Map<String, dynamic> h) {
  final today = dk(DateTime.now());
  final days = List<String>.from(h['days'] as List);
  if (days.contains(today)) {
    days.remove(today);
  } else {
    days.add(today);
  }
  h['days'] = days;
  store.save();
}

Widget smallCheck(bool on, VoidCallback f) => GestureDetector(
      onTap: f,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? kAccent : null,
          border: Border.all(color: on ? kAccent : kSub, width: 2),
        ),
        child: on
            ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );

class WeatherTile extends StatelessWidget {
  WeatherTile({super.key, required this.s});
  final int s;

  List<List<String>> hourly() {
    final d = wx.d;
    if (d == null) return [];
    try {
      final times = ((d['hourly'] as Map)['time'] as List).cast<String>();
      final temps = (d['hourly'] as Map)['temperature_2m'] as List;
      final codes = (d['hourly'] as Map)['weather_code'] as List;
      final cur = (d['current'] as Map)['time'] as String;
      var i = times.indexWhere((x) => x.compareTo(cur) >= 0);
      if (i < 0) i = 0;
      final out = <List<String>>[];
      for (var k = 0; k < 5; k++) {
        final j = i + k * 3;
        if (j >= times.length) break;
        final h = int.parse(times[j].substring(11, 13));
        out.add([
          wxEmoji((codes[j] as num).toInt(), h >= 6 && h < 19),
          '${fa((temps[j] as num).round())}°',
          fa(times[j].substring(11, 16)),
        ]);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wx,
      builder: (c, _) {
        final cu = wx.cur;
        final t = cu == null ? 0 : (cu['temperature_2m'] as num).round();
        final code = cu == null ? 0 : (cu['weather_code'] as num).toInt();
        final day = cu == null || cu['is_day'] == 1;
        final emoji = cu == null ? '🌡️' : wxEmoji(code, day);
        final desc = cu == null
            ? (wx.failed ? 'اینترنت وصل نیست' : 'در حال دریافت…')
            : wxText(code);
        final city = Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(cityNames[store.cityIdx],
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
            SizedBox(width: 4),
            Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
          ]),
        );
        Widget body;
        if (s == 0) {
          body = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: 44)),
                Text(cu == null ? '—' : '${fa(t)}°',
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text(desc,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                city,
              ]);
        } else {
          final top = Row(children: [
            Text(emoji, style: TextStyle(fontSize: s == 2 ? 78 : 64)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    city,
                    Text(cu == null ? '—' : '${fa(t)}°',
                        style: TextStyle(
                            fontSize: s == 2 ? 66 : 54,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    Text(desc,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    if (cu != null && s == 1)
                      Text(wxTip(t),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(215))),
                  ]),
            ),
          ]);
          if (s == 1) {
            body = Center(child: top);
          } else {
            final hr = hourly();
            body = Column(children: [
              top,
              Spacer(),
              if (cu != null)
                Text(wxTip(t),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withAlpha(215))),
              SizedBox(height: 10),
              Row(children: [
                for (final h in hr)
                  Expanded(
                    child: Column(children: [
                      Text(h[2],
                          style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                      Text(h[0], style: TextStyle(fontSize: 26)),
                      Text(h[1],
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900)),
                    ]),
                  ),
              ]),
            ]);
          }
        }
        return GestureDetector(
          onTap: () => tabIdx.value = 3,
          onLongPress: null,
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(kAccent, Colors.black, .5)!,
                  Color.lerp(kAccent, Colors.black, .12)!
                ],
              ),
              boxShadow: [
                BoxShadow(
                    color: kAccent.withAlpha(60),
                    blurRadius: 22,
                    offset: Offset(0, 10))
              ],
            ),
            child: body,
          ),
        );
      },
    );
  }
}

Widget dateTile(int s) {
  final n = DateTime.now();
  final j = toJalali(n);
  final fri = n.weekday == 5;
  final col = fri ? kDanger : kInk;
  if (s == 0) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(wDay(n),
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: fri ? col : kSub)),
      Text(fa(j[2]),
          style: TextStyle(
              fontSize: 62, height: 1.1, fontWeight: FontWeight.w900, color: col)),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: col.withAlpha(25), borderRadius: BorderRadius.circular(14)),
        child: Text('${jMonths[j[1] - 1]} ${fa(j[0])}',
            style: TextStyle(fontWeight: FontWeight.w800, color: col)),
      ),
    ]);
  }
  final head = Row(children: [
    Text(fa(j[2]),
        style: TextStyle(
            fontSize: 58, height: 1.1, fontWeight: FontWeight.w900, color: col)),
    SizedBox(width: 16),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(wDay(n),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: col)),
        Text('${jMonths[j[1] - 1]} ${fa(j[0])}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text('${n.year}/${two(n.month)}/${two(n.day)}',
            style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
      ]),
    ),
  ]);
  if (s == 1) return Center(child: head);
  final marks = <String>{...store.events.map((e) => e['date'] as String)};
  return Column(children: [
    head,
    SizedBox(height: 8),
    MonthGrid(jy: j[0], jm: j[1], marks: marks, cell: 31),
  ]);
}

Widget quoteTile(int s) {
  final fs = s == 0 ? 14.5 : (s == 1 ? 17.0 : 24.0);
  return Column(children: [
    wTitle('sparkle', 'جمله امروز'),
    Expanded(
      child: Center(
        child: Text(quotes[quoteIdx % quotes.length],
            textAlign: TextAlign.center,
            maxLines: 7,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: fs, height: 1.65, fontWeight: FontWeight.w800)),
      ),
    ),
    GestureDetector(
      onTap: nextQuote,
      child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.autorenew_rounded, color: kSub)),
    ),
  ]);
}

Widget tasksTile(int s) {
  final total = store.tasks.length;
  final done = store.tasks.where((e) => e['done'] == true).length;
  final p = total == 0 ? 0.0 : done / total;
  final pending = store.tasks.where((e) => e['done'] != true).toList();
  final ring = Ring(p,
      size: s == 0 ? 76 : 70,
      stroke: 9,
      child: Text('${fa((p * 100).round())}٪',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)));
  if (s == 0) {
    return Column(children: [
      wTitle('tasks', 'کارهای من'),
      Spacer(),
      ring,
      Spacer(),
      Text('${fa(done)} از ${fa(total)} انجام شد',
          style: TextStyle(
              color: kSub, fontWeight: FontWeight.w700, fontSize: 12)),
    ]);
  }
  final info = Expanded(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${fa(pending.length)} کار باقی مونده',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          if (pending.isNotEmpty)
            Text('بعدی: ${pending.first['title']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
          if (pending.isEmpty)
            Text('همه‌چیز تموم شده 🎉',
                style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
        ]),
  );
  if (s == 1) {
    return Row(children: [ring, SizedBox(width: 16), info]);
  }
  return Column(children: [
    Row(children: [ring, SizedBox(width: 16), info]),
    SizedBox(height: 10),
    Expanded(
      child: ListView(padding: EdgeInsets.zero, children: [
        for (final t in pending.take(6))
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              smallCheck(false, () => toggleTask(t)),
              SizedBox(width: 12),
              Expanded(
                  child: Text(t['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15))),
            ]),
          ),
      ]),
    ),
  ]);
}

Widget waterTile(int s) {
  final day = dk(DateTime.now());
  final w = store.water(day);
  final ring = Ring(w / 8,
      size: s == 0 ? 76 : (s == 1 ? 84 : 130),
      stroke: s == 2 ? 12 : 9,
      child: Text('💧 ${fa(w)}',
          style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: s == 2 ? 22 : 15)));
  final btns = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    GestureDetector(
        onTap: () => store.setWater(day, w - 1),
        child: AppIcon('minus', size: 30, color: kSub)),
    Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('از ${fa(8)} لیوان',
            style: TextStyle(
                color: kSub, fontWeight: FontWeight.w700, fontSize: 12))),
    GestureDetector(
        onTap: () => store.setWater(day, w + 1),
        child: AppIcon('plus', size: 30, color: kAccent)),
  ]);
  if (s == 0) {
    return Column(children: [
      wTitle('drop', 'آب امروز'),
      Spacer(),
      ring,
      Spacer(),
      btns,
    ]);
  }
  if (s == 1) {
    return Row(children: [
      ring,
      SizedBox(width: 16),
      Expanded(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            wTitle('drop', 'آب امروز'),
            SizedBox(height: 10),
            btns,
          ])),
    ]);
  }
  return Column(children: [
    wTitle('drop', 'آب امروز'),
    Spacer(),
    ring,
    SizedBox(height: 14),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < 8; i++)
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: AppIcon('drop',
                size: 24, color: i < w ? kAccent : kSub.withAlpha(110))),
    ]),
    Spacer(),
    btns,
  ]);
}

Widget eventTile(int s) {
  final today = dayOnly(DateTime.now());
  final up = <Map<String, dynamic>>[];
  for (final e in store.events) {
    if (!dayOnly(DateTime.parse(e['date'] as String)).isBefore(today)) up.add(e);
  }
  up.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  int left(Map<String, dynamic> e) =>
      dayOnly(DateTime.parse(e['date'] as String)).difference(today).inDays;
  if (up.isEmpty) {
    return Column(children: [
      wTitle('event', 'مناسبت بعدی'),
      Spacer(),
      Text('🎉', style: TextStyle(fontSize: 40)),
      SizedBox(height: 6),
      Text('مناسبتی ثبت نکردی',
          style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
      Spacer(),
    ]);
  }
  final e = up.first;
  if (s == 2) {
    return Column(children: [
      wTitle('event', 'مناسبت‌های بعدی'),
      SizedBox(height: 8),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          for (final x in up.take(6))
            Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Text(x['emoji'] as String? ?? '📅',
                    style: TextStyle(fontSize: 28)),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(x['title'] as String,
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                      Text(jStr(DateTime.parse(x['date'] as String)),
                          style: TextStyle(
                              color: kSub,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ])),
                Text(left(x) == 0 ? 'امروز' : '${fa(left(x))} روز',
                    style: TextStyle(
                        color: kAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ]),
            ),
        ]),
      ),
    ]);
  }
  if (s == 1) {
    return Row(children: [
      Text(e['emoji'] as String? ?? '📅', style: TextStyle(fontSize: 46)),
      SizedBox(width: 14),
      Expanded(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(e['title'] as String,
                style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(jStr(DateTime.parse(e['date'] as String)),
                style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
          ])),
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(left(e) == 0 ? 'امروز' : fa(left(e)),
            style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w900, color: kAccent)),
        if (left(e) != 0)
          Text('روز دیگر',
              style: TextStyle(
                  color: kSub, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    ]);
  }
  return Column(children: [
    wTitle('event', 'مناسبت بعدی'),
    Spacer(),
    Text(e['emoji'] as String? ?? '📅', style: TextStyle(fontSize: 38)),
    Text(e['title'] as String,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
    Text(left(e) == 0 ? 'امروز' : '${fa(left(e))} روز دیگر',
        style: TextStyle(color: kAccent, fontWeight: FontWeight.w900)),
    Spacer(),
  ]);
}

Widget habitsTile(int s) {
  final today = dk(DateTime.now());
  final hs = store.habits;
  final done = hs.where((h) => (h['days'] as List).contains(today)).length;
  if (hs.isEmpty) {
    return Column(children: [
      wTitle('habit', 'عادت‌های روزانه'),
      Spacer(),
      Text('عادتی نساختی؛ از ابزارها > عادت‌ساز',
          textAlign: TextAlign.center,
          style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
      Spacer(),
    ]);
  }
  if (s == 0) {
    return Column(children: [
      wTitle('habit', 'عادت‌ها'),
      Spacer(),
      Ring(done / hs.length,
          size: 76,
          stroke: 9,
          child: Text('${fa(done)}/${fa(hs.length)}',
              style: TextStyle(fontWeight: FontWeight.w900))),
      Spacer(),
      Text('امروز انجام شد',
          style: TextStyle(
              color: kSub, fontWeight: FontWeight.w700, fontSize: 12)),
    ]);
  }
  final cnt = s == 1 ? 3 : 7;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    wTitle('habit', 'عادت‌های روزانه  •  ${fa(done)} از ${fa(hs.length)}'),
    SizedBox(height: 6),
    Expanded(
      child: ListView(padding: EdgeInsets.zero, children: [
        for (final h in hs.take(cnt))
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              smallCheck((h['days'] as List).contains(today),
                  () => toggleHabitToday(h)),
              SizedBox(width: 12),
              Expanded(
                  child: Text(h['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15))),
              Text('🔥 ${fa(habitStreak(h['days'] as List))}',
                  style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    ),
  ]);
}

Widget financeTile(int s) {
  var bal = 0;
  for (final t in store.txs) {
    final a = _n(t['amt'], 0);
    bal += t['in'] == true ? a : -a;
  }
  final goal = prefs.getInt('goal') ?? 0;
  final p = goal > 0 ? (bal / goal).clamp(0.0, 1.0).toDouble() : 0.0;
  final bl = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('موجودی',
            style: TextStyle(
                color: kSub, fontWeight: FontWeight.w800, fontSize: 13)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(money(bal),
              style: TextStyle(
                  fontSize: s == 0 ? 24 : 30,
                  fontWeight: FontWeight.w900,
                  color: bal < 0 ? kDanger : kInk)),
        ),
        Text('تومان',
            style: TextStyle(
                color: kSub, fontWeight: FontWeight.w700, fontSize: 12)),
      ]);
  if (s == 0) {
    return Column(children: [
      wTitle('finance', 'مالی'),
      Spacer(),
      bl,
      Spacer(),
    ]);
  }
  final ring = Ring(p,
      size: 74,
      stroke: 8,
      child: Text(goal > 0 ? '${fa((p * 100).round())}٪' : '—',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)));
  if (s == 1) {
    return Row(children: [Expanded(child: bl), ring]);
  }
  return Column(children: [
    Row(children: [Expanded(child: bl), ring]),
    SizedBox(height: 10),
    Expanded(
      child: ListView(padding: EdgeInsets.zero, children: [
        for (final t in store.txs.reversed.take(5))
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(
                  t['in'] == true
                      ? Icons.arrow_circle_down_rounded
                      : Icons.arrow_circle_up_rounded,
                  color: t['in'] == true ? Color(0xFF1FA67A) : kDanger,
                  size: 22),
              SizedBox(width: 10),
              Expanded(
                  child: Text(t['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800))),
              Text(money(_n(t['amt'], 0)),
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ]),
          ),
      ]),
    ),
  ]);
}

Widget pomoTile(BuildContext c, int s) {
  return ListenableBuilder(
    listenable: pomo,
    builder: (c, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openPage(c, PomodoroPage()),
      child: Column(children: [
        wTitle('pomodoro', 'پومودورو'),
        Spacer(),
        Text(fmtMs((pomo.remainMs / 1000).ceil() * 1000),
            style: TextStyle(
                fontSize: s == 0 ? 36 : 48, fontWeight: FontWeight.w900)),
        Text(PomoCtl.names[pomo.mode],
            style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
        Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          circleBtn(pomo.running ? 'pause' : 'play',
              pomo.running ? pomo.pause : pomo.start,
              primary: true, size: 48),
          if (s > 0) ...[
            SizedBox(width: 16),
            Text('امروز: ${fa(pomo.doneToday)} جلسه',
                style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
          ],
        ]),
      ]),
    ),
  );
}


Widget wdetailTile(int s) {
  final cu = wx.cur;
  if (cu == null) {
    return Column(children: [
      wTitle('weather', 'جزئیات هوا'),
      Expanded(
          child: Center(
              child: Text(wx.failed ? 'اینترنت وصل نیست' : 'در حال دریافت…',
                  style: TextStyle(color: kSub, fontWeight: FontWeight.w700)))),
    ]);
  }
  final hum = fa((cu['relative_humidity_2m'] as num).round());
  final wind = fa((cu['wind_speed_10m'] as num).round());
  final pr = fa((cu['surface_pressure'] as num).round());
  Widget big(String e, String v, String l) => Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(e, style: TextStyle(fontSize: 30)),
          Text(v, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
          Text(l,
              style: TextStyle(
                  color: kSub, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ]),
      );
  Widget line(String e, String v, String l) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(e, style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text(l,
              style: TextStyle(
                  color: kSub, fontWeight: FontWeight.w700, fontSize: 12.5)),
          Spacer(),
          Text(v, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      );
  Widget body;
  if (s == 0) {
    body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      line('💧', '$hum٪', 'رطوبت'),
      line('💨', wind, 'باد'),
      line('⏲️', pr, 'فشار'),
    ]);
  } else {
    body = Column(children: [
      Expanded(
          child: Row(children: [
        big('💧', '$hum٪', 'رطوبت'),
        big('💨', wind, 'باد (km/h)'),
        big('⏲️', pr, 'فشار'),
      ])),
      if (s == 2 && wx.aqi != null)
        Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text('شاخص کیفیت هوا: ${fa(wx.aqi!)}',
              style: TextStyle(color: kAccent, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
    ]);
  }
  return Column(children: [wTitle('weather', 'جزئیات هوا'), Expanded(child: body)]);
}

Widget calminiTile(int s) {
  final j = toJalali(DateTime.now());
  final marks = <String>{
    ...store.events.map((e) => e['date'] as String),
    ...store.tasks.map((t) => (t['due'] as String?) ?? '').where((e) => e.isNotEmpty),
  };
  final body = Column(mainAxisSize: MainAxisSize.min, children: [
    Text('${jMonths[j[1] - 1]} ${fa(j[0])}',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: s == 2 ? 20 : 14)),
    SizedBox(height: 4),
    MonthGrid(jy: j[0], jm: j[1], marks: marks, cell: s == 2 ? 38 : 20),
  ]);
  if (s == 2) return Center(child: body);
  return FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(width: s == 0 ? 150 : 300, child: body),
  );
}

Widget worldTile(int s) {
  final up = upcomingWorldDays(s == 2 ? 7 : 1);
  String lt(int l) => l == 0 ? 'امروز' : '${fa(l)} روز دیگر';
  if (s == 2) {
    return Column(children: [
      wTitle('globe', 'مناسبت‌های جهانی'),
      SizedBox(height: 8),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          for (final x in up)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                    child: Text(x['name'] as String,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Text(lt(x['left'] as int),
                    style: TextStyle(color: kAccent, fontWeight: FontWeight.w900)),
              ]),
            ),
        ]),
      ),
    ]);
  }
  final x = up.first;
  if (s == 1) {
    return Row(children: [
      iconBadge('globe', kAccent, size: 58),
      SizedBox(width: 14),
      Expanded(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(x['name'] as String,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(jStr(x['date'] as DateTime),
                style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
          ])),
      Text(lt(x['left'] as int),
          style: TextStyle(color: kAccent, fontWeight: FontWeight.w900, fontSize: 17)),
    ]);
  }
  return Column(children: [
    wTitle('globe', 'مناسبت'),
    Spacer(),
    Text(x['name'] as String,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.5)),
    SizedBox(height: 6),
    Text(lt(x['left'] as int),
        style: TextStyle(color: kAccent, fontWeight: FontWeight.w900)),
    Spacer(),
  ]);
}

// ───────────────────────── انتخاب ویجت با پیش‌نمایش واقعی ─────────────────────────
void showWidgetPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: FlatGlass(
        child: StatefulBuilder(builder: (ctx, setS) {
          final L = loadLayout();
          int sizeOf(String id) {
            final k = L.indexWhere((e) => e['id'] == id);
            return k < 0 ? -1 : _n(L[k]['s'], 0);
          }

          Widget item(String id, int s) {
            final d = widgetDefs.firstWhere((e) => e.$1 == id);
            final on = sizeOf(id) == s;
            final pw = s == 0 ? 170.0 : 350.0;
            final ph = s == 2 ? 360.0 : 176.0;
            return GestureDetector(
              onTap: () {
                final l = loadLayout();
                final k = l.indexWhere((e) => e['id'] == id);
                if (k >= 0 && _n(l[k]['s'], 0) == s) {
                  l.removeAt(k);
                } else if (k >= 0) {
                  l[k]['s'] = s;
                } else {
                  l.add({'id': id, 's': s});
                }
                saveLayout(l);
                setS(() {});
              },
              child: Column(children: [
                Stack(children: [
                  AspectRatio(
                    aspectRatio: pw / ph,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: pw,
                        height: ph,
                        child: IgnorePointer(child: tileContent(ctx, id, s)),
                      ),
                    ),
                  ),
                  if (on)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent),
                        child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                ]),
                SizedBox(height: 6),
                Text(d.$2,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                Text(d.$3,
                    style: TextStyle(
                        color: kSub, fontWeight: FontWeight.w600, fontSize: 12)),
              ]),
            );
          }

          Widget sec(String t) => Padding(
                padding: EdgeInsets.fromLTRB(4, 22, 4, 12),
                child: Row(children: [
                  Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                          color: kAccent, borderRadius: BorderRadius.circular(3))),
                  SizedBox(width: 10),
                  Text(t, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ]),
              );

          final ids = widgetDefs.map((e) => e.$1).toList();
          final bigIds = ['weather', 'calmini', 'tasks', 'habits', 'finance', 'event', 'world'];
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .92),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                Center(
                    child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                            color: kSub.withAlpha(90),
                            borderRadius: BorderRadius.circular(3)))),
                SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Column(children: [
                      Text('انتخاب ویجت',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('پیش‌نمایش واقعی ویجت‌ها • بزن تا اضافه/حذف بشه',
                          style: TextStyle(
                              color: kSub, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ]),
                  ),
                ]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GBtn('بازنشانی', () {
                    resetLayout();
                    setS(() {});
                  }),
                ),
                Divider(),
                sec('ویجت‌های مربعی (۱×۱)'),
                for (var i = 0; i < ids.length; i += 2)
                  Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: item(ids[i], 0)),
                      SizedBox(width: 14),
                      Expanded(child: i + 1 < ids.length ? item(ids[i + 1], 0) : SizedBox()),
                    ]),
                  ),
                sec('ویجت‌های عرضی (۱×۲)'),
                for (final id in ids)
                  Padding(padding: EdgeInsets.only(bottom: 18), child: item(id, 1)),
                sec('ویجت‌های بزرگ (۲×۲)'),
                for (final id in bigIds)
                  Padding(padding: EdgeInsets.only(bottom: 18), child: item(id, 2)),
              ],
            ),
          );
        }),
      ),
    ),
  );
}

Widget tileContent(BuildContext c, String id, int s) {
  if (id == 'weather') return WeatherTile(s: s);
  if (id == 'pomo') {
    return Glass(
        radius: 28,
        padding: EdgeInsets.all(14),
        child: pomoTile(c, s));
  }
  return ListenableBuilder(
    listenable: Listenable.merge([store, wx]),
    builder: (c, _) {
      Widget w;
      switch (id) {
        case 'date':
          w = dateTile(s);
          break;
        case 'quote':
          w = quoteTile(s);
          break;
        case 'tasks':
          w = tasksTile(s);
          break;
        case 'water':
          w = waterTile(s);
          break;
        case 'event':
          w = eventTile(s);
          break;
        case 'habits':
          w = habitsTile(s);
          break;
        case 'wdetail':
          w = wdetailTile(s);
          break;
        case 'calmini':
          w = calminiTile(s);
          break;
        case 'world':
          w = worldTile(s);
          break;
        default:
          w = financeTile(s);
      }
      return Glass(radius: 28, padding: EdgeInsets.all(14), child: w);
    },
  );
}

// ───────────────────────── صفحه امروز ─────────────────────────
class TodayPage extends StatefulWidget {
  TodayPage({super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final sc = ScrollController();
  bool editing = false;

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  void moveBefore(String dragId, String? targetId) {
    final l = loadLayout();
    final i = l.indexWhere((e) => e['id'] == dragId);
    if (i < 0) return;
    final item = l.removeAt(i);
    if (targetId == null) {
      l.add(item);
    } else {
      final t = l.indexWhere((e) => e['id'] == targetId);
      l.insert(t < 0 ? l.length : t, item);
    }
    saveLayout(l);
  }

  void autoScroll(DragUpdateDetails d) {
    if (!sc.hasClients) return;
    final y = d.globalPosition.dy;
    final h = MediaQuery.of(context).size.height;
    if (y < 180) {
      sc.jumpTo(max(0.0, sc.offset - 16));
    } else if (y > h - 200) {
      sc.jumpTo(min(sc.position.maxScrollExtent, sc.offset + 16));
    }
  }

  Widget miniBtn(String icon, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kSurface.withAlpha(235),
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
          ),
          child: Center(child: AppIcon(icon, size: 18, color: kAccent)),
        ),
      );

  Widget tile(Map<String, dynamic> w) {
    final id = w['id'] as String;
    final s = _n(w['s'], 0).clamp(0, 2).toInt();
    final h = s == 2 ? 360.0 : 176.0;
    return LayoutBuilder(builder: (c, cons) {
      final content = SizedBox(height: h, child: tileContent(context, id, s));
      final shown = Stack(children: [
        content,
        if (editing)
          Positioned(
            top: 8,
            left: 8,
            child: miniBtn('resize', () {
              final l = loadLayout();
              final k = l.indexWhere((e) => e['id'] == id);
              if (k >= 0) l[k]['s'] = (s + 1) % 3;
              saveLayout(l);
            }),
          ),
        if (editing)
          Positioned(
            top: 8,
            right: 8,
            child: miniBtn('close', () {
              final l = loadLayout();
              l.removeWhere((e) => e['id'] == id);
              saveLayout(l);
            }),
          ),
      ]);
      return DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != id,
        onAcceptWithDetails: (d) => moveBefore(d.data, id),
        builder: (c, cand, rej) => LongPressDraggable<String>(
          data: id,
          onDragStarted: () => setState(() => editing = true),
          onDragUpdate: autoScroll,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
                width: cons.maxWidth,
                height: h,
                child: Opacity(opacity: .92, child: content)),
          ),
          childWhenDragging: Opacity(opacity: .22, child: shown),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: cand.isNotEmpty
                  ? Border.all(color: kAccent, width: 3)
                  : Border.all(color: Colors.transparent, width: 3),
            ),
            child: shown,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ListenableBuilder(
      listenable: Listenable.merge([store, smartSearch]),
      builder: (c, _) {
        final L = loadLayout();
        final rows = <Widget>[];
        var i = 0;
        while (i < L.length) {
          final a = L[i];
          final small = _n(a['s'], 0) == 0;
          if (small && i + 1 < L.length && _n(L[i + 1]['s'], 0) == 0) {
            rows.add(Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Expanded(child: tile(a)),
                SizedBox(width: 14),
                Expanded(child: tile(L[i + 1])),
              ]),
            ));
            i += 2;
          } else if (small) {
            rows.add(Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Expanded(child: tile(a)),
                SizedBox(width: 14),
                Expanded(child: SizedBox()),
              ]),
            ));
            i++;
          } else {
            rows.add(Padding(
                padding: EdgeInsets.only(bottom: 14), child: tile(a)));
            i++;
          }
        }
        final now = DateTime.now();
        return Stack(children: [
          ListView(
            controller: sc,
            padding: EdgeInsets.fromLTRB(16, top + (smartSearch.value ? 150 : 92), 16, 140),
            children: [
              if (editing)
                Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Glass(
                    radius: 22,
                    padding: EdgeInsets.fromLTRB(16, 10, 10, 10),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                            'حالت ویرایش: ویجت‌ها رو بکش و جابه‌جا کن. با دکمه اندازه، کوچک/عریض/بزرگ می‌شن.',
                            style: TextStyle(
                                color: kSub,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                height: 1.6)),
                      ),
                      SizedBox(width: 8),
                      GBtn('تمام', () => setState(() => editing = false),
                          primary: true),
                    ]),
                  ),
                ),
              if (L.isEmpty)
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(children: [
                    ClarioMascot(size: 110, mood: 'wow'),
                    SizedBox(height: 12),
                    Text('ویجتی نداری؛ با دکمه بالا اضافه کن',
                        style: TextStyle(
                            color: kSub,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ]),
                ),
              ...rows,
              if (editing)
                DragTarget<String>(
                  onWillAcceptWithDetails: (d) => true,
                  onAcceptWithDetails: (d) => moveBefore(d.data, null),
                  builder: (c, cand, rej) => Container(
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: cand.isNotEmpty ? kAccent : kSub.withAlpha(120),
                          width: 2),
                    ),
                    child: Center(
                        child: Text('اینجا رها کن تا بره آخر لیست',
                            style: TextStyle(
                                color: kSub, fontWeight: FontWeight.w800))),
                  ),
                ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
              child: Column(children: [
                Glass(
                  radius: 36,
                  padding: EdgeInsets.all(7),
                  child: Row(children: [
                    roundBtn('settings',
                        () => openPage(context, SettingsPage())),
                    Expanded(
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          ClarioLogo(size: 26),
                          SizedBox(width: 7),
                          Text('کلاریو',
                              style: TextStyle(
                                  fontSize: 24,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                  color: kAccent)),
                        ]),
                        Text('${wDay(now)}، ${jStr(now)}',
                            style: TextStyle(
                                color: kSub,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ]),
                    ),
                    roundBtn('plus', () => showWidgetPicker(context)),
                  ]),
                ),
                if (smartSearch.value) ...[
                  SizedBox(height: 10),
                  SearchBox(),
                ],
              ]),
            ),
          ),
        ]);
      },
    );
  }
}
