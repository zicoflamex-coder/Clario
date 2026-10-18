import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alarm.dart';
import 'core.dart';
import 'home.dart';
import 'layout.dart';
import 'native.dart';
import 'pages.dart';

Future<bool> applyBackup(String text) async {
  try {
    final m = jsonDecode(text) as Map<String, dynamic>;
    for (final e in m.entries) {
      final v = e.value;
      if (v is int) {
        await prefs.setInt(e.key, v);
      } else if (v is double) {
        await prefs.setDouble(e.key, v);
      } else if (v is bool) {
        await prefs.setBool(e.key, v);
      } else if (v is String) {
        await prefs.setString(e.key, v);
      } else if (v is List) {
        await prefs.setStringList(e.key, v.map((x) => x.toString()).toList());
      }
    }
    store.load();
    applyUiPrefs();
    store.poke();
    syncAllAlarms();
    return true;
  } catch (_) {
    return false;
  }
}

String backupText() =>
    jsonEncode({for (final k in prefs.getKeys()) k: prefs.get(k)});

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  // رنگ‌های آیکون‌های اپ (مطابق فایل‌های آیکون)
  static const iconChoices = [
    ('blue', 'آبی', Color(0xFF3C78FF), Color(0xFF143296)),
    ('green', 'سبز', Color(0xFF3CCD96), Color(0xFF0A6450)),
    ('purple', 'بنفش', Color(0xFF9664F0), Color(0xFF461E96)),
    ('dark', 'تیره', Color(0xFF464A5C), Color(0xFF0A0C14)),
  ];

  Widget section(String t) => Padding(
        padding: EdgeInsets.fromLTRB(8, 24, 8, 10),
        child: Row(children: [
          Text(t, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          SizedBox(width: 10),
          Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                  color: kAccent, borderRadius: BorderRadius.circular(3))),
        ]),
      );

  Widget row(String icon, Color col, String t, String s, VoidCallback? f,
      {Widget? trailing, bool dim = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: f,
      child: Opacity(
        opacity: dim ? .45 : 1,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 11),
          child: Row(children: [
            iconBadge(icon, col, size: 46),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t,
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15.5)),
                    SizedBox(height: 2),
                    Text(s,
                        style: TextStyle(
                            color: kSub,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            height: 1.5)),
                  ]),
            ),
            trailing ?? Icon(Icons.chevron_left_rounded, color: kSub),
          ]),
        ),
      ),
    );
  }

  Widget switchRow(String icon, Color col, String t, String s, bool v,
      ValueChanged<bool>? f) {
    return row(icon, col, t, s, f == null ? null : () => f(!v),
        dim: f == null, trailing: Switch(value: v, onChanged: f));
  }

  Widget slider(String icon, Color col, String t, String s, double v,
      double min, double max, ValueChanged<double> f) {
    return Padding(
      padding: EdgeInsets.only(top: 6),
      child: Column(children: [
        row(icon, col, t, s, null, trailing: SizedBox()),
        Slider(value: v, min: min, max: max, onChanged: f),
      ]),
    );
  }

  Future<void> saveBackup(BuildContext c) async {
    final n = DateTime.now();
    final ok = await Native.saveFile(
        'clario-backup-${n.year}${two(n.month)}${two(n.day)}.json', backupText());
    if (c.mounted) {
      toast(c, ok ? 'فایل بکاپ ذخیره شد ✅' : 'ذخیره‌ی فایل انجام نشد');
    }
  }

  Future<void> loadBackup(BuildContext c) async {
    final text = await Native.readFile();
    if (text == null) return;
    final ok = await applyBackup(text);
    if (c.mounted) toast(c, ok ? 'بازیابی شد ✅' : 'فایل بکاپ معتبر نیست');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        accentIdx, manualDark, sysTheme, liquidGlass, smartSearch,
        glassLevel, animBg, textScale, store
      ]),
      builder: (c, _) {
        final curIcon = prefs.getString('icon') ?? 'blue';
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 60),
          children: [
            PageTitle('تنظیمات'),
            section('همگام‌سازی و پشتیبان‌گیری'),
            Glass(
              child: Column(children: [
                row('backup', Color(0xFFFF9500), 'پشتیبان‌گیری آفلاین',
                    'خروجی گرفتن فایل در حافظه گوشی', () => saveBackup(context)),
                Divider(height: 1),
                row('restore', Color(0xFF1FA67A), 'بازیابی از فایل',
                    'انتخاب فایل بکاپ از حافظه گوشی', () => loadBackup(context)),
                Divider(height: 1),
                row('note', Color(0xFF6E7585), 'کپی بکاپ در کلیپ‌بورد',
                    'برای فرستادن به پیام‌های ذخیره‌شده', () async {
                  await Clipboard.setData(ClipboardData(text: backupText()));
                  if (context.mounted) toast(context, 'بکاپ کپی شد');
                }),
              ]),
            ),
            section('ظاهر و تم'),
            Glass(
              child: Column(children: [
                switchRow('palette', kAccent, 'تم بر اساس تنظیمات سیستم',
                    'اگر روشن باشد، روشن/تیره را موبایل تعیین می‌کند', sysTheme.value,
                    (v) {
                  sysTheme.value = v;
                  prefs.setBool('systheme', v);
                }),
                Divider(height: 1),
                switchRow('moon', Color(0xFF5B6CFF), 'حالت تیره دستی',
                    'فقط وقتی تم سیستم خاموش باشد فعال می‌شود', manualDark.value,
                    sysTheme.value
                        ? null
                        : (v) {
                            manualDark.value = v;
                            prefs.setBool('dark', v);
                          }),
                Divider(height: 1),
                switchRow('search', Color(0xFF1F9AA6), 'نوار جستجوی هوشمند',
                    'نمایش نوار جستجو بالای صفحه‌ی امروز', smartSearch.value, (v) {
                  smartSearch.value = v;
                  prefs.setBool('smart', v);
                }),
                Divider(height: 1),
                switchRow('widgets', Color(0xFFAF52DE), 'شیشه مایع',
                    'افکت Liquid Glass (شفاف و برجسته)', liquidGlass.value, (v) {
                  liquidGlass.value = v;
                  prefs.setBool('liquid', v);
                }),
                Divider(height: 24),
                Row(children: [
                  Expanded(
                      child: Text('رنگ تم',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15.5))),
                  Text(tdef.name,
                      style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
                ]),
                SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 12, children: [
                  for (var i = 0; i < themeDefs.length; i++)
                    GestureDetector(
                      onTap: () {
                        accentIdx.value = i;
                        prefs.setInt('accent', i);
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [themeDefs[i].accent2, themeDefs[i].accent]),
                          border: Border.all(
                              color: accentIdx.value == i ? kInk : Colors.transparent,
                              width: 2.6),
                        ),
                        child: accentIdx.value == i
                            ? Icon(Icons.check_rounded, color: Colors.white)
                            : null,
                      ),
                    ),
                ]),
                SizedBox(height: 8),
                slider('widgets', Color(0xFF1F9AA6), 'غلظت شیشه',
                    'چپ: کاملاً شفاف • راست: مات‌تر', glassLevel.value, 0, 1, (v) {
                  glassLevel.value = v;
                  prefs.setDouble('glass', v);
                }),
                slider('settings', Color(0xFFFF9500), 'اندازه متن',
                    'بزرگ‌تر یا کوچیک‌تر کردن نوشته‌ها', textScale.value, .85, 1.3, (v) {
                  textScale.value = v;
                  prefs.setDouble('tscale', v);
                }),
                Divider(height: 1),
                switchRow('sparkle', Color(0xFFAF52DE), 'انیمیشن پس‌زمینه',
                    'حرکت آروم حباب‌ها پشت شیشه', animBg.value, (v) {
                  animBg.value = v;
                  prefs.setBool('anim', v);
                }),
              ]),
            ),
            section('آیکون اپ'),
            Glass(
              child: Column(children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('آیکون برنامه را در صفحه‌ی اصلی گوشی عوض کنید',
                      style: TextStyle(
                          color: kSub, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  for (final ic in iconChoices)
                    GestureDetector(
                      onTap: () async {
                        await Native.setIcon(ic.$1);
                        await prefs.setString('icon', ic.$1);
                        store.poke();
                        if (context.mounted) {
                          toast(context, 'آیکون عوض شد (ممکنه چند ثانیه طول بکشه)');
                        }
                      },
                      child: Column(children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [ic.$3, ic.$4]),
                            border: Border.all(
                                color: curIcon == ic.$1 ? kAccent : Colors.transparent,
                                width: 3),
                          ),
                          child: Center(
                              child: Text('ب',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900))),
                        ),
                        SizedBox(height: 6),
                        Text(ic.$2,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: curIcon == ic.$1 ? kAccent : kSub)),
                      ]),
                    ),
                ]),
              ]),
            ),
            section('صفحه امروز و آب‌وهوا'),
            Glass(
              child: Column(children: [
                row('widgets', kAccent, 'انتخاب ویجت‌ها',
                    'اضافه/حذف ویجت با پیش‌نمایش و اندازه',
                    () => showWidgetPicker(context)),
                Divider(height: 1),
                row('reset', Color(0xFF6E7585), 'بازنشانی چیدمان ویجت‌ها',
                    'برگرداندن به چیدمان اولیه', () {
                  resetLayout();
                  toast(context, 'چیدمان ویجت‌ها بازنشانی شد');
                }),
                Divider(height: 1),
                row('sparkle', Color(0xFFFFB300), 'جمله انگیزشی جدید',
                    'یه جمله تصادفی دیگه', nextQuote),
                Divider(height: 1),
                row('pin', Color(0xFF1F9AA6), 'شهر آب‌وهوا',
                    cityNames[store.cityIdx], () => pickCity(context)),
              ]),
            ),
            section('مدیریت آلارم‌ها'),
            Glass(
              child: Column(children: [
                row('alarm', Color(0xFFE5484D), 'تاریخچه آلارم‌ها',
                    'بررسی وضعیت آلارم‌ها',
                    () => openPage(context, AlarmsPage())),
                Divider(height: 1),
                row('shield', Color(0xFF1FA67A), 'دسترسی‌های برنامه',
                    'اعلان، زمان دقیق، صفحه قفل و باتری',
                    () => openPage(context, PermissionsPage())),
                Divider(height: 1),
                row('bell', Color(0xFFFF9500), 'تست آلارم',
                    '۱۰ ثانیه دیگه آلارم به صدا درمیاد', () {
                  Native.schedule(900009,
                      DateTime.now().add(Duration(seconds: 10)), 'تست آلارم کلاریو');
                  toast(context, 'تا ۱۰ ثانیه دیگه آلارم میاد ⏰');
                }),
              ]),
            ),
            section('اطلاعات و پشتیبانی'),
            Glass(
              child: Column(children: [
                row('info', Color(0xFF1F9AA6), 'درباره کلاریو',
                    'رایگان، بدون تبلیغ و بدون ثبت‌نام',
                    () => openPage(context, AboutPage())),
                Divider(height: 1),
                row('send', Color(0xFF2AA5E0), 'درباره توسعه‌دهنده',
                    'سازنده کلاریو را بیشتر بشناسید',
                    () => openPage(context, DeveloperPage())),
                Divider(height: 1),
                row('trash', kDanger, 'پاک‌کردن همه اطلاعات',
                    'کارها، یادداشت‌ها و بقیه حذف می‌شن', () async {
                  if (await confirm(context, 'همه اطلاعات برنامه پاک بشه؟')) {
                    for (final t in store.tasks) {
                      cancelTaskAlarm(t);
                    }
                    await prefs.clear();
                    store.load();
                    applyUiPrefs();
                    store.poke();
                    if (context.mounted) toast(context, 'همه‌چیز پاک شد');
                  }
                }),
              ]),
            ),
            SizedBox(height: 30),
            Center(
                child: Text('C L A R I O',
                    style: TextStyle(
                        color: kSub.withAlpha(150),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4))),
          ],
        );
      },
    );
  }
}

