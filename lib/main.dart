import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alarm.dart';
import 'core.dart';
import 'home.dart';
import 'native.dart';
import 'pages.dart';
import 'tools.dart';

void showFatal(Object e, StackTrace? st) {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: SelectableText(
            'Clario startup error\n\n$e\n\n${st ?? ''}',
            textDirection: TextDirection.ltr,
            style: TextStyle(color: Color(0xFFB71C1C), fontSize: 12),
          ),
        ),
      ),
    ),
  ));
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorWidget.builder = (d) => Material(
          color: Color(0xFFFFEBEE),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Text(
                d.exceptionAsString(),
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Color(0xFFB71C1C), fontSize: 11),
              ),
            ),
          ),
        );
    try {
      prefs = await Prefs.load();
      store.load();
      applyUiPrefs();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e, st) {
      showFatal(e, st);
      return;
    }
    runApp(ClarioApp());
  }, (e, st) {});
}

class ClarioApp extends StatefulWidget {
  ClarioApp({super.key});
  @override
  State<ClarioApp> createState() => _ClarioAppState();
}

class _ClarioAppState extends State<ClarioApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (sysTheme.value) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        accentIdx, manualDark, sysTheme, liquidGlass, glassLevel, animBg, textScale
      ]),
      builder: (c, _) {
        final dark = isDark;
        final base = ThemeData(
          useMaterial3: true,
          brightness: dark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: kBg,
          colorScheme: ColorScheme.fromSeed(
              seedColor: kAccent,
              brightness: dark ? Brightness.dark : Brightness.light),
        );
        return MaterialApp(
          title: 'کلاریو',
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            textTheme: base.textTheme.apply(bodyColor: kInk, displayColor: kInk),
          ),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(textScale.value)),
            child: Directionality(
                textDirection: TextDirection.rtl, child: child!),
          ),
          home: SplashGate(),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const items = [
    ('today', 'امروز'),
    ('tasks', 'کارها'),
    ('tools', 'ابزارها'),
    ('weather', 'آب و هوا'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      syncAllAlarms();
      wx.load();
      if (Native.ok && prefs.getBool('asked') != true) {
        await prefs.setBool('asked', true);
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kSurface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            title: Text('دسترسی‌های لازم',
                style: TextStyle(fontWeight: FontWeight.w900)),
            content: Text(
                'برای اینکه آلارم کارها و تایمرها حتی وقتی برنامه بسته‌ست به صدا دربیاد، کلاریو به اجازه اعلان‌ها و چند تنظیم دیگه نیاز داره. الان تنظیمشون می‌کنیم؟',
                style: TextStyle(height: 1.7)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('بعدا')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('بزن بریم')),
            ],
          ),
        );
        if (ok == true) {
          await Native.requestNotif();
          if (mounted) openPage(context, PermissionsPage());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIdx,
      builder: (c, idx, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: (idx == 3 || isDark)
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            extendBody: true,
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            body: Stack(children: [
              Positioned.fill(child: Backdrop()),
              IndexedStack(index: idx, children: [
                TodayPage(),
                TasksPage(),
                ToolsPage(),
                WeatherPage(),
              ]),
            ]),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Glass(
                  radius: 34,
                  padding: EdgeInsets.all(6),
                  child: Row(children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => tabIdx.value = i,
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: idx == i
                                  ? LinearGradient(colors: [
                                      kAccentLight.withAlpha(70),
                                      kAccent.withAlpha(40)
                                    ])
                                  : null,
                              border: idx == i
                                  ? Border.all(color: wh(.8), width: 1)
                                  : null,
                            ),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(items[i].$1,
                                      size: 26,
                                      color: idx == i ? kAccent : kSub),
                                  SizedBox(height: 3),
                                  Text(items[i].$2,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: idx == i ? kAccent : kSub)),
                                ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class SplashGate extends StatefulWidget {
  SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted) setState(() => done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      child: done
          ? Shell(key: ValueKey('shell'))
          : Scaffold(
              key: ValueKey('splash'),
              body: Stack(children: [
                Positioned.fill(child: Backdrop()),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ClarioMascot(size: 170),
                    SizedBox(height: 18),
                    Text('Clario',
                        style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: kAccent,
                            letterSpacing: 2)),
                    Text('کلاریو',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
                    SizedBox(height: 8),
                    Text('روزت، شفاف‌تر.',
                        style: TextStyle(color: kSub, fontWeight: FontWeight.w800)),
                    SizedBox(height: 18),
                    Text('v2.3',
                        style: TextStyle(color: kSub.withAlpha(150), fontSize: 12)),
                  ]),
                ),
              ]),
            ),
    );
  }
}
