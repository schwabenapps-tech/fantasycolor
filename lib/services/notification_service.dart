import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';

/// Sanfte Local Notifications (täglicher Sticker-Hinweis).
///
/// Ohne `flutter_timezone` (JVM-Konflikt mit AGP 9) — Zeitzone wird über
/// Offset-Matching aus der `timezone`-DB gesetzt.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'fantasy_gentle';
  static const _channelName = 'Gentle reminders';
  static const _dailyId = 42;
  static const _streakId = 43;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      _setLocalTimezoneFromOffset();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e, st) {
      debugPrint('NotificationService.initialize failed: $e\n$st');
    }
  }

  /// Findet eine IANA-Location mit gleichem Offset wie das Gerät.
  void _setLocalTimezoneFromOffset() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;

    const preferred = <String>[
      'Europe/Berlin',
      'Europe/Vienna',
      'Europe/Zurich',
      'Europe/Paris',
      'Europe/Amsterdam',
      'Europe/Rome',
      'Europe/Madrid',
      'Europe/Lisbon',
      'Europe/Warsaw',
      'Europe/Istanbul',
      'Europe/London',
      'America/New_York',
      'America/Los_Angeles',
      'America/Sao_Paulo',
      'Asia/Tokyo',
      'UTC',
    ];

    for (final name in preferred) {
      try {
        final loc = tz.getLocation(name);
        if (tz.TZDateTime.from(now, loc).timeZoneOffset == offset) {
          tz.setLocalLocation(loc);
          return;
        }
      } catch (_) {}
    }

    for (final name in tz.timeZoneDatabase.locations.keys) {
      try {
        final loc = tz.getLocation(name);
        if (tz.TZDateTime.from(now, loc).timeZoneOffset == offset) {
          tz.setLocalLocation(loc);
          return;
        }
      } catch (_) {}
    }

    tz.setLocalLocation(tz.UTC);
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (!_ready) await initialize();
    try {
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final ok = await ios?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;
        return ok;
      }
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final ok = await android?.requestNotificationsPermission() ?? true;
        return ok;
      }
    } catch (e, st) {
      debugPrint('NotificationService.permission failed: $e\n$st');
    }
    return false;
  }

  /// Plant eine ruhige tägliche Erinnerung (~16:30 Ortszeit).
  Future<void> scheduleGentleReminders(BuildContext context) async {
    final t = AppStrings.of(context);
    final dailyTitle = t.notifyTitle;
    final dailyBody = t.notifyBody;
    final streakTitle = t.notifyStreakTitle;
    final streakBody = t.notifyStreakBody;

    if (!_ready) await initialize();
    final allowed = await requestPermissionIfNeeded();
    if (!allowed) return;

    await _plugin.cancel(_dailyId);
    await _plugin.cancel(_streakId);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Soft daily reminders for Fairy Fantasy Color',
      importance: Importance.low,
      priority: Priority.low,
      styleInformation: BigTextStyleInformation(dailyBody),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 16, 30);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        _dailyId,
        dailyTitle,
        dailyBody,
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      var streakAt =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 45);
      if (!streakAt.isAfter(now)) {
        streakAt = streakAt.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        _streakId,
        streakTitle,
        streakBody,
        streakAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Soft daily reminders for Fairy Fantasy Color',
            importance: Importance.low,
            priority: Priority.low,
            styleInformation: BigTextStyleInformation(streakBody),
          ),
          iOS: iosDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, st) {
      debugPrint('NotificationService.schedule failed: $e\n$st');
    }
  }
}
