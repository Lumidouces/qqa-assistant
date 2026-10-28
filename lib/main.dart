import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/store.dart';
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
  final store = await AppStore.load();
  final state = AppState(store);
  runApp(QqaApp(state: state));
}

/// Root widget: owns the [AppState] and the shell chrome.
class QqaApp extends StatefulWidget {
  const QqaApp({super.key, required this.state});

  final AppState state;

  @override
  State<QqaApp> createState() => _QqaAppState();
}

class _QqaAppState extends State<QqaApp> {
  late final AppState _state = widget.state;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        return MaterialApp(
          title: 'QQA 助手',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(_state.store.fontPercent / 100),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _state.ready
              ? Shell(state: _state)
              : ConnectScreen(state: _state, firstRun: true),
        );
      },
    );
  }
}

/// Bottom-tab shell with the five sections from the mock-up.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});

  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _tabs = <({String label, IconData icon})>[
    (label: '总览', icon: Icons.grid_view_rounded),
    (label: '日志', icon: Icons.article_outlined),
    (label: '事件', icon: Icons.bolt_rounded),
    (label: '操作', icon: Icons.tune_rounded),
    (label: '设置', icon: Icons.settings_rounded),
  ];

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    final pages = <Widget>[
      OverviewScreen(
          state: state, onNavigate: (index) => setState(() => _index = index)),
      LogsScreen(state: state),
      EventsScreen(state: state),
      ToolsScreen(state: state),
      SettingsScreen(state: state),
    ];

    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                backgroundColor: QqaColors.bg,
                indicatorColor: QqaColors.accent.withValues(alpha: 0.16),
                labelType: NavigationRailLabelType.all,
                selectedIconTheme:
                    const IconThemeData(color: QqaColors.accent, size: 22),
                unselectedIconTheme:
                    const IconThemeData(color: QqaColors.faint, size: 22),
                selectedLabelTextStyle:
                    const TextStyle(color: QqaColors.accent, fontSize: 11.5),
                unselectedLabelTextStyle:
                    const TextStyle(color: QqaColors.faint, fontSize: 11.5),
                destinations: [
                  for (final tab in _tabs)
                    NavigationRailDestination(
                      icon: Icon(tab.icon),
                      label: Text(tab.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, color: QqaColors.line),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: QqaColors.bg,
          border: Border(top: BorderSide(color: QqaColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var index = 0; index < _tabs.length; index++)
                  Expanded(
                    child: _TabButton(
                      label: _tabs[index].label,
                      icon: _tabs[index].icon,
                      selected: index == _index,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _index = index);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? QqaColors.accent : QqaColors.faint;
    return InkWell(
      onTap: onTap,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: selected
                ? BoxDecoration(
                    color: QqaColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  )
                : null,
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
