// lib/models/notification_entity.dart
import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String type; // general | live_stream | new_lesson | reminder | achievement
  final String title;
  final String body;
  final String? linkUrl;
  final DateTime sendAt;
  final DateTime createdAt;
  final bool isRead;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.linkUrl,
    required this.sendAt,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationEntity.fromJson(
    Map<String, dynamic> json, {
    bool isRead = false,
  }) {
    return NotificationEntity(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String,
      body: json['body'] as String,
      linkUrl: json['link_url'] as String?,
      sendAt: DateTime.parse(json['send_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: isRead,
    );
  }

  NotificationEntity copyWith({bool? isRead}) => NotificationEntity(
        id: id,
        type: type,
        title: title,
        body: body,
        linkUrl: linkUrl,
        sendAt: sendAt,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  @override
  List<Object?> get props => [id, type, title, body, linkUrl, sendAt, isRead];
}