// ───────────────────────── درباره کلاریو ─────────────────────────
class AboutPage extends StatelessWidget {
  AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        PageTitle('درباره کلاریو'),
        Glass(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 26),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              ClarioLogo(size: 88),
              SizedBox(height: 14),
              Text('Clario | کلاریو',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('روزت، شفاف‌تر.',
                  style: TextStyle(
                      color: kAccent, fontWeight: FontWeight.w900, fontSize: 16)),
              SizedBox(height: 18),
              ClarioMascot(size: 150),
              SizedBox(height: 14),
              Text(
                  'کلاریو برنامه‌ی رایگان مدیریت کارها، ویجت‌ها و ابزارهای روزانه‌ست؛ بدون تبلیغ و بدون ثبت‌نام. همه اطلاعات فقط روی گوشی خودت ذخیره می‌شه. آب‌وهوا از سرویس رایگان Open-Meteo گرفته می‌شه.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: kSub,
                      fontWeight: FontWeight.w700,
                      height: 1.9,
                      fontSize: 14)),
              SizedBox(height: 14),
              Text('نسخه ۲.۲',
                  style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── درباره توسعه‌دهنده ─────────────────────────
class DeveloperPage extends StatelessWidget {
  DeveloperPage({super.key});

  static const links = [
    ('megaphone', 'کانال تلگرام', 't.me/zicoflame', 'https://t.me/zicoflame', Color(0xFF2AA5E0)),
    ('send', 'آیدی تلگرام توسعه‌دهنده', '@trippiezico', 'https://t.me/trippiezico', Color(0xFF2AA5E0)),
    ('camera', 'اینستاگرام توسعه‌دهنده', '@trippiezico', 'https://www.instagram.com/trippiezico', Color(0xFFE0457B)),
  ];

  Future<void> go(BuildContext c, String url) async {
    final ok = await Native.openUrl(url);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      if (c.mounted) toast(c, 'لینک کپی شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        PageTitle('درباره توسعه‌دهنده'),
        Glass(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              ClarioMascot(size: 120),
              SizedBox(height: 14),
              Text('ساخته شده توسط زیکو',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('کلاریو رایگان و بدون تبلیغه',
                  style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        SizedBox(height: 14),
        Glass(
          child: Column(children: [
            for (var i = 0; i < links.length; i++) ...[
              if (i > 0) Divider(height: 1),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => go(context, links[i].$4),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    iconBadge(links[i].$1, links[i].$5, size: 46),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(links[i].$2,
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 15.5)),
                            Text(links[i].$3,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                    color: kSub,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ]),
                    ),
                    Icon(Icons.open_in_new_rounded, color: kSub, size: 20),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}
