import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class ChatService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: 'gs://chat-app-1ca15.firebasestorage.app');
  final NotificationService _notificationService = NotificationService();

  //Constructor: enabling keepSynced on mobile
  ChatService() {
    // Keep important data synced (only on mobile platforms)
    if (!kIsWeb) {
      try {
        _database.child('users').keepSynced(true);//offline support
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

  // Delete a message for both users in a chat
  Future<void> deleteMessage(String otherUserId, String messageId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final String chatRoomId = _createChatRoomId(currentUser.uid, otherUserId);

      // Remove the message from the messages list
      final messageRef =
          _database.child('chats/$chatRoomId/messages/$messageId');
      await messageRef.remove();

      // After deleting, update the lastMessage field to the latest remaining message (if any)
      final DatabaseEvent remainingMessagesEvent = await _database
          .child('chats/$chatRoomId/messages')
          .orderByChild('timestamp')
          .limitToLast(1)
          .once();

      if (remainingMessagesEvent.snapshot.value != null) {
        final Map<dynamic, dynamic> remainingMessages =
            remainingMessagesEvent.snapshot.value as Map<dynamic, dynamic>;

        // There should be at most one entry due to limitToLast(1)
        final entry = remainingMessages.entries.first;
        final String lastMessageId = entry.key;
        final Map<String, dynamic> lastMessageMap =
            Map<String, dynamic>.from(entry.value);
        lastMessageMap['messageId'] = lastMessageId;

        final MessageModel lastMessage = MessageModel.fromJson(lastMessageMap);

        await _database.child('chats/$chatRoomId/lastMessage').set({
          'message': lastMessage.message,
          'senderId': lastMessage.senderId,
          'timestamp': lastMessage.timestamp.millisecondsSinceEpoch,
          'messageId': lastMessage.messageId,
        });
      } else {
        // No messages left in this chat, remove the lastMessage node
        await _database.child('chats/$chatRoomId/lastMessage').remove();
      }
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  // Send an image message
  // Future<void> sendImageMessage(String receiverId, File imageFile) async {
  //   try {
  //     final currentUser = _auth.currentUser;
  //     if (currentUser == null) {
  //       throw Exception('No current user when sending image message');
  //     }
  //
  //     print('Starting image upload...');
  //     print('Storage bucket: ${_storage.bucket}');
  //
  //     // Check if file exists and is readable
  //     if (!await imageFile.exists()) {
  //       throw Exception('Image file does not exist');
  //     }
  //
  //     final int fileSize = await imageFile.length();
  //     print('File size: $fileSize bytes');
  //
  //     if (fileSize == 0) {
  //       throw Exception('Image file is empty');
  //     }
  //
  //     // Create a unique filename
  //     final String fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg';
  //     print('Uploading to path: $fileName');
  //
  //     try {
  //       // Upload image to Firebase Storage with metadata
  //       final Reference storageRef = _storage.ref().child(fileName);
  //
  //       final SettableMetadata metadata = SettableMetadata(
  //         contentType: 'image/jpeg',
  //         customMetadata: {
  //           'uploadedBy': currentUser.uid,
  //           'uploadedAt': DateTime.now().toIso8601String(),
  //         },
  //       );
  //
  //       final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
  //
  //       // Monitor upload progress
  //       uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
  //         final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
  //         print('Upload progress: ${progress.toStringAsFixed(1)}%');
  //       });
  //
  //       final TaskSnapshot snapshot = await uploadTask;
  //
  //       // Get download URL
  //       final String downloadUrl = await snapshot.ref.getDownloadURL();
  //       print('Image uploaded successfully. URL: $downloadUrl');
  //
  //       // Create message data
  //       final now = DateTime.now();
  //       final messageData = MessageModel(
  //         messageId: '',
  //         senderId: currentUser.uid,
  //         receiverId: receiverId,
  //         message: 'Image', // Placeholder text for image messages
  //         timestamp: now,
  //         isRead: false,
  //         type: MessageType.image,
  //         imageUrl: downloadUrl,
  //       );
  //
  //       // Create chat room ID (consistent ordering)
  //       String chatRoomId = _createChatRoomId(currentUser.uid, receiverId);
  //
  //       print('Sending image message to chat room: $chatRoomId');
  //
  //       // Add message to chat room
  //       final messageRef = _database.child('chats/$chatRoomId/messages').push();
  //       await messageRef.set({
  //         ...messageData.toJson(),
  //         'messageId': messageRef.key,
  //         'serverTimestamp': ServerValue.timestamp,
  //       });
  //
  //       // Update last message info
  //       await _database.child('chats/$chatRoomId/lastMessage').set({
  //         'message': 'Image',
  //         'senderId': currentUser.uid,
  //         'timestamp': ServerValue.timestamp,
  //         'messageId': messageRef.key,
  //         'type': 'image',
  //       });
  //
  //       // Update chat participants info
  //       await _database.child('chats/$chatRoomId/participants').set({
  //         currentUser.uid: true,
  //         receiverId: true,
  //       });
  //
  //       print('Image message sent successfully with ID: ${messageRef.key}');
  //
  //     } catch (storageError) {
  //       print('Firebase Storage error: $storageError');
  //
  //       // Provide more specific error messages
  //       String errorMessage = 'Failed to upload image';
  //
  //       if (storageError.toString().contains('object-not-found')) {
  //         errorMessage = 'Storage bucket not found. Please check Firebase Storage configuration.';
  //       } else if (storageError.toString().contains('unauthorized')) {
  //         errorMessage = 'Storage access denied. Please check Firebase Storage rules.';
  //       } else if (storageError.toString().contains('network')) {
  //         errorMessage = 'Network error. Please check your internet connection.';
  //       }
  //
  //       throw Exception(errorMessage);
  //     }
  //
  //   } catch (e) {
  //     print('Error sending image message: $e');
  //     print('Stack trace: ${StackTrace.current}');
  //     rethrow;
  //   }
  // }

  // Get messages for a chat
  //Streams all messages from DB for that chat room.
  // Converts to MessageModel list.
  // Sorts by timestamp.
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

      //Get All Messages from That Sender
      DatabaseEvent event = await _database
          .child('chats/$chatRoomId/messages')
          .orderByChild('senderId')
          .equalTo(senderId)
          .once();
      
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> messages = 
            event.snapshot.value as Map<dynamic, dynamic>;

        //For every message that isn’t read yet.set isRead = true
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

  // Stream unread message count in real-time
  Stream<int> streamUnreadMessageCount(String senderId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    final String chatRoomId = _createChatRoomId(currentUser.uid, senderId);

    return _database
        .child('chats/$chatRoomId/messages')
        .orderByChild('senderId')
        .equalTo(senderId)
        .onValue
        .map((event) {
      int unreadCount = 0;
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> messages =
            event.snapshot.value as Map<dynamic, dynamic>;
        messages.forEach((key, value) {
          if (value['isRead'] == false) {
            unreadCount++;
          }
        });
      }
      return unreadCount;
    });
  }
}
