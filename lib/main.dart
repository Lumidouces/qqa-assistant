import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/store.dart';
import 'design/glass.dart';
import 'design/liquid_tabs.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/screens/connect_screen.dart';
import 'ui/screens/events_screen.dart';
import 'ui/screens/logs_screen.dart';
import 'ui/screens/overview_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/tools_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先把液态玻璃着色器编译好，避免首帧闪一下假玻璃。
  await GlassShader.load();
  final store = await AppStore.load();
  final state = AppState(store);
  runApp(QqaApp(state: state));
}

/// Root widget: owns the [AppState] and the glass tone.
class QqaApp extends StatefulWidget {
  const QqaApp({super.key, required this.state});

  final AppState state;

  @override
  State<QqaApp> createState() => _QqaAppState();
}

class _QqaAppState extends State<QqaApp> {
  late final AppState _state = widget.state;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    // The tone lives in the store, so a theme flip has to rebuild from here.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tone = _state.store.darkMode ? GlassTone.dark : GlassTone.light;

    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        return GlassScope(
          tone: tone,
          child: MaterialApp(
            title: 'QQA 助手',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(tone),
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(_state.store.fontPercent / 100),
                ),
                child: GlassBackdrop(
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: _state.ready
                ? Shell(state: _state)
                : ConnectScreen(state: _state, firstRun: true),
          ),
        );
      },
    );
  }
}

/// Shell: page body plus the floating glass dock.
///
/// Wide layouts keep the dock but pin it to the left as a rail-like column so
/// the app still feels like the phone original.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});

  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _tabs = <({String label, IconData icon})>[
    (label: '总览', icon: Icons.blur_on_rounded),
    (label: '过程', icon: Icons.forum_rounded),
    (label: '存档', icon: Icons.chat_bubble_rounded),
    (label: '操作', icon: Icons.bolt_rounded),
    (label: '设置', icon: Icons.settings_rounded),
  ];

  AppState get state => widget.state;

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final wide = MediaQuery.of(context).size.width >= 760;

    final pages = <Widget>[
      OverviewScreen(state: state, onNavigate: _select),
      LogsScreen(state: state),
      EventsScreen(state: state),
      ToolsScreen(state: state),
      SettingsScreen(state: state),
    ];

    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                child: Center(
                  child: GlassChrome(
                    radius: GlassRadius.sheet,
                    blur: GlassBlur.chrome,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _tabs.length; i++)
                          _RailItem(
                            label: _tabs[i].label,
                            icon: _tabs[i].icon,
                            selected: i == _index,
                            ramp: ramp,
                            onTap: () => _select(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(bottom: false, child: body),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: LiquidTabBar(
          tabs: [
            for (final tab in _tabs)
              LiquidTabSpec(icon: tab.icon, label: tab.label),
          ],
          index: _index,
          onSelect: _select,
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.ramp,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final GlassRamp ramp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ramp.accent : ramp.contentMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: GlassMotion.base,
        curve: GlassMotion.curve,
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? ramp.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(GlassRadius.chip),
          border: Border.all(
            color:
                selected ? ramp.accent.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GlassText.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
