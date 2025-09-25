class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String description;
  final bool isOnline;
  final DateTime lastSeen;
  final List<String> friends;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.description,
    required this.isOnline,
    required this.lastSeen,
    required this.friends,
  });

  // Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'description': description,
      'isOnline': isOnline,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'friends': friends,
    };
  }

  // Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    List<String> friendsList = [];
    
    // Handle friends field which can be null, empty, or a Map from Firebase
    if (json['friends'] != null) {
      final friendsData = json['friends'];
      if (friendsData is Map) {
        // Firebase stores arrays as maps with keys, extract the values
        friendsList = friendsData.values.cast<String>().toList();
      } else if (friendsData is List) {
        friendsList = friendsData.cast<String>().toList();
      }
    }
    
    return UserModel(
      uid: uid,
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      description: json['description'] ?? '',
      isOnline: json['isOnline'] ?? false,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] ?? 0),
      friends: friendsList,
    );
  }

  // Creates a new UserModel object with some fields changed while keeping others the same.
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? description,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? friends,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      friends: friends ?? this.friends,
    );
  }


  //Makes it easy to print the object in debug logs
  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, description: $description, isOnline: $isOnline, lastSeen: $lastSeen, friends: $friends)';
  }


  //Equality & HashCode
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.description == description &&
        other.isOnline == isOnline &&
        other.lastSeen == lastSeen;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        description.hashCode ^
        isOnline.hashCode ^
        lastSeen.hashCode;
  }

  // Get status text
  String get statusText {
    if (isOnline) {
      return 'Online';
    } else {
      final now = DateTime.now();
      final difference = now.difference(lastSeen);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    }
  }
}
