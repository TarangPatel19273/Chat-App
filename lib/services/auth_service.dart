import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  AuthService() {
    // Monitor database connection
    _database.child('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      print('Firebase Database connected: $connected');
    });
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email, 
    String password, 
    String displayName
  ) async {
    try {
      print('Starting registration for email: $email');
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('Firebase Auth user created: ${result.user?.uid}');
      
      User? user = result.user;
      if (user != null) {
        print('Updating display name to: $displayName');
        // Update display name
        await user.updateDisplayName(displayName);
        
        print('Creating user in database...');
        // Create user in Realtime Database
        await _createUserInDatabase(user, displayName, email);
      }
      
      print('Registration completed successfully');
      return result;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Registration error: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('General registration error: $e');
      print('Stack trace: ${StackTrace.current}');
      throw e;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email, 
    String password
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update user status to online
      if (result.user != null) {
        await _updateUserStatus(result.user!.uid, true);
      }
      
      return result;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.message}');
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Update user status to offline
      if (currentUser != null) {
        await _updateUserStatus(currentUser!.uid, false);
      }
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Create user in database
  Future<void> _createUserInDatabase(User user, String displayName, String email) async {
    try {
      UserModel userModel = UserModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        isOnline: true,
        lastSeen: DateTime.now(),
        friends: [],
      );
      
      print('Attempting to create user in database: ${user.uid}');
      print('User data: ${userModel.toJson()}');
      
      await _database.child('users/${user.uid}').set(userModel.toJson());
      print('User successfully created in database');
    } catch (e) {
      print('Error creating user in database: $e');
      print('Stack trace: ${StackTrace.current}');
      throw e;
    }
  }

  // Update user online status
  Future<void> _updateUserStatus(String uid, bool isOnline) async {
    await _database.child('users/$uid').update({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get user by email
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

  // Add friend
  Future<bool> addFriend(String friendEmail) async {
    try {
      if (currentUser == null) return false;
      
      String currentUid = currentUser!.uid;
      
      // Don't add yourself as a friend
      if (friendEmail.toLowerCase() == currentUser!.email?.toLowerCase()) {
        print('Cannot add yourself as a friend');
        return false;
      }
      
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
      
      // Add friend to current user's friends list
      await _database.child('users/$currentUid/friends').push().set(friend.uid);
      
      // Add current user to friend's friends list
      await _database.child('users/${friend.uid}/friends').push().set(currentUid);
      
      print('Successfully added ${friend.displayName} as friend');
      return true;
    } catch (e) {
      print('Error adding friend: $e');
      return false;
    }
  }

  // Get current user data
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
}
