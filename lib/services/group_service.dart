import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

// GroupService: handles all group-related operations such as creation, membership management,
// sending/receiving messages, unread counts, and syncing group data in Firebase Realtime Database.
class GroupService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GroupService() {
    // Keep group and group_messages data synced (mobile only)
    if (!kIsWeb) {
      try {
        _database.child('groups').keepSynced(true);
        _database.child('group_messages').keepSynced(true);
        print('Group data keepSynced enabled for mobile');
      } catch (e) {
        print('Group keepSynced not supported: $e');
      }
    }
  }

  // Create a new group with members and initialize chat structure
  Future<String?> createGroup({
    required String groupName,
    required String groupDescription,
    required List<String> memberIds,
    String groupImage = '',
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final now = DateTime.now();
      final groupRef = _database.child('groups').push();
      final groupId = groupRef.key!;

      // Add creator as admin and member
      List<String> allMembers = [currentUser.uid, ...memberIds];
      List<String> admins = [currentUser.uid];

      final group = GroupModel(
        groupId: groupId,
        groupName: groupName,
        groupDescription: groupDescription,
        groupImage: groupImage,
        createdBy: currentUser.uid,
        createdAt: now,
        members: allMembers,
        admins: admins,
        lastMessageTime: now,
      );

      // Save group data
      await groupRef.set({
        ...group.toJson(),
        'serverTimestamp': ServerValue.timestamp,
        'createdTimestamp': ServerValue.timestamp,
      });

      // Initialize group messages with system placeholder
      await _database.child('group_messages/$groupId').set({
        'groupId': groupId,
        'createdAt': ServerValue.timestamp,
        'messages': {
          'placeholder': {
            'message': 'Group created',
            'senderId': 'system',
            'timestamp': ServerValue.timestamp,
            'isSystem': true,
          }
        }
      });

      // Add group reference to each member's profile
      for (String memberId in allMembers) {
        await _database.child('users/$memberId/groups').child(groupId).set({
          'joinedAt': ServerValue.timestamp,
          'isActive': true,
          'groupName': groupName,
        });
      }

      print('Group created successfully: $groupId');
      return groupId;
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }

  // Stream all groups that current user belongs to
  Stream<List<GroupModel>> getUserGroups() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _database.child('groups').onValue.map((event) {
      List<GroupModel> groups = [];
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> groupsData = event.snapshot.value as Map<dynamic, dynamic>;

        groupsData.forEach((key, value) {
          try {
            Map<String, dynamic> groupMap = Map<String, dynamic>.from(value);
            GroupModel group = GroupModel.fromJson(groupMap, key);
            if (group.isActive && group.isMember(currentUser.uid)) {
              groups.add(group);
            }
          } catch (e) {
            print('Error parsing group $key: $e');
          }
        });

        // Sort by last message time or creation date
        groups.sort((a, b) {
          if (a.lastMessage.isEmpty && b.lastMessage.isEmpty) {
            return b.createdAt.compareTo(a.createdAt);
          }
          return b.lastMessageTime.compareTo(a.lastMessageTime);
        });
      }
      return groups;
    });
  }

  // Send a message to a group
  Future<void> sendGroupMessage(String groupId, String message) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      final messageData = MessageModel(
        messageId: '',
        senderId: currentUser.uid,
        receiverId: groupId,
        message: message,
        timestamp: now,
        isRead: false,
      );

      // Add to group messages
      final messageRef = _database.child('group_messages/$groupId/messages').push();
      await messageRef.set({
        ...messageData.toJson(),
        'messageId': messageRef.key,
        'serverTimestamp': ServerValue.timestamp,
      });

      // Update last message details
      await _database.child('groups/$groupId').update({
        'lastMessage': message,
        'lastMessageTime': ServerValue.timestamp,
        'lastMessageSenderId': currentUser.uid,
      });
    } catch (e) {
      print('Error sending group message: $e');
      rethrow;
    }
  }

  // Stream messages of a group
  Stream<List<MessageModel>> getGroupMessages(String groupId) {
    return _database.child('group_messages/$groupId/messages').onValue.map((event) {
      List<MessageModel> messages = [];
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> messagesData = event.snapshot.value as Map<dynamic, dynamic>;
        messagesData.forEach((key, value) {
          try {
            Map<String, dynamic> messageMap = Map<String, dynamic>.from(value);
            messageMap['messageId'] = key;
            messages.add(MessageModel.fromJson(messageMap));
          } catch (e) {
            print('Error parsing message $key: $e');
          }
        });
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      return messages;
    });
  }

  // Get group by ID
  Future<GroupModel?> getGroupById(String groupId) async {
    try {
      DatabaseEvent event = await _database.child('groups/$groupId').once();
      if (event.snapshot.value != null) {
        Map<String, dynamic> groupData = Map<String, dynamic>.from(event.snapshot.value as Map);
        return GroupModel.fromJson(groupData, groupId);
      }
      return null;
    } catch (e) {
      print('Error getting group by ID: $e');
      return null;
    }
  }

  // Add member (admin-only)
  Future<bool> addMemberToGroup(String groupId, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      GroupModel? group = await getGroupById(groupId);
      if (group == null || !group.isAdmin(currentUser.uid)) return false;

      if (group.members.contains(userId)) return true;

      List<String> updatedMembers = [...group.members, userId];
      await _database.child('groups/$groupId/members').set(updatedMembers);

      await _database.child('users/$userId/groups').child(groupId).set({
        'joinedAt': ServerValue.timestamp,
        'isActive': true,
        'groupName': group.groupName,
      });

      return true;
    } catch (e) {
      print('Error adding member: $e');
      return false;
    }
  }

  // Remove member (admin-only)
  Future<bool> removeMemberFromGroup(String groupId, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      GroupModel? group = await getGroupById(groupId);
      if (group == null || !group.isAdmin(currentUser.uid)) return false;

      List<String> updatedMembers = group.members.where((id) => id != userId).toList();
      await _database.child('groups/$groupId/members').set(updatedMembers);

      if (group.isAdmin(userId)) {
        List<String> updatedAdmins = group.admins.where((id) => id != userId).toList();
        await _database.child('groups/$groupId/admins').set(updatedAdmins);
      }

      await _database.child('users/$userId/groups').child(groupId).remove();
      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  // Leave group (for current user)
  Future<bool> leaveGroup(String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    return await removeMemberFromGroup(groupId, currentUser.uid);
  }

  // Delete group (creator-only)
  Future<bool> deleteGroup(String groupId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      GroupModel? group = await getGroupById(groupId);
      if (group == null || group.createdBy != currentUser.uid) return false;

      for (String memberId in group.members) {
        await _database.child('users/$memberId/groups').child(groupId).remove();
      }

      await _database.child('group_messages/$groupId').remove();
      await _database.child('groups/$groupId').remove();
      return true;
    } catch (e) {
      print('Error deleting group: $e');
      return false;
    }
  }

  // Helper: get user details by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      DatabaseEvent event = await _database.child('users/$userId').once();
      if (event.snapshot.value != null) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(event.snapshot.value as Map);
        return UserModel.fromJson(userData, userId);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Get full member details of a group
  Future<List<UserModel>> getGroupMembersDetails(String groupId) async {
    try {
      GroupModel? group = await getGroupById(groupId);
      if (group == null) return [];

      List<UserModel> members = [];
      for (String memberId in group.members) {
        UserModel? user = await getUserById(memberId);
        if (user != null) members.add(user);
      }
      return members;
    } catch (e) {
      print('Error getting members: $e');
      return [];
    }
  }

  // Stream unread count for current user in a group
  Stream<int> streamGroupUnreadCount(String groupId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    final userGroupRef = _database.child('users/${currentUser.uid}/groups/$groupId');
    final messagesRef = _database.child('group_messages/$groupId/messages');

    return userGroupRef.onValue.asyncExpand((userSnap) {
      int lastReadAt = 0;
      if (userSnap.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(userSnap.snapshot.value as Map);
        lastReadAt = (data['lastReadAt'] ?? 0) as int;
      }

      return messagesRef.onValue.map((msgSnap) {
        int count = 0;
        if (msgSnap.snapshot.value != null) {
          final Map<dynamic, dynamic> messages = msgSnap.snapshot.value as Map;
          messages.forEach((key, value) {
            try {
              final Map<String, dynamic> m = Map<String, dynamic>.from(value);
              final int ts = (m['timestamp'] ?? 0) as int;
              final String senderId = (m['senderId'] ?? '') as String;
              if (senderId != currentUser.uid && ts > lastReadAt) count++;
            } catch (_) {}
          });
        }
        return count;
      });
    });
  }

  // Mark messages as read for current user
  Future<void> markGroupAsRead(String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      await _database.child('users/${currentUser.uid}/groups/$groupId').update({
        'lastReadAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error marking read: $e');
    }
  }

  // Delete a group message (only allows deleting own messages)
  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // First, verify that the message belongs to the current user
      final DatabaseEvent messageEvent = await _database
          .child('group_messages/$groupId/messages/$messageId')
          .once();

      if (messageEvent.snapshot.value == null) {
        print('Message not found: $messageId');
        return;
      }

      final Map<String, dynamic> messageData =
          Map<String, dynamic>.from(messageEvent.snapshot.value as Map);

      // Security check: Only allow deleting own messages
      if (messageData['senderId'] != currentUser.uid) {
        print('Cannot delete message: User is not the sender');
        return;
      }

      // Remove the message from the group messages
      await _database
          .child('group_messages/$groupId/messages/$messageId')
          .remove();

      // Update group's last message if the deleted message was the last one
      final DatabaseEvent remainingMessagesEvent = await _database
          .child('group_messages/$groupId/messages')
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

        await _database.child('groups/$groupId').update({
          'lastMessage': lastMessage.message,
          'lastMessageTime': lastMessage.timestamp.millisecondsSinceEpoch,
          'lastMessageSenderId': lastMessage.senderId,
        });
      } else {
        // No messages left in this group, clear the lastMessage fields
        await _database.child('groups/$groupId').update({
          'lastMessage': '',
          'lastMessageTime': ServerValue.timestamp,
          'lastMessageSenderId': '',
        });
      }
    } catch (e) {
      print('Error deleting group message: $e');
      rethrow;
    }
  }
}




// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart';
// import '../models/group_model.dart';
// import '../models/message_model.dart';
// import '../models/user_model.dart';
//
// class GroupService {
//   final DatabaseReference _database = FirebaseDatabase.instance.ref();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   GroupService() {
//     // Keep groups data synced (only on mobile platforms)
//     if (!kIsWeb) {
//       try {
//         _database.child('groups').keepSynced(true);
//         _database.child('group_messages').keepSynced(true);
//         print('Group data keepSynced enabled for mobile');
//       } catch (e) {
//         print('Group keepSynced not supported: $e');
//       }
//     }
//   }
//
//   // Create a new group
//   Future<String?> createGroup({
//     required String groupName,
//     required String groupDescription,
//     required List<String> memberIds,
//     String groupImage = '',
//   }) async {
//     try {
//       final currentUser = _auth.currentUser;
//       if (currentUser == null) {
//         print('Error: No current user when creating group');
//         return null;
//       }
//
//       final now = DateTime.now();
//       final groupRef = _database.child('groups').push();
//       final groupId = groupRef.key!;
//
//       // Add creator to members and admins
//       List<String> allMembers = [currentUser.uid, ...memberIds];
//       List<String> admins = [currentUser.uid]; // Creator is admin
//
//       final group = GroupModel(
//         groupId: groupId,
//         groupName: groupName,
//         groupDescription: groupDescription,
//         groupImage: groupImage,
//         createdBy: currentUser.uid,
//         createdAt: now,
//         members: allMembers,
//         admins: admins,
//         lastMessageTime: now,
//       );
//
//       // Create the group with all necessary fields
//       await groupRef.set({
//         ...group.toJson(),
//         'serverTimestamp': ServerValue.timestamp,
//         'createdTimestamp': ServerValue.timestamp,
//       });
//
//       // Initialize the group messages structure
//       await _database
//           .child('group_messages/$groupId')
//           .set({
//         'groupId': groupId,
//         'createdAt': ServerValue.timestamp,
//         'messages': {
//           'placeholder': {
//             'message': 'Group created',
//             'senderId': 'system',
//             'timestamp': ServerValue.timestamp,
//             'isSystem': true,
//           }
//         }
//       });
//
//       // Add group reference to each member's profile with more detail
//       for (String memberId in allMembers) {
//         await _database
//             .child('users/$memberId/groups')
//             .child(groupId)
//             .set({
//           'joinedAt': ServerValue.timestamp,
//           'isActive': true,
//           'groupName': groupName,
//         });
//       }
//
//       print('Group created successfully with ID: $groupId and initialized messages structure');
//       return groupId;
//     } catch (e) {
//       print('Error creating group: $e');
//       return null;
//     }
//   }
//
//   // Get user's groups with better persistence
//   Stream<List<GroupModel>> getUserGroups() {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return const Stream.empty();
//
//     return _database
//         .child('groups')
//         .onValue
//         .map((event) {
//       List<GroupModel> groups = [];
//
//       if (event.snapshot.value != null) {
//         Map<dynamic, dynamic> groupsData =
//             event.snapshot.value as Map<dynamic, dynamic>;
//
//         groupsData.forEach((key, value) {
//           try {
//             Map<String, dynamic> groupMap = Map<String, dynamic>.from(value);
//             GroupModel group = GroupModel.fromJson(groupMap, key);
//
//             // Only include active groups where current user is a member
//             if (group.isActive && group.isMember(currentUser.uid)) {
//               groups.add(group);
//               print('Loaded group: ${group.groupName} with ${group.memberCount} members');
//             }
//           } catch (e) {
//             print('Error parsing group $key: $e');
//           }
//         });
//
//         // Sort groups by last message time (most recent first), then by creation date
//         groups.sort((a, b) {
//           if (a.lastMessage.isEmpty && b.lastMessage.isEmpty) {
//             return b.createdAt.compareTo(a.createdAt);
//           }
//           return b.lastMessageTime.compareTo(a.lastMessageTime);
//         });
//
//         print('Total groups loaded for user: ${groups.length}');
//       }
//
//       return groups;
//     });
//   }
//
//   // Send message to group
//   Future<void> sendGroupMessage(String groupId, String message) async {
//     try {
//       final currentUser = _auth.currentUser;
//       if (currentUser == null) {
//         print('Error: No current user when sending group message');
//         return;
//       }
//
//       final now = DateTime.now();
//       final messageData = MessageModel(
//         messageId: '',
//         senderId: currentUser.uid,
//         receiverId: groupId, // For group messages, receiver is group ID
//         message: message,
//         timestamp: now,
//         isRead: false,
//       );
//
//       // Add message to group messages
//       final messageRef = _database.child('group_messages/$groupId/messages').push();
//       await messageRef.set({
//         ...messageData.toJson(),
//         'messageId': messageRef.key,
//         'serverTimestamp': ServerValue.timestamp,
//       });
//
//       // Update group's last message info
//       await _database.child('groups/$groupId').update({
//         'lastMessage': message,
//         'lastMessageTime': ServerValue.timestamp,
//         'lastMessageSenderId': currentUser.uid,
//       });
//
//       print('Group message sent successfully with ID: ${messageRef.key}');
//     } catch (e) {
//       print('Error sending group message: $e');
//       rethrow;
//     }
//   }
//
//   // Get messages for a group with better persistence
//   Stream<List<MessageModel>> getGroupMessages(String groupId) {
//     print('Loading messages for group: $groupId');
//     return _database
//         .child('group_messages/$groupId/messages')
//         .onValue
//         .map((event) {
//       List<MessageModel> messages = [];
//
//       if (event.snapshot.value != null) {
//         Map<dynamic, dynamic> messagesData =
//             event.snapshot.value as Map<dynamic, dynamic>;
//
//         messagesData.forEach((key, value) {
//           try {
//             Map<String, dynamic> messageMap = Map<String, dynamic>.from(value);
//             messageMap['messageId'] = key;
//             messages.add(MessageModel.fromJson(messageMap));
//           } catch (e) {
//             print('Error parsing message $key in group $groupId: $e');
//           }
//         });
//
//         // Sort messages by timestamp (oldest first for chat display)
//         messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
//         print('Loaded ${messages.length} messages for group $groupId');
//       } else {
//         print('No messages found for group $groupId');
//       }
//
//       return messages;
//     });
//   }
//
//   // Get group by ID
//   Future<GroupModel?> getGroupById(String groupId) async {
//     try {
//       DatabaseEvent event = await _database.child('groups/$groupId').once();
//
//       if (event.snapshot.value != null) {
//         Map<String, dynamic> groupData = Map<String, dynamic>.from(
//           event.snapshot.value as Map<dynamic, dynamic>
//         );
//         return GroupModel.fromJson(groupData, groupId);
//       }
//       return null;
//     } catch (e) {
//       print('Error getting group by ID: $e');
//       return null;
//     }
//   }
//
//   // Add member to group
//   Future<bool> addMemberToGroup(String groupId, String userId) async {
//     try {
//       final currentUser = _auth.currentUser;
//       if (currentUser == null) return false;
//
//       // Check if current user is admin
//       GroupModel? group = await getGroupById(groupId);
//       if (group == null || !group.isAdmin(currentUser.uid)) {
//         print('User is not admin of this group');
//         return false;
//       }
//
//       // Avoid duplicate add
//       if (group.members.contains(userId)) {
//         print('User already a member of this group');
//         return true;
//       }
//
//       // Add user to members list
//       List<String> updatedMembers = [...group.members, userId];
//       await _database.child('groups/$groupId/members').set(updatedMembers);
//
//       // Add group reference to user's profile
//       await _database.child('users/$userId/groups').child(groupId).set({
//         'joinedAt': ServerValue.timestamp,
//         'isActive': true,
//         'groupName': group.groupName,
//       });
//
//       print('Member added to group successfully');
//       return true;
//     } catch (e) {
//       print('Error adding member to group: $e');
//       return false;
//     }
//   }
//
//   // Remove member from group
//   Future<bool> removeMemberFromGroup(String groupId, String userId) async {
//     try {
//       final currentUser = _auth.currentUser;
//       if (currentUser == null) return false;
//
//       // Check if current user is admin
//       GroupModel? group = await getGroupById(groupId);
//       if (group == null || !group.isAdmin(currentUser.uid)) {
//         print('User is not admin of this group');
//         return false;
//       }
//
//       // Remove user from members list
//       List<String> updatedMembers = group.members.where((id) => id != userId).toList();
//       await _database.child('groups/$groupId/members').set(updatedMembers);
//
//       // Remove user from admins list if they are admin
//       if (group.isAdmin(userId)) {
//         List<String> updatedAdmins = group.admins.where((id) => id != userId).toList();
//         await _database.child('groups/$groupId/admins').set(updatedAdmins);
//       }
//
//       // Remove group reference from user's profile
//       await _database.child('users/$userId/groups').child(groupId).remove();
//
//       print('Member removed from group successfully');
//       return true;
//     } catch (e) {
//       print('Error removing member from group: $e');
//       return false;
//     }
//   }
//
//   // Leave group
//   Future<bool> leaveGroup(String groupId) async {
//     try {
//       final currentUser = _auth.currentUser;
//       if (currentUser == null) return false;
//
//       return await removeMemberFromGroup(groupId, currentUser.uid);
//     } catch (e) {
//       print('Error leaving group: $e');
//       return false;
//     }
//   }
//
//   // Delete group (only creator can delete)
//   Future<bool> deleteGroup(String groupId) async {
//     try {
//       final currentUser = _auth.currentUser;
//       if (currentUser == null) return false;
//
//       GroupModel? group = await getGroupById(groupId);
//       if (group == null || group.createdBy != currentUser.uid) {
//         print('Only group creator can delete the group');
//         return false;
//       }
//
//       // Remove group from all members' profiles
//       for (String memberId in group.members) {
//         await _database.child('users/$memberId/groups').child(groupId).remove();
//       }
//
//       // Delete group messages
//       await _database.child('group_messages/$groupId').remove();
//
//       // Delete group
//       await _database.child('groups/$groupId').remove();
//
//       print('Group deleted successfully');
//       return true;
//     } catch (e) {
//       print('Error deleting group: $e');
//       return false;
//     }
//   }
//
//   // Get user by ID (helper method)
//   Future<UserModel?> getUserById(String userId) async {
//     try {
//       DatabaseEvent event = await _database.child('users/$userId').once();
//
//       if (event.snapshot.value != null) {
//         Map<String, dynamic> userData = Map<String, dynamic>.from(
//           event.snapshot.value as Map<dynamic, dynamic>
//         );
//         return UserModel.fromJson(userData, userId);
//       }
//       return null;
//     } catch (e) {
//       print('Error getting user by ID: $e');
//       return null;
//     }
//   }
//
//   // Get group members details
//   Future<List<UserModel>> getGroupMembersDetails(String groupId) async {
//     try {
//       GroupModel? group = await getGroupById(groupId);
//       if (group == null) return [];
//
//       List<UserModel> members = [];
//       for (String memberId in group.members) {
//         UserModel? user = await getUserById(memberId);
//         if (user != null) {
//           members.add(user);
//         }
//       }
//
//       return members;
//     } catch (e) {
//       print('Error getting group members details: $e');
//       return [];
//     }
//   }
//
//   // Stream unread message count for a group for current user
//   Stream<int> streamGroupUnreadCount(String groupId) {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return const Stream.empty();
//
//     final userGroupRef = _database.child('users/${currentUser.uid}/groups/$groupId');
//     final messagesRef = _database.child('group_messages/$groupId/messages');
//
//     // Combine both streams: lastReadAt and messages
//     return userGroupRef.onValue.asyncExpand((userSnap) {
//       int lastReadAt = 0;
//       if (userSnap.snapshot.value != null) {
//         final data = Map<dynamic, dynamic>.from(userSnap.snapshot.value as Map);
//         lastReadAt = (data['lastReadAt'] ?? 0) as int;
//       }
//
//       return messagesRef.onValue.map((msgSnap) {
//         int count = 0;
//         if (msgSnap.snapshot.value != null) {
//           final Map<dynamic, dynamic> messages =
//               msgSnap.snapshot.value as Map<dynamic, dynamic>;
//           messages.forEach((key, value) {
//             try {
//               final Map<String, dynamic> m = Map<String, dynamic>.from(value);
//               final int ts = (m['timestamp'] ?? 0) as int;
//               final String senderId = (m['senderId'] ?? '') as String;
//               if (senderId != currentUser.uid && ts > lastReadAt) {
//                 count++;
//               }
//             } catch (_) {}
//           });
//         }
//         return count;
//       });
//     });
//   }
//
//   // Mark group messages as read by setting lastReadAt for the user
//   Future<void> markGroupAsRead(String groupId) async {
//     final currentUser = _auth.currentUser;
//     if (currentUser == null) return;
//     try {
//       await _database.child('users/${currentUser.uid}/groups/$groupId').update({
//         'lastReadAt': ServerValue.timestamp,
//       });
//     } catch (e) {
//       print('Error marking group as read: $e');
//     }
//   }
// }
