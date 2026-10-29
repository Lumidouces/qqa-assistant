/// The one place the displayed version lives.
///
/// Keep this in step with `version:` in `pubspec.yaml` — the About tab and the
/// header chip both read from here so a bump never leaves a stale string on
/// screen. Bump rules we follow:
///
///   * patch (`1.2.x`) — display / copy / small fixes, no new surface
///   * minor (`1.x.0`) — new feature or a screen's worth of new behaviour
///   * major (`x.0.0`) — rewrite, or a change that breaks existing settings
const String appVersion = '1.4.5';
const int appBuild = 13;

/// `1.2.1 (build 5)`
String get appVersionFull => '$appVersion (build $appBuild)';
