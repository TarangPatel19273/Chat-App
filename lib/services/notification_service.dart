import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

// NotificationService: handles creating, reading, updating, and listening to
// notification entries in Firebase Realtime Database for the current user.
class NotificationService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  NotificationService() {
    // Keep notifications synced to disk when running on mobile (not web)
    if (!kIsWeb) {
      try {
        _database.child('notifications').keepSynced(true);
        print('Notifications keepSynced enabled for mobile');
      } catch (e) {
        print('Notifications keepSynced not supported: $e');
      }
    }
  }

  // Generic sendNotification helper to push a notification node under /notifications/<toUserId>
  Future<bool> sendNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        userId: toUserId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        type: type,
        title: title,
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
        data: data,
      );

      // Push a new notification node for the target user
      final notificationRef = _database
          .child('notifications')
          .child(toUserId)
          .push();

      await notificationRef.set({
        ...notification.toJson(),
        'id': notificationRef.key,
        'serverTimestamp': ServerValue.timestamp,
      });

      print('Notification sent: $title to $toUserId');
      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  // Convenience method to notify a user that they were added as a friend
  Future<bool> sendFriendAddedNotification({
    required String friendUserId,
    required String currentUserName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    return await sendNotification(
      toUserId: friendUserId,
      fromUserId: currentUser.uid,
      fromUserName: currentUserName,
      type: 'friend_added',
      title: 'New Friend Added! 👥',
      message: '$currentUserName added you as a friend',
      data: {
        'friendId': currentUser.uid,
        'friendName': currentUserName,
      },
    );
  }

  // Stream notifications for current user (limited to last 50, newest first)
  Stream<List<NotificationModel>> getNotificationsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _database
        .child('notifications')
        .child(currentUser.uid)
        .orderByChild('timestamp')
        .limitToLast(50) // Limit to last 50 notifications
        .onValue
        .map((event) {
      List<NotificationModel> notifications = [];

      if (event.snapshot.value != null) {
        final notificationsData = event.snapshot.value as Map<dynamic, dynamic>;

        notificationsData.forEach((key, value) {
          try {
            final notificationMap = Map<String, dynamic>.from(value);
            notifications.add(NotificationModel.fromJson(notificationMap, key));
          } catch (e) {
            print('Error parsing notification: $e');
          }
        });

        // Sort by timestamp (newest first)
        notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      return notifications;
    });
  }

  // Stream the unread notifications count derived from the notifications stream
  Stream<int> getUnreadNotificationsCount() {
    return getNotificationsStream().map((notifications) {
      return notifications.where((notification) => !notification.isRead).length;
    });
  }

  // Mark a single notification as read by updating its isRead flag
  Future<void> markNotificationAsRead(String notificationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _database
          .child('notifications')
          .child(currentUser.uid)
          .child(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications for the current user as read in a single multi-path update
  Future<void> markAllNotificationsAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await _database
          .child('notifications')
          .child(currentUser.uid)
          .once();

      if (snapshot.snapshot.value != null) {
        final notifications = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final updates = <String, dynamic>{};

        // Build a multi-path update for any unread notifications
        notifications.forEach((key, value) {
          if (value['isRead'] == false) {
            updates['notifications/${currentUser.uid}/$key/isRead'] = true;
          }
        });

        if (updates.isNotEmpty) {
          await _database.update(updates);
        }
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _database
          .child('notifications')
          .child(currentUser.uid)
          .child(notificationId)
          .remove();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications for the current user
  Future<void> clearAllNotifications() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _database
          .child('notifications')
          .child(currentUser.uid)
          .remove();
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }

  // Helper to create consistent chat room IDs (used by message-notification logic)
  String _createChatRoomId(String userId1, String userId2) {
    List<String> users = [userId1, userId2];
    users.sort(); // Ensure consistent ordering
    return users.join('_');
  }

  // Listen for newly added notifications and call back when a recent notification arrives
  void listenForNewNotifications({
    required Function(NotificationModel) onNewNotification,
  }) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _database
        .child('notifications')
        .child(currentUser.uid)
        .orderByChild('timestamp')
        .limitToLast(1)
        .onChildAdded
        .listen((event) {
      try {
        final notificationData = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>
        );
        final notification = NotificationModel.fromJson(
            notificationData,
            event.snapshot.key!
        );

        // Trigger callback only for notifications created within last 5 seconds
        if (DateTime.now().difference(notification.timestamp).inSeconds < 5) {
          onNewNotification(notification);
        }
      } catch (e) {
        print('Error processing new notification: $e');
      }
    });
  }
}




// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart';
// import '../models/notification_model.dart';
//
// class NotificationService {
//   final DatabaseReference _database = FirebaseDatabase.instance.ref();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   NotificationService() {
//     // Keep notifications synced (only on mobile platforms)
//     if (!kIsWeb) {
//       try {
//         _database.child('notifications').keepSynced(true);
//         print('Notifications keepSynced enabled for mobile');
//       } catch (e) {
//         print('Notifications keepSynced not supported: $e');
//       }
//     }
//   }
//
//   // Send a notification
//   Future<bool> sendNotification({
//     required String toUserId,
//     required String fromUserId,
//     required String fromUserName,
//     required String type,
//     required String title,
//     required String message,
//     Map<String, dynamic> data = const {},
//   }) async {
//     try {
//       final notification = NotificationModel(
//         id: '',
//         userId: toUserId,
//         fromUserId: fromUserId,
//         fromUserName: fromUserName,
//         type: type,
//         title: title,
//         message: message,
//         timestamp: DateTime.now(),
//         isRead: false,
//         data: data,
//       );
//
//       final notificationRef = _database
//           .child('notifications')
//           .child(toUserId)
//           .push();
//
//       await notificationRef.set({
//         ...notification.toJson(),
//         'id': notificationRef.key,
//         'serverTimestamp': ServerValue.timestamp,
//       });
//
//       print('Notification sent: $title to $toUserId');
//       return true;
//     } catch (e) {
//       print('Error sending notification: $e');
//       return false;
//     }
//   }
//
//   // Send friend added notification
//   Future<bool> sendFriendAddedNotification({
//     required String friendUserId,
//     required String currentUserName,
//   }) async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return false;
//
//     return await sendNotification(
//       toUserId: friendUserId,
//       fromUserId: currentUser.uid,
//       fromUserName: currentUserName,
//       type: 'friend_added',
//       title: 'New Friend Added! 👥',
//       message: '$currentUserName added you as a friend',
//       data: {
//         'friendId': currentUser.uid,
//         'friendName': currentUserName,
//       },
//     );
//   }
//
//   // Send message notification (disabled for now - only friend notifications)
//   // Future<bool> sendMessageNotification({
//   //   required String toUserId,
//   //   required String fromUserName,
//   //   required String messageContent,
//   // }) async {
//   //   final currentUser = _auth.currentUser;
//   //   if (currentUser == null) return false;
//
//   //   return await sendNotification(
//   //     toUserId: toUserId,
//   //     fromUserId: currentUser.uid,
//   //     fromUserName: fromUserName,
//   //     type: 'message',
//   //     title: 'New Message 💬',
//   //     message: '$fromUserName: ${messageContent.length > 50 ? messageContent.substring(0, 50) + '...' : messageContent}',
//   //     data: {
//   //       'messageContent': messageContent,
//   //       'chatRoomId': _createChatRoomId(currentUser.uid, toUserId),
//   //     },
//   //   );
//   // }
//
//   // Get notifications stream for current user
//   Stream<List<NotificationModel>> getNotificationsStream() {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return const Stream.empty();
//
//     return _database
//         .child('notifications')
//         .child(currentUser.uid)
//         .orderByChild('timestamp')
//         .limitToLast(50) // Limit to last 50 notifications
//         .onValue
//         .map((event) {
//       List<NotificationModel> notifications = [];
//
//       if (event.snapshot.value != null) {
//         final notificationsData = event.snapshot.value as Map<dynamic, dynamic>;
//
//         notificationsData.forEach((key, value) {
//           try {
//             final notificationMap = Map<String, dynamic>.from(value);
//             notifications.add(NotificationModel.fromJson(notificationMap, key));
//           } catch (e) {
//             print('Error parsing notification: $e');
//           }
//         });
//
//         // Sort by timestamp (newest first)
//         notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//       }
//
//       return notifications;
//     });
//   }
//
//   // Get unread notifications count
//   Stream<int> getUnreadNotificationsCount() {
//     return getNotificationsStream().map((notifications) {
//       return notifications.where((notification) => !notification.isRead).length;
//     });
//   }
//
//   // Mark notification as read
//   Future<void> markNotificationAsRead(String notificationId) async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return;
//
//     try {
//       await _database
//           .child('notifications')
//           .child(currentUser.uid)
//           .child(notificationId)
//           .update({'isRead': true});
//     } catch (e) {
//       print('Error marking notification as read: $e');
//     }
//   }
//
//   // Mark all notifications as read
//   Future<void> markAllNotificationsAsRead() async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return;
//
//     try {
//       final snapshot = await _database
//           .child('notifications')
//           .child(currentUser.uid)
//           .once();
//
//       if (snapshot.snapshot.value != null) {
//         final notifications = snapshot.snapshot.value as Map<dynamic, dynamic>;
//         final updates = <String, dynamic>{};
//
//         notifications.forEach((key, value) {
//           if (value['isRead'] == false) {
//             updates['notifications/${currentUser.uid}/$key/isRead'] = true;
//           }
//         });
//
//         if (updates.isNotEmpty) {
//           await _database.update(updates);
//         }
//       }
//     } catch (e) {
//       print('Error marking all notifications as read: $e');
//     }
//   }
//
//   // Delete notification
//   Future<void> deleteNotification(String notificationId) async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return;
//
//     try {
//       await _database
//           .child('notifications')
//           .child(currentUser.uid)
//           .child(notificationId)
//           .remove();
//     } catch (e) {
//       print('Error deleting notification: $e');
//     }
//   }
//
//   // Clear all notifications
//   Future<void> clearAllNotifications() async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return;
//
//     try {
//       await _database
//           .child('notifications')
//           .child(currentUser.uid)
//           .remove();
//     } catch (e) {
//       print('Error clearing all notifications: $e');
//     }
//   }
//
//   // Helper method to create chat room ID
//   String _createChatRoomId(String userId1, String userId2) {
//     List<String> users = [userId1, userId2];
//     users.sort(); // Ensure consistent ordering
//     return users.join('_');
//   }
//
//   // Listen for new notifications and trigger callbacks
//   void listenForNewNotifications({
//     required Function(NotificationModel) onNewNotification,
//   }) {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return;
//
//     _database
//         .child('notifications')
//         .child(currentUser.uid)
//         .orderByChild('timestamp')
//         .limitToLast(1)
//         .onChildAdded
//         .listen((event) {
//       try {
//         final notificationData = Map<String, dynamic>.from(
//           event.snapshot.value as Map<dynamic, dynamic>
//         );
//         final notification = NotificationModel.fromJson(
//           notificationData,
//           event.snapshot.key!
//         );
//
//         // Only trigger for new notifications (less than 5 seconds old)
//         if (DateTime.now().difference(notification.timestamp).inSeconds < 5) {
//           onNewNotification(notification);
//         }
//       } catch (e) {
//         print('Error processing new notification: $e');
//       }
//     });
//   }
// }
