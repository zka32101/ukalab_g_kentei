import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:ukalab_core/reminder_notification.dart';

/// 学習リマインダーの端末の通知（ローカル通知）。Android と iOS だけで動き、それ以外は何もしない。
///
/// 時刻は「その瞬間」を UTC で渡す（端末のタイムゾーン名を取らずに済む。通知が出る時刻は
/// 端末の時計どおり）。予約は毎回すべて取り消してから作り直す。
class LocalReminderNotifier implements ReminderNotifier {
  LocalReminderNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'study_reminder';
  static const _channelName = '学習リマインダー';

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _ensureInitialized() async {
    if (!_supported) return false;
    if (_initialized) return true;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // 許可は、リマインダーをオンにしたときに [requestPermission] で求める。
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (!await _ensureInitialized()) return false;
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> schedule(List<DateTime> times, {required String title, required String body}) async {
    try {
      if (!await _ensureInitialized()) return;
      await _plugin.cancelAll();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName, importance: Importance.defaultImportance),
        iOS: DarwinNotificationDetails(),
      );
      for (var i = 0; i < times.length; i++) {
        await _plugin.zonedSchedule(
          i,
          title,
          body,
          tz.TZDateTime.from(times[i], tz.UTC),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // 通知が出せなくても、学習そのものは続けられる。
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      if (!await _ensureInitialized()) return;
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
