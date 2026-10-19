import 'dart:async';

import 'package:flutter/material.dart';

import 'core.dart';
import 'native.dart';

// ───────────────────────── انتخاب تاریخ شمسی ─────────────────────────
Future<DateTime?> pickJDate(BuildContext context,
    {DateTime? init, String title = 'تاریخ شمسی'}) {
  final j = toJalali(init ?? DateTime.now());
  final y = TextEditingController(text: fa(j[0]));
  final m = TextEditingController(text: fa(j[1]));
  final d = TextEditingController(text: fa(j[2]));
  Widget f(TextEditingController c, String l) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
              labelText: l,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
      );
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
      content: Row(children: [
        f(d, 'روز'),
        SizedBox(width: 8),
        f(m, 'ماه'),
        SizedBox(width: 8),
        f(y, 'سال'),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text('انصراف')),
        TextButton(
          onPressed: () {
            final yy = int.tryParse(en(y.text.trim()));
            final mm = int.tryParse(en(m.text.trim()));
            final dd = int.tryParse(en(d.text.trim()));
            if (yy == null ||
                mm == null ||
                dd == null ||
                mm < 1 ||
                mm > 12 ||
                dd < 1 ||
                dd > 31) {
              return;
            }
            Navigator.pop(ctx, jToG(yy, mm, dd));
          },
          child: Text('تایید'),
        ),
      ],
    ),
  );
}

Future<DateTime?> pickAlarmDateTime(BuildContext context,
    {DateTime? init}) async {
  final d = await pickJDate(context, init: init, title: 'تاریخ آلارم');
  if (d == null || !context.mounted) return null;
  final tm = await showTimePicker(
    context: context,
    helpText: 'ساعت آلارم',
    initialTime:
        TimeOfDay(hour: init?.hour ?? 8, minute: init?.minute ?? 0),
  );
  if (tm == null) return null;
  return DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
}

String timeStr(DateTime d) => fa('${two(d.hour)}:${two(d.minute)}');

// ───────────────────────── آلارم کارها ─────────────────────────
int alarmIdFor(Map<String, dynamic> t) =>
    (int.tryParse(t['id'].toString()) ?? 1) % 799999999 + 1;

DateTime? alarmAt(Map<String, dynamic> t) =>
    DateTime.tryParse((t['at'] as String?) ?? '');

void syncTaskAlarm(Map<String, dynamic> t) {
  final at = alarmAt(t);
  if (t['alarm'] == true &&
      t['done'] != true &&
      at != null &&
      at.isAfter(DateTime.now())) {
    Native.schedule(alarmIdFor(t), at, t['title'] as String);
  } else {
    Native.cancel(alarmIdFor(t));
  }
}

void cancelTaskAlarm(Map<String, dynamic> t) => Native.cancel(alarmIdFor(t));

void syncAllAlarms() {
  for (final t in store.tasks) {
    if (t['alarm'] == true) syncTaskAlarm(t);
  }
}

class AlarmsPage extends StatelessWidget {
  AlarmsPage({super.key});

