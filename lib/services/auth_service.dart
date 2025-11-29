import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class AuthService {
  // Firebase Auth instance for authentication operations.
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Root reference for Realtime Database.
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  // Notification service for sending notifications (push/in-app).
  final NotificationService _notificationService = NotificationService();

  AuthService() {
    // Monitor Realtime Database connection state and log changes.
    _database.child('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      print('Firebase Database connected: $connected');
    });
  }

  // Current authenticated Firebase user (nullable).
  User? get currentUser => _auth.currentUser;
  // Stream to listen for auth state changes (useful for AuthWrapper).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password + create user record in Realtime DB.
  Future<UserCredential?> registerWithEmailAndPassword(
      String email,
      String password,
      String displayName
      ) async {
    try {
      print('Starting registration for email: $email');

      // Create user in Firebase Auth.
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Firebase Auth user created: ${result.user?.uid}');

      User? user = result.user;
      if (user != null) {
        // Update the Firebase user's display name (profile).
        print('Updating display name to: $displayName');
        try {
          await user.updateProfile(
            displayName: displayName,
          );
          await user.reload();
        } catch (e) {
          print('Warning: Could not update display name in Auth profile: $e');
          // Continue with database creation even if Auth profile update fails
        }

        print('Creating user in database...');
        // Create a corresponding user node in Realtime Database.
        await _createUserInDatabase(user, displayName, email);
      }

      print('Registration completed successfully');
      return result;
    } on FirebaseAuthException catch (e) {
      // Rethrow auth exceptions so UI can show proper messages.
      print('Firebase Auth Registration error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      // Catch-all for unexpected errors during registration.
      print('General registration error: $e');
      print('Stack trace: ${StackTrace.current}');
      throw e;
    }
  }

  // Sign in with email and password; mark user as online after success.
  Future<UserCredential?> signInWithEmailAndPassword(
      String email,
      String password
      ) async {
    try {
      print('🔐 Starting sign-in for: $email');

      // Sign in using Firebase Auth.
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Firebase Auth sign-in successful');
      print('User: ${result.user?.email} (${result.user?.uid})');

      // Update user status to online in Realtime Database.
      if (result.user != null) {
        print('🔄 Updating user status to online...');
        await _updateUserStatus(result.user!.uid, true);
        print('✅ User status updated successfully');
      }

      print('✅ Sign-in completed successfully');
      return result;
    } on FirebaseAuthException catch (e) {
      // Log and rethrow so UI can display specific error message.
      print('❌ Firebase Auth sign-in error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('❌ General sign-in error: $e');
      throw e;
    }
  }

  // Sign out: attempt to mark user offline and then sign out from Auth.
  Future<void> signOut() async {
    try {
      print('🔓 Starting sign-out...');

      // Try updating user status to offline; continue sign-out even if it fails.
      if (currentUser != null) {
        print('🔄 Updating user status to offline for: ${currentUser!.email}');
        try {
          await _updateUserStatus(currentUser!.uid, false);
          print('✅ User status updated to offline');
        } catch (e) {
          print('⚠️ Warning: Could not update user status to offline: $e');
          // Continue with sign-out even if status update fails
        }
      }

      print('🗿 Calling Firebase Auth sign-out...');
      await _auth.signOut();
      print('✅ Firebase Auth sign-out completed successfully');

    } catch (e) {
      print('❌ Sign out error: $e');
      rethrow;
    }
  }

  // Create user record in Realtime Database after successful registration.
  Future<void> _createUserInDatabase(User user, String displayName, String email) async {
    try {
      UserModel userModel = UserModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        description: '',
        isOnline: true,
        lastSeen: DateTime.now(),
        friends: [],
      );

      print('Attempting to create user in database: ${user.uid}');
      print('User data: ${userModel.toJson()}');

      // Write the user model to /users/<uid>
      await _database.child('users/${user.uid}').set(userModel.toJson());
      print('User successfully created in database');
    } catch (e) {
      print('Error creating user in database: $e');
      print('Stack trace: ${StackTrace.current}');
      throw e;
    }
  }

  // Update user's online presence and last seen timestamp.
  Future<void> _updateUserStatus(String uid, bool isOnline) async {
    try {
      print('Updating user status: $uid -> isOnline: $isOnline');
      await _database.child('users/$uid').update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
      print('User status updated successfully');
    } catch (e) {
      print('Error updating user status: $e');
      throw e;
    }
  }

  // Query the database for a user by email.
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      DatabaseEvent event = await _database
          .child('users')
          .orderByChild('email')
          .equalTo(email)
          .once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> users = event.snapshot.value as Map<dynamic, dynamic>;
        String uid = users.keys.first;
        Map<String, dynamic> userData = Map<String, dynamic>.from(users[uid]);
        return UserModel.fromJson(userData, uid);
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  // Add a friend by their email address.
  Future<bool> addFriend(String friendEmail) async {
    try {
      if (currentUser == null) return false;

      String currentUid = currentUser!.uid;

      // Don't add yourself as a friend
      if (friendEmail.toLowerCase() == currentUser!.email?.toLowerCase()) {
        print('Cannot add yourself as a friend');
        return false;
      }

      // Find user by email
      UserModel? friend = await getUserByEmail(friendEmail);
      if (friend == null) {
        print('User with email $friendEmail not found');
        return false;
      }

      // Check if already friends
      UserModel? currentUserData = await getCurrentUserData();
      if (currentUserData != null && currentUserData.friends.contains(friend.uid)) {
        print('Already friends with ${friend.displayName}');
        return false;
      }

      // Add friend to current user's friends list (push adds a new key)
      await _database.child('users/$currentUid/friends').push().set(friend.uid);

      // Add current user to friend's friends list
      await _database.child('users/${friend.uid}/friends').push().set(currentUid);

      // Send notification to the friend informing them they were added.
      await _notificationService.sendFriendAddedNotification(
        friendUserId: friend.uid,
        currentUserName: currentUserData?.displayName ?? currentUser!.displayName ?? 'Someone',
      );

      print('Successfully added ${friend.displayName} as friend');
      return true;
    } catch (e) {
      print('Error adding friend: $e');
      return false;
    }
  }

  // Remove a friend by UID and clean up chat data.
  Future<bool> removeFriend(String friendUid) async {
    try {
      if (currentUser == null) {
        print('No current user found');
        return false;
      }

      final currentUid = currentUser!.uid;
      print('Removing friend: $friendUid from user: $currentUid');

      // Get current user's friends list to find the push key for this friend.
      DatabaseEvent currentUserEvent = await _database.child('users/$currentUid/friends').once();
      if (currentUserEvent.snapshot.value != null) {
        Map<dynamic, dynamic> friendsMap = currentUserEvent.snapshot.value as Map<dynamic, dynamic>;

        // Find and remove the friend from current user's friends list
        String? friendKey;
        for (var entry in friendsMap.entries) {
          if (entry.value == friendUid) {
            friendKey = entry.key;
            break;
          }
        }

        if (friendKey != null) {
          await _database.child('users/$currentUid/friends/$friendKey').remove();
          print('Removed friend from current user\'s friends list');
        }
      }

      // Get friend's friends list and remove current user similarly.
      DatabaseEvent friendEvent = await _database.child('users/$friendUid/friends').once();
      if (friendEvent.snapshot.value != null) {
        Map<dynamic, dynamic> friendsMap = friendEvent.snapshot.value as Map<dynamic, dynamic>;

        // Find and remove current user from friend's friends list
        String? currentUserKey;
        for (var entry in friendsMap.entries) {
          if (entry.value == currentUid) {
            currentUserKey = entry.key;
            break;
          }
        }

        if (currentUserKey != null) {
          await _database.child('users/$friendUid/friends/$currentUserKey').remove();
          print('Removed current user from friend\'s friends list');
        }
      }

      // Clean up chat data between the two users (this removes the entire chat).
      await _cleanupChatData(currentUid, friendUid);

      print('Successfully removed friend');
      return true;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }

  // Remove chat data when friends are removed (deletes chats/<chatRoomId>).
  Future<void> _cleanupChatData(String currentUid, String friendUid) async {
    try {
      // Create chat room ID (consistent ordering)
      String chatRoomId = _createChatRoomId(currentUid, friendUid);

      // Remove the chat room and all its messages
      await _database.child('chats/$chatRoomId').remove();
      print('Cleaned up chat data for chat room: $chatRoomId');
    } catch (e) {
      print('Error cleaning up chat data: $e');
      // Don't throw error - friend removal should succeed even if chat cleanup fails
    }
  }

  // Helper method to create consistent chat room ID by sorting UIDs.
  String _createChatRoomId(String uid1, String uid2) {
    // Sort the UIDs to ensure consistent chat room ID regardless of order
    List<String> sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}';
  }

  // Get current user's data from /users/<uid> node.
  Future<UserModel?> getCurrentUserData() async {
    try {
      if (currentUser == null) return null;

      DatabaseEvent event = await _database.child('users/${currentUser!.uid}').once();

      if (event.snapshot.value != null) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>
        );
        return UserModel.fromJson(userData, currentUser!.uid);
      }
      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  // Update user profile fields such as displayName and optional description.
  Future<void> updateUserProfile(String uid, String displayName, [String? description]) async {
    try {
      print('Updating user profile in database: $uid');
      print('New display name: $displayName');
      print('New description: $description');

      Map<String, dynamic> updateData = {
        'displayName': displayName,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      };

      if (description != null) {
        updateData['description'] = description;
      }

      await _database.child('users/$uid').update(updateData);

      print('Successfully updated user profile in database');
    } catch (e) {
      print('Error updating user profile in database: $e');
      throw e;
    }
  }
}


// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import '../models/user_model.dart';
// import 'notification_service.dart';
//
// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final DatabaseReference _database = FirebaseDatabase.instance.ref();
//   final NotificationService _notificationService = NotificationService();
//
//   AuthService() {
//     // Monitor database connection
//     _database.child('.info/connected').onValue.listen((event) {
//       final connected = event.snapshot.value as bool? ?? false;
//       print('Firebase Database connected: $connected');
//     });
//   }
//
//   User? get currentUser => _auth.currentUser;
//   Stream<User?> get authStateChanges => _auth.authStateChanges();
//
//   // Register with email and password
//   Future<UserCredential?> registerWithEmailAndPassword(
//     String email,
//     String password,
//     String displayName
//   ) async {
//     try {
//       print('Starting registration for email: $email');
//
//       UserCredential result = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//
//       print('Firebase Auth user created: ${result.user?.uid}');
//
//       User? user = result.user;
//       if (user != null) {
//         print('Updating display name to: $displayName');
//         // Update display name
//         await user.updateDisplayName(displayName);
//
//         print('Creating user in database...');
//         // Create user in Realtime Database
//         await _createUserInDatabase(user, displayName, email);
//       }
//
//       print('Registration completed successfully');
//       return result;
//     } on FirebaseAuthException catch (e) {
//       print('Firebase Auth Registration error: ${e.code} - ${e.message}');
//       throw e;
//     } catch (e) {
//       print('General registration error: $e');
//       print('Stack trace: ${StackTrace.current}');
//       throw e;
//     }
//   }
//
//   // Sign in with email and password
//   Future<UserCredential?> signInWithEmailAndPassword(
//     String email,
//     String password
//   ) async {
//     try {
//       print('🔐 Starting sign-in for: $email');
//
//       UserCredential result = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//
//       print('✅ Firebase Auth sign-in successful');
//       print('User: ${result.user?.email} (${result.user?.uid})');
//
//       // Update user status to online
//       if (result.user != null) {
//         print('🔄 Updating user status to online...');
//         await _updateUserStatus(result.user!.uid, true);
//         print('✅ User status updated successfully');
//       }
//
//       print('✅ Sign-in completed successfully');
//       return result;
//     } on FirebaseAuthException catch (e) {
//       print('❌ Firebase Auth sign-in error: ${e.code} - ${e.message}');
//       throw e;
//     } catch (e) {
//       print('❌ General sign-in error: $e');
//       throw e;
//     }
//   }
//
//   // Sign out
//   Future<void> signOut() async {
//     try {
//       print('🔓 Starting sign-out...');
//
//       // Update user status to offline (with error handling)
//       if (currentUser != null) {
//         print('🔄 Updating user status to offline for: ${currentUser!.email}');
//         try {
//           await _updateUserStatus(currentUser!.uid, false);
//           print('✅ User status updated to offline');
//         } catch (e) {
//           print('⚠️ Warning: Could not update user status to offline: $e');
//           // Continue with sign-out even if status update fails
//         }
//       }
//
//       print('🗿 Calling Firebase Auth sign-out...');
//       await _auth.signOut();
//       print('✅ Firebase Auth sign-out completed successfully');
//
//     } catch (e) {
//       print('❌ Sign out error: $e');
//       rethrow;
//     }
//   }
//
//   // Create user in database
//   Future<void> _createUserInDatabase(User user, String displayName, String email) async {
//     try {
//       UserModel userModel = UserModel(
//         uid: user.uid,
//         email: email,
//         displayName: displayName,
//         description: '',
//         isOnline: true,
//         lastSeen: DateTime.now(),
//         friends: [],
//       );
//
//       print('Attempting to create user in database: ${user.uid}');
//       print('User data: ${userModel.toJson()}');
//
//       await _database.child('users/${user.uid}').set(userModel.toJson());
//       print('User successfully created in database');
//     } catch (e) {
//       print('Error creating user in database: $e');
//       print('Stack trace: ${StackTrace.current}');
//       throw e;
//     }
//   }
//
//   // Update user online status
//   Future<void> _updateUserStatus(String uid, bool isOnline) async {
//     try {
//       print('Updating user status: $uid -> isOnline: $isOnline');
//       await _database.child('users/$uid').update({
//         'isOnline': isOnline,
//         'lastSeen': DateTime.now().millisecondsSinceEpoch,
//       });
//       print('User status updated successfully');
//     } catch (e) {
//       print('Error updating user status: $e');
//       throw e;
//     }
//   }
//
//   // Get user by email
//   Future<UserModel?> getUserByEmail(String email) async {
//     try {
//       DatabaseEvent event = await _database
//           .child('users')
//           .orderByChild('email')
//           .equalTo(email)
//           .once();
//
//       if (event.snapshot.value != null) {
//         Map<dynamic, dynamic> users = event.snapshot.value as Map<dynamic, dynamic>;
//         String uid = users.keys.first;
//         Map<String, dynamic> userData = Map<String, dynamic>.from(users[uid]);
//         return UserModel.fromJson(userData, uid);
//       }
//       return null;
//     } catch (e) {
//       print('Error getting user by email: $e');
//       return null;
//     }
//   }
//
//   // Add friend
//   Future<bool> addFriend(String friendEmail) async {
//     try {
//       if (currentUser == null) return false;
//
//       String currentUid = currentUser!.uid;
//
//       // Don't add yourself as a friend
//       if (friendEmail.toLowerCase() == currentUser!.email?.toLowerCase()) {
//         print('Cannot add yourself as a friend');
//         return false;
//       }
//
//       UserModel? friend = await getUserByEmail(friendEmail);
//       if (friend == null) {
//         print('User with email $friendEmail not found');
//         return false;
//       }
//
//       // Check if already friends
//       UserModel? currentUserData = await getCurrentUserData();
//       if (currentUserData != null && currentUserData.friends.contains(friend.uid)) {
//         print('Already friends with ${friend.displayName}');
//         return false;
//       }
//
//       // Add friend to current user's friends list
//       await _database.child('users/$currentUid/friends').push().set(friend.uid);
//
//       // Add current user to friend's friends list
//       await _database.child('users/${friend.uid}/friends').push().set(currentUid);
//
//       // Send notification to the friend
//       await _notificationService.sendFriendAddedNotification(
//         friendUserId: friend.uid,
//         currentUserName: currentUserData?.displayName ?? currentUser!.displayName ?? 'Someone',
//       );
//
//       print('Successfully added ${friend.displayName} as friend');
//       return true;
//     } catch (e) {
//       print('Error adding friend: $e');
//       return false;
//     }
//   }
//
//   // Remove friend
//   Future<bool> removeFriend(String friendUid) async {
//     try {
//       if (currentUser == null) {
//         print('No current user found');
//         return false;
//       }
//
//       final currentUid = currentUser!.uid;
//       print('Removing friend: $friendUid from user: $currentUid');
//
//       // Get current user's friends list
//       DatabaseEvent currentUserEvent = await _database.child('users/$currentUid/friends').once();
//       if (currentUserEvent.snapshot.value != null) {
//         Map<dynamic, dynamic> friendsMap = currentUserEvent.snapshot.value as Map<dynamic, dynamic>;
//
//         // Find and remove the friend from current user's friends list
//         String? friendKey;
//         for (var entry in friendsMap.entries) {
//           if (entry.value == friendUid) {
//             friendKey = entry.key;
//             break;
//           }
//         }
//
//         if (friendKey != null) {
//           await _database.child('users/$currentUid/friends/$friendKey').remove();
//           print('Removed friend from current user\'s friends list');
//         }
//       }
//
//       // Get friend's friends list and remove current user
//       DatabaseEvent friendEvent = await _database.child('users/$friendUid/friends').once();
//       if (friendEvent.snapshot.value != null) {
//         Map<dynamic, dynamic> friendsMap = friendEvent.snapshot.value as Map<dynamic, dynamic>;
//
//         // Find and remove current user from friend's friends list
//         String? currentUserKey;
//         for (var entry in friendsMap.entries) {
//           if (entry.value == currentUid) {
//             currentUserKey = entry.key;
//             break;
//           }
//         }
//
//         if (currentUserKey != null) {
//           await _database.child('users/$friendUid/friends/$currentUserKey').remove();
//           print('Removed current user from friend\'s friends list');
//         }
//       }
//
//       // Clean up chat data between the two users
//       await _cleanupChatData(currentUid, friendUid);
//
//       print('Successfully removed friend');
//       return true;
//     } catch (e) {
//       print('Error removing friend: $e');
//       return false;
//     }
//   }
//
//   // Clean up chat data when friends are removed
//   Future<void> _cleanupChatData(String currentUid, String friendUid) async {
//     try {
//       // Create chat room ID (consistent ordering)
//       String chatRoomId = _createChatRoomId(currentUid, friendUid);
//
//       // Remove the chat room and all its messages
//       await _database.child('chats/$chatRoomId').remove();
//       print('Cleaned up chat data for chat room: $chatRoomId');
//     } catch (e) {
//       print('Error cleaning up chat data: $e');
//       // Don't throw error - friend removal should succeed even if chat cleanup fails
//     }
//   }
//
//   // Helper method to create consistent chat room ID
//   String _createChatRoomId(String uid1, String uid2) {
//     // Sort the UIDs to ensure consistent chat room ID regardless of order
//     List<String> sortedUids = [uid1, uid2]..sort();
//     return '${sortedUids[0]}_${sortedUids[1]}';
//   }
//
//   // Get current user data
//   Future<UserModel?> getCurrentUserData() async {
//     try {
//       if (currentUser == null) return null;
//
//       DatabaseEvent event = await _database.child('users/${currentUser!.uid}').once();
//
//       if (event.snapshot.value != null) {
//         Map<String, dynamic> userData = Map<String, dynamic>.from(
//           event.snapshot.value as Map<dynamic, dynamic>
//         );
//         return UserModel.fromJson(userData, currentUser!.uid);
//       }
//       return null;
//     } catch (e) {
//       print('Error getting current user data: $e');
//       return null;
//     }
//   }
//
//   // Update user profile in database
//   Future<void> updateUserProfile(String uid, String displayName, [String? description]) async {
//     try {
//       print('Updating user profile in database: $uid');
//       print('New display name: $displayName');
//       print('New description: $description');
//
//       Map<String, dynamic> updateData = {
//         'displayName': displayName,
//         'lastSeen': DateTime.now().millisecondsSinceEpoch,
//       };
//
//       if (description != null) {
//         updateData['description'] = description;
//       }
//
//       await _database.child('users/$uid').update(updateData);
//
//       print('Successfully updated user profile in database');
//     } catch (e) {
//       print('Error updating user profile in database: $e');
//       throw e;
//     }
//   }
// }
