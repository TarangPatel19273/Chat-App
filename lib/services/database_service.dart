import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

// DatabaseService: utility class for verifying and testing Firebase Realtime Database connection,
// performing admin-like tasks (viewing all users/chats), and managing sync/persistence.
class DatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Verify database connection, server time, and test read/write
  Future<void> verifyDatabaseConnection() async {
    try {
      print('=== Database Verification Started ===');

      // 1. Check connection status via ".info/connected"
      final connectedRef = _database.child('.info/connected');
      final connectedSnapshot = await connectedRef.once();
      final isConnected = connectedSnapshot.snapshot.value as bool? ?? false;
      print('Database Connected: $isConnected');

      // 2. Check server time offset
      final serverTimeRef = _database.child('.info/serverTimeOffset');
      final serverTimeSnapshot = await serverTimeRef.once();
      final serverOffset = serverTimeSnapshot.snapshot.value as num? ?? 0;
      print('Server Time Offset: $serverOffset ms');

      // 3. Test write
      await _testWriteOperation();

      // 4. Test read
      await _testReadOperation();

      print('=== Database Verification Completed ===');
    } catch (e) {
      print('Database verification error: $e');
    }
  }

  // Perform a test write to confirm DB write capability
  Future<void> _testWriteOperation() async {
    try {
      final testRef = _database.child('test/connection_test');
      final testData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Connection test',
        'serverTimestamp': ServerValue.timestamp,
      };

      await testRef.set(testData);
      print('✅ Test write operation successful');
    } catch (e) {
      print('❌ Test write operation failed: $e');
    }
  }

  // Perform a test read to confirm DB read capability
  Future<void> _testReadOperation() async {
    try {
      final testRef = _database.child('test/connection_test');
      final snapshot = await testRef.once();

      if (snapshot.snapshot.exists) {
        final data = snapshot.snapshot.value;
        print('✅ Test read operation successful: $data');
      } else {
        print('❌ Test read operation failed: No data found');
      }
    } catch (e) {
      print('❌ Test read operation failed: $e');
    }
  }

  // Admin utility: list all users from DB
  Future<void> getAllUsers() async {
    try {
      print('=== All Users in Database ===');
      final usersRef = _database.child('users');
      final snapshot = await usersRef.once();

      if (snapshot.snapshot.exists) {
        final usersData = snapshot.snapshot.value as Map<dynamic, dynamic>;
        print('Total users found: ${usersData.length}');

        usersData.forEach((uid, userData) {
          print('User ID: $uid');
          print('User Data: $userData');
          print('---');
        });
      } else {
        print('No users found in database');
      }
    } catch (e) {
      print('Error getting all users: $e');
    }
  }

  // Admin utility: list all chats and messages count
  Future<void> getAllChats() async {
    try {
      print('=== All Chats in Database ===');
      final chatsRef = _database.child('chats');
      final snapshot = await chatsRef.once();

      if (snapshot.snapshot.exists) {
        final chatsData = snapshot.snapshot.value as Map<dynamic, dynamic>;
        print('Total chats found: ${chatsData.length}');

        chatsData.forEach((chatId, chatData) {
          print('Chat ID: $chatId');

          if (chatData['messages'] != null) {
            final messages = chatData['messages'] as Map<dynamic, dynamic>;
            print('Messages count: ${messages.length}');
          }

          if (chatData['lastMessage'] != null) {
            print('Last Message: ${chatData['lastMessage']}');
          }

          print('---');
        });
      } else {
        print('No chats found in database');
      }
    } catch (e) {
      print('Error getting all chats: $e');
    }
  }

  // Force a database sync (useful to flush any pending offline writes)
  Future<void> forceDatabaseSync() async {
    try {
      print('Forcing database sync...');

      // Go online forces sync of pending writes
      FirebaseDatabase.instance.goOnline();

      // Add a marker entry in DB to confirm sync
      await _database.child('sync/last_sync').set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'serverTimestamp': ServerValue.timestamp,
      });

      print('Database sync completed');
    } catch (e) {
      print('Database sync error: $e');
    }
  }

  // Configure persistence rules to keep certain paths synced offline
  void setupDatabasePersistence() {
    try {
      _database.child('users').keepSynced(true);
      _database.child('chats').keepSynced(true);

      print('Database persistence rules set up');
    } catch (e) {
      print('Database persistence setup error: $e');
    }
  }
}




// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// class DatabaseService {
//   final DatabaseReference _database = FirebaseDatabase.instance.ref();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   // Verify database connection and permanency
//   Future<void> verifyDatabaseConnection() async {
//     try {
//       print('=== Database Verification Started ===');
//
//       // Check connection status
//       final connectedRef = _database.child('.info/connected');
//       final connectedSnapshot = await connectedRef.once();
//       final isConnected = connectedSnapshot.snapshot.value as bool? ?? false;
//       print('Database Connected: $isConnected');
//
//       // Check server time
//       final serverTimeRef = _database.child('.info/serverTimeOffset');
//       final serverTimeSnapshot = await serverTimeRef.once();
//       final serverOffset = serverTimeSnapshot.snapshot.value as num? ?? 0;
//       print('Server Time Offset: $serverOffset ms');
//
//       // Test write operation
//       await _testWriteOperation();
//
//       // Test read operation
//       await _testReadOperation();
//
//       print('=== Database Verification Completed ===');
//     } catch (e) {
//       print('Database verification error: $e');
//     }
//   }
//
//   Future<void> _testWriteOperation() async {
//     try {
//       final testRef = _database.child('test/connection_test');
//       final testData = {
//         'timestamp': DateTime.now().millisecondsSinceEpoch,
//         'message': 'Connection test',
//         'serverTimestamp': ServerValue.timestamp,
//       };
//
//       await testRef.set(testData);
//       print('✅ Test write operation successful');
//     } catch (e) {
//       print('❌ Test write operation failed: $e');
//     }
//   }
//
//   Future<void> _testReadOperation() async {
//     try {
//       final testRef = _database.child('test/connection_test');
//       final snapshot = await testRef.once();
//
//       if (snapshot.snapshot.exists) {
//         final data = snapshot.snapshot.value;
//         print('✅ Test read operation successful: $data');
//       } else {
//         print('❌ Test read operation failed: No data found');
//       }
//     } catch (e) {
//       print('❌ Test read operation failed: $e');
//     }
//   }
//
//   // Get all users (admin function for verification)
//   Future<void> getAllUsers() async {
//     try {
//       print('=== All Users in Database ===');
//       final usersRef = _database.child('users');
//       final snapshot = await usersRef.once();
//
//       if (snapshot.snapshot.exists) {
//         final usersData = snapshot.snapshot.value as Map<dynamic, dynamic>;
//         print('Total users found: ${usersData.length}');
//
//         usersData.forEach((uid, userData) {
//           print('User ID: $uid');
//           print('User Data: $userData');
//           print('---');
//         });
//       } else {
//         print('No users found in database');
//       }
//     } catch (e) {
//       print('Error getting all users: $e');
//     }
//   }
//
//   // Get all chats (admin function for verification)
//   Future<void> getAllChats() async {
//     try {
//       print('=== All Chats in Database ===');
//       final chatsRef = _database.child('chats');
//       final snapshot = await chatsRef.once();
//
//       if (snapshot.snapshot.exists) {
//         final chatsData = snapshot.snapshot.value as Map<dynamic, dynamic>;
//         print('Total chats found: ${chatsData.length}');
//
//         chatsData.forEach((chatId, chatData) {
//           print('Chat ID: $chatId');
//
//           if (chatData['messages'] != null) {
//             final messages = chatData['messages'] as Map<dynamic, dynamic>;
//             print('Messages count: ${messages.length}');
//           }
//
//           if (chatData['lastMessage'] != null) {
//             print('Last Message: ${chatData['lastMessage']}');
//           }
//
//           print('---');
//         });
//       } else {
//         print('No chats found in database');
//       }
//     } catch (e) {
//       print('Error getting all chats: $e');
//     }
//   }
//
//   // Force data sync to server
//   Future<void> forceDatabaseSync() async {
//     try {
//       print('Forcing database sync...');
//
//       // This forces any pending operations to complete
//       FirebaseDatabase.instance.goOnline();
//
//       // Add a sync marker
//       await _database.child('sync/last_sync').set({
//         'timestamp': DateTime.now().millisecondsSinceEpoch,
//         'serverTimestamp': ServerValue.timestamp,
//       });
//
//       print('Database sync completed');
//     } catch (e) {
//       print('Database sync error: $e');
//     }
//   }
//
//   // Setup database persistence rules
//   void setupDatabasePersistence() {
//     try {
//       // Keep specific paths synced offline
//       _database.child('users').keepSynced(true);
//       _database.child('chats').keepSynced(true);
//
//       print('Database persistence rules set up');
//     } catch (e) {
//       print('Database persistence setup error: $e');
//     }
//   }
// }