  Future<void> addAlarm(BuildContext c) async {
    final free = store.tasks
        .where((t) => t['alarm'] != true && t['done'] != true)
        .toList();
    if (free.isEmpty) {
      toast(c, 'اول یه کار بساز (یا همه کارها آلارم دارن)');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: c,
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: EdgeInsets.all(14),
          shrinkWrap: true,
          children: [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('برای کدوم کار آلارم بذارم؟',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            for (final t in free)
              ListTile(
                title: Text(t['title'] as String,
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !c.mounted) return;
    final at = await pickAlarmDateTime(c);
    if (at == null) return;
    picked['alarm'] = true;
    picked['at'] = at.toIso8601String();
    store.save();
    syncTaskAlarm(picked);
    if (c.mounted && !at.isAfter(DateTime.now())) {
      toast(c, 'این زمان گذشته؛ یه زمان آینده انتخاب کن');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final list = store.tasks
            .where((t) => t['alarm'] == true && alarmAt(t) != null)
            .toList();
        list.sort((a, b) => alarmAt(a)!.compareTo(alarmAt(b)!));
        final now = DateTime.now();
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            PageTitle('آلارم کارها',
                trailing: GIcon(Icons.add_rounded, () => addAlarm(c))),
            Glass(
              onTap: () => Navigator.push(c,
                  MaterialPageRoute(builder: (_) => SubPage(child: PermissionsPage()))),
              child: Row(children: [
                iconBadge('shield', Color(0xFF1FA67A)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('بررسی دسترسی‌های آلارم',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('برای اینکه آلارم حتما به صدا دربیاد',
                            style: TextStyle(
                                color: Color(0xFF8A90A0),
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5)),
                      ]),
                ),
                Icon(Icons.chevron_left_rounded, color: kSub),
              ]),
            ),
            SizedBox(height: 14),
            if (list.isEmpty)
              Padding(
                padding: EdgeInsets.all(34),
                child: Column(children: [
                  ClarioMascot(size: 110, mood: 'sleep'),
                  SizedBox(height: 10),
                  Text('هنوز آلارمی نذاشتی',
                      style: TextStyle(
                          color: kSub,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('با + یکی از کارهات رو آلارم‌دار کن',
                      style: TextStyle(
                          color: kSub, fontWeight: FontWeight.w600)),
                ]),
              ),
            for (final t in list)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Glass(
                  radius: 24,
                  onTap: () async {
                    final at = await pickAlarmDateTime(c, init: alarmAt(t));
                    if (at == null) return;
                    t['at'] = at.toIso8601String();
                    t['alarm'] = true;
                    store.save();
                    syncTaskAlarm(t);
                  },
                  child: Row(children: [
                    iconBadge('alarm', alarmAt(t)!.isAfter(now) ? kAccent : kDanger,
                        size: 46),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(
                                '${jStr(alarmAt(t)!)}  •  ${timeStr(alarmAt(t)!)}',
                                style: TextStyle(
                                    color: alarmAt(t)!.isAfter(now)
                                        ? kSub
                                        : kDanger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5)),
                          ]),
                    ),
                    Switch(
                      value: t['done'] != true && alarmAt(t)!.isAfter(now),
                                      onChanged: (v) async {
                        if (v) {
                          var at = alarmAt(t)!;
                          if (!at.isAfter(DateTime.now())) {
                            final n = await pickAlarmDateTime(c, init: at);
                            if (n == null) return;
                            at = n;
                          }
                          t['at'] = at.toIso8601String();
                          t['alarm'] = true;
                          t['done'] = false;
                        } else {
                          t['alarm'] = false;
                          t['at'] = '';
                        }
                        store.save();
                        syncTaskAlarm(t);
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        t['alarm'] = false;
                        t['at'] = '';
                        store.save();
                        cancelTaskAlarm(t);
                      },
                      child: Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: AppIcon('trash', size: 22, color: kDanger)),
                    ),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// صفحه ساده با دکمه بازگشت (برای استفاده داخل همین فایل)
class SubPage extends StatelessWidget {
  SubPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: Backdrop()),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(children: [
                GIcon(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                Spacer(),
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      ]),
    );
  }
}

void openPage(BuildContext c, Widget w) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => SubPage(child: w)));

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

// ───────────────────────── دسترسی‌ها ─────────────────────────
class PermissionsPage extends StatefulWidget {
  PermissionsPage({super.key});
  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  Map<String, bool> st = {};
  bool loaded = false;
  int alarmCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final r = await Native.status();
    final cnt = await Native.alarmCount();
    if (mounted) {
      setState(() {
        alarmCount = cnt;
        st = r;
        loaded = true;
      });
    }
  }

  Widget row(String key, String icon, String title, String sub, Color col,
      VoidCallback act) {
    final on = st[key] == true;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        iconBadge(icon, col),
        SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15.5)),
                Text(sub,
                    style: TextStyle(
                        color: kSub,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ]),
        ),
        SizedBox(width: 8),
        on
            ? Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: Color(0xFF1FA67A).withAlpha(40),
                    borderRadius: BorderRadius.circular(14)),
                child: Text('فعال ✓',
                    style: TextStyle(
                        color: Color(0xFF1FA67A),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5)),
              )
            : GBtn('فعال‌سازی', act, primary: true),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        PageTitle('دسترسی‌ها'),
        if (!Native.ok)
          Glass(
              child: Text('این بخش فقط روی اندروید کار می‌کنه.',
                  style: TextStyle(color: kSub, fontWeight: FontWeight.w700)))
        else
          Glass(
            child: Column(children: [
              row('notif', 'bell', 'اعلان‌ها',
                  'لازم برای نمایش و پخش صدای آلارم', Color(0xFFFF9500),
                  () async {
                    await Native.requestNotif();
                    await Future.delayed(Duration(milliseconds: 1500));
                    await refresh();
                    if (st['notif'] != true) Native.open('notif');
                  }),
              Divider(height: 1),
              row('exact', 'alarm', 'زمان دقیق آلارم',
                  'آلارم سر ساعتِ دقیق به صدا دربیاد', Color(0xFFE5484D),
                  () => Native.open('exact')),
              Divider(height: 1),
              row('fullscreen', 'shield', 'نمایش روی صفحه قفل',
                  'وقتی گوشی قفله آلارم صفحه رو روشن کنه',
                  Color(0xFFAF52DE), () => Native.open('fullscreen')),
              Divider(height: 1),
              row('battery', 'battery', 'بدون محدودیت باتری',
                  'تا گوشی آلارم رو تو حالت خواب نبُره', Color(0xFF1FA67A),
                  () => Native.open('battery')),
              Divider(height: 1),
              row('autostart', 'shield', 'شروع خودکار (شیائومی و ...)',
                  'بدونش بعد از بستن اپ، آلارم به صدا درنمیاد',
                  Color(0xFF3B8EEA), () => Native.open('autostart')),
            ]),
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
                'آلارم‌های ثبت‌شده در سیستم الان: ${fa(alarmCount)}  (بعد از ساخت آلارم باید ۱ یا بیشتر باشه)',
                style: TextStyle(
                    color: kAccent, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        SizedBox(height: 14),
        Glass(
          onTap: () {
            Native.schedule(900009, DateTime.now().add(Duration(seconds: 10)),
                'تست آلارم Clario');
            toast(context, 'آلارم تستی تا ۱۰ ثانیه دیگه به صدا درمیاد ⏰');
          },
          child: Row(children: [
            iconBadge('alarm', kAccent),
            SizedBox(width: 14),
            Expanded(
              child: Text('تست آلارم (۱۰ ثانیه دیگه)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ]),
        ),
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.all(8),
          child: Text(
              'نکته‌ها: ۱) تو شیائومی «شروع خودکار» رو روشن کن و تو برنامه‌های اخیر روی کارت Clario نگه دار و قفلش کن. ۲) صدای «آلارم» گوشی (نه صدای زنگ) نباید صفر باشه. ۳) حالت «مزاحم نشوید» با گزینه‌ی سکوت کامل آلارم رو هم قطع می‌کنه.',
              style: TextStyle(
                  color: kSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1.7)),
        ),
        Center(
          child: GBtn('تنظیمات برنامه در گوشی', () => Native.open('app')),
        ),
      ],
    );
  }
}
