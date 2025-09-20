class GroupModel {
  final String groupId;
  final String groupName;
  final String groupDescription;
  final String groupImage; // URL for group image (optional)
  final String createdBy; // User ID of group creator
  final DateTime createdAt;
  final List<String> members; // List of user IDs
  final List<String> admins; // List of admin user IDs
  final bool isActive;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;

  GroupModel({
    required this.groupId,
    required this.groupName,
    required this.groupDescription,
    this.groupImage = '',
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.admins,
    this.isActive = true,
    this.lastMessage = '',
    required this.lastMessageTime,
    this.lastMessageSenderId = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupDescription': groupDescription,
      'groupImage': groupImage,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'members': members,
      'admins': admins,
      'isActive': isActive,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'lastMessageSenderId': lastMessageSenderId,
    };
  }

  factory GroupModel.fromJson(Map<String, dynamic> json, String groupId) {
    return GroupModel(
      groupId: groupId,
      groupName: json['groupName'] ?? '',
      groupDescription: json['groupDescription'] ?? '',
      groupImage: json['groupImage'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      members: List<String>.from(json['members'] ?? []),
      admins: List<String>.from(json['admins'] ?? []),
      isActive: json['isActive'] ?? true,
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(
        json['lastMessageTime'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      lastMessageSenderId: json['lastMessageSenderId'] ?? '',
    );
  }

  GroupModel copyWith({
    String? groupId,
    String? groupName,
    String? groupDescription,
    String? groupImage,
    String? createdBy,
    DateTime? createdAt,
    List<String>? members,
    List<String>? admins,
    bool? isActive,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
  }) {
    return GroupModel(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupDescription: groupDescription ?? this.groupDescription,
      groupImage: groupImage ?? this.groupImage,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      isActive: isActive ?? this.isActive,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
    );
  }

  // Check if user is admin
  bool isAdmin(String userId) {
    return admins.contains(userId);
  }

  // Check if user is member
  bool isMember(String userId) {
    return members.contains(userId);
  }

  // Get member count
  int get memberCount => members.length;

  // Get admin count
  int get adminCount => admins.length;
}
