enum MessageType {
  text,
  image,
}

class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final String? imageUrl;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.type = MessageType.text,
    this.imageUrl,
  });

  // Convert MessageModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'type': type.toString().split('.').last,
      'imageUrl': imageUrl,
    };
  }

  // Create MessageModel from JSON
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageType type = MessageType.text;
    String? typeString = json['type'];
    if (typeString == 'image') {
      type = MessageType.image;
    }
    
    return MessageModel(
      messageId: json['messageId'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      isRead: json['isRead'] ?? false,
      type: type,
      imageUrl: json['imageUrl'],
    );
  }

  // Create a copy with updated fields
  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? receiverId,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    MessageType? type,
    String? imageUrl,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() {
    return 'MessageModel(messageId: $messageId, senderId: $senderId, receiverId: $receiverId, message: $message, timestamp: $timestamp, isRead: $isRead, type: $type, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel &&
        other.messageId == messageId &&
        other.senderId == senderId &&
        other.receiverId == receiverId &&
        other.message == message &&
        other.timestamp == timestamp &&
        other.isRead == isRead &&
        other.type == type &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode {
    return messageId.hashCode ^
        senderId.hashCode ^
        receiverId.hashCode ^
        message.hashCode ^
        timestamp.hashCode ^
        isRead.hashCode ^
        type.hashCode ^
        imageUrl.hashCode;
  }
}
