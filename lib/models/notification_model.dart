class NotificationModel {
  final String id;
  final String userId; // Who receives the notification
  final String fromUserId; // Who triggered the notification
  final String fromUserName; // Name of the user who triggered it
  final String type; // 'friend_request', 'message', 'friend_added'
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic> data; // Additional data

  NotificationModel({
    required this.id,
    required this.userId,
    required this.fromUserId,
    required this.fromUserName,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.data = const {},
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'type': type,
      'title': title,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'data': data,
    };
  }

  // Create from JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json, String id) {
    return NotificationModel(
      id: id,
      userId: json['userId'] ?? '',
      fromUserId: json['fromUserId'] ?? '',
      fromUserName: json['fromUserName'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      isRead: json['isRead'] ?? false,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  // Copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? fromUserId,
    String? fromUserName,
    String? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: $type, title: $title, fromUserName: $fromUserName, isRead: $isRead)';
  }

  // Get icon based on notification type
  String get icon {
    switch (type) {
      case 'friend_added':
        return '👥';
      case 'message':
        return '💬';
      case 'friend_request':
        return '🤝';
      default:
        return '🔔';
    }
  }

  // Get color based on notification type
  String get color {
    switch (type) {
      case 'friend_added':
        return 'green';
      case 'message':
        return 'blue';
      case 'friend_request':
        return 'orange';
      default:
        return 'gray';
    }
  }
}
