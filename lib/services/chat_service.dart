import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class ChatService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  ChatService() {
    // Keep important data synced (only on mobile platforms)
    if (!kIsWeb) {
      try {
        _database.child('users').keepSynced(true);
        _database.child('chats').keepSynced(true);
        print('Database keepSynced enabled for mobile');
      } catch (e) {
        print('keepSynced not supported: $e');
      }
    }
  }

  // Send a message
  Future<void> sendMessage(String receiverId, String message) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Error: No current user when sending message');
        return;
      }

      final now = DateTime.now();
      final messageData = MessageModel(
        messageId: '',
        senderId: currentUser.uid,
        receiverId: receiverId,
        message: message,
        timestamp: now,
        isRead: false,
      );

      // Create chat room ID (consistent ordering)
      String chatRoomId = _createChatRoomId(currentUser.uid, receiverId);
      
      print('Sending message to chat room: $chatRoomId');
      print('Message data: ${messageData.toJson()}');
      
      // Add message to chat room with server timestamp for accuracy
      final messageRef = _database.child('chats/$chatRoomId/messages').push();
      await messageRef.set({
        ...messageData.toJson(),
        'messageId': messageRef.key,
        'serverTimestamp': ServerValue.timestamp,
      });
      
      // Update last message info
      await _database.child('chats/$chatRoomId/lastMessage').set({
        'message': message,
        'senderId': currentUser.uid,
        'timestamp': ServerValue.timestamp,
        'messageId': messageRef.key,
      });
      
      // Update chat participants info
      await _database.child('chats/$chatRoomId/participants').set({
        currentUser.uid: true,
        receiverId: true,
      });
      
      // Message notifications disabled - only friend notifications enabled
      
      print('Message sent successfully with ID: ${messageRef.key}');
      
    } catch (e) {
      print('Error sending message: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Get messages for a chat
  Stream<List<MessageModel>> getMessages(String receiverId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    String chatRoomId = _createChatRoomId(currentUser.uid, receiverId);
    
    return _database
        .child('chats/$chatRoomId/messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      List<MessageModel> messages = [];
      
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> messagesData = 
            event.snapshot.value as Map<dynamic, dynamic>;
        
        messagesData.forEach((key, value) {
          Map<String, dynamic> messageMap = Map<String, dynamic>.from(value);
          messageMap['messageId'] = key;
          messages.add(MessageModel.fromJson(messageMap));
        });
        
        // Sort messages by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      
      return messages;
    });
  }

  // Get user's chat list
  Stream<List<Map<String, dynamic>>> getChatList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _database
        .child('chats')
        .orderByChild('lastMessage/timestamp')
        .onValue
        .asyncMap((event) async {
      List<Map<String, dynamic>> chats = [];
      
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> chatsData = 
            event.snapshot.value as Map<dynamic, dynamic>;
        
        for (var entry in chatsData.entries) {
          String chatRoomId = entry.key;
          Map<dynamic, dynamic> chatData = entry.value;
          
          // Check if current user is part of this chat
          List<String> participants = chatRoomId.split('_');
          if (participants.contains(currentUser.uid)) {
            // Get the other participant
            String otherUserId = participants.firstWhere(
              (id) => id != currentUser.uid,
            );
            
            // Get other user's data
            UserModel? otherUser = await _getUserById(otherUserId);
            
            if (otherUser != null && chatData['lastMessage'] != null) {
              chats.add({
                'user': otherUser,
                'lastMessage': chatData['lastMessage']['message'] ?? '',
                'timestamp': DateTime.fromMillisecondsSinceEpoch(
                  chatData['lastMessage']['timestamp'] ?? 0
                ),
                'isLastMessageFromMe': chatData['lastMessage']['senderId'] == currentUser.uid,
              });
            }
          }
        }
        
        // Sort chats by last message timestamp (most recent first)
        chats.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      }
      
      return chats;
    });
  }

  // Get user's friends as a stream for real-time updates
  Stream<List<UserModel>> getFriendsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _database
        .child('users/${currentUser.uid}/friends')
        .onValue
        .asyncMap((event) async {
      List<UserModel> friends = [];
      
      try {
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> friendsData = 
              event.snapshot.value as Map<dynamic, dynamic>;
          
          for (var friendId in friendsData.values) {
            UserModel? friend = await _getUserById(friendId);
            if (friend != null) {
              friends.add(friend);
            }
          }
        }
      } catch (e) {
        print('Error processing friends data: $e');
      }
      
      return friends;
    });
  }

  // Get user's friends (keeping original method for compatibility)
  Future<List<UserModel>> getFriends() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      DatabaseEvent event = await _database
          .child('users/${currentUser.uid}/friends')
          .once();
      
      List<UserModel> friends = [];
      
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> friendsData = 
            event.snapshot.value as Map<dynamic, dynamic>;
        
        for (var friendId in friendsData.values) {
          UserModel? friend = await _getUserById(friendId);
          if (friend != null) {
            friends.add(friend);
          }
        }
      }
      
      return friends;
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String senderId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      String chatRoomId = _createChatRoomId(currentUser.uid, senderId);
      
      DatabaseEvent event = await _database
          .child('chats/$chatRoomId/messages')
          .orderByChild('senderId')
          .equalTo(senderId)
          .once();
      
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> messages = 
            event.snapshot.value as Map<dynamic, dynamic>;
        
        messages.forEach((key, value) {
          if (value['isRead'] == false) {
            _database
                .child('chats/$chatRoomId/messages/$key')
                .update({'isRead': true});
          }
        });
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Create consistent chat room ID
  String _createChatRoomId(String userId1, String userId2) {
    List<String> users = [userId1, userId2];
    users.sort(); // Ensure consistent ordering
    return users.join('_');
  }

  // Get user by ID
  Future<UserModel?> _getUserById(String userId) async {
    try {
      DatabaseEvent event = await _database.child('users/$userId').once();
      
      if (event.snapshot.value != null) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(
          event.snapshot.value as Map<dynamic, dynamic>
        );
        return UserModel.fromJson(userData, userId);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Get unread message count
  Future<int> getUnreadMessageCount(String senderId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      String chatRoomId = _createChatRoomId(currentUser.uid, senderId);
      
      DatabaseEvent event = await _database
          .child('chats/$chatRoomId/messages')
          .orderByChild('senderId')
          .equalTo(senderId)
          .once();
      
      int unreadCount = 0;
      
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> messages = 
            event.snapshot.value as Map<dynamic, dynamic>;
        
        messages.forEach((key, value) {
          if (value['isRead'] == false) {
            unreadCount++;
          }
        });
      }
      
      return unreadCount;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }
}
