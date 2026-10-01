import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationType { readiness, workout, milestone, technique, alert }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? actionRoute;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
        actionRoute: actionRoute,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'actionRoute': actionRoute,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: NotificationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NotificationType.readiness,
        ),
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
        actionRoute: json['actionRoute'] as String?,
      );
}

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _storageKey = 'rehab_x_notifications';
  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _notifications = list.map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {
        _loadDefaultNotifications();
      }
    } else {
      _loadDefaultNotifications();
      await _persist();
    }
    notifyListeners();
  }

  void _loadDefaultNotifications() {
    final now = DateTime.now();
    _notifications = [
      AppNotification(
        id: 'notif_1',
        title: 'Optimal Readiness Window Open',
        message: 'Your physiological readiness is at peak (85%). Lower-body stability session recommended.',
        type: NotificationType.readiness,
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: false,
      ),
      AppNotification(
        id: 'notif_2',
        title: 'Biomechanical Quality Milestone',
        message: 'Movement consistency increased to 94% across recent reps. Great form stability!',
        type: NotificationType.milestone,
        timestamp: now.subtract(const Duration(hours: 4)),
        isRead: false,
      ),
      AppNotification(
        id: 'notif_3',
        title: 'Recovery Recommendation',
        message: 'High neuromuscular load observed. Consider 8 min posterior chain mobility stretch.',
        type: NotificationType.technique,
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }

  Future<void> addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.readiness,
    String? actionRoute,
  }) async {
    final notif = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      actionRoute: actionRoute,
    );
    _notifications.insert(0, notif);
    await _persist();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_notifications.map((n) => n.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}

