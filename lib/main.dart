import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';
import 'models/group_model.dart';
import 'screens/group/add_group_members_screen.dart';
import 'debug_firebase_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase - check if already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
      // Firebase is already initialized, continue
    } else {
      print('Firebase initialization error: $e');
      rethrow;
    }
  }
  
  // Enable Firebase Realtime Database offline persistence (not supported on web)
  try {
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000); // 10MB cache
      print('Firebase offline persistence enabled');
    } else {
      print('Firebase offline persistence skipped (not supported on web)');
    }
    
    // Setup database persistence rules
    final databaseService = DatabaseService();
    databaseService.setupDatabasePersistence();
    
    // Verify database connection
    databaseService.verifyDatabaseConnection();
    
  } catch (e) {
    print('Firebase persistence setup error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Chatting App',
            theme: themeProvider.currentTheme,
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
            // Named routes for better navigation control
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/debug': (context) => const FirebaseDebugTest(),
              '/group/addMembers': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is GroupModel) {
                  return AddGroupMembersScreen(group: args);
                }
                return const Scaffold(
                  body: Center(child: Text('Invalid group data')),
                );
              },
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Add debugging for auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        print('Auth state changed: ${user?.email ?? "null"} (${user?.uid ?? "no uid"})');
        print('Auth state change timestamp: ${DateTime.now()}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('StreamBuilder rebuild - ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, User: ${snapshot.data?.email}');
        
        // Check for errors first
        if (snapshot.hasError) {
          print('Auth stream error: ${snapshot.error}');
          return _buildErrorScreen(context, snapshot.error.toString());
        }
        
        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          print('✅ User authenticated: ${snapshot.data!.email} (${snapshot.data!.uid})');
          return const HomeScreen();
        }
        
        // Show loading state only for a limited time, then show login
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Auth state is waiting, showing loading with timeout...');
          return FutureBuilder(
            future: Future.delayed(const Duration(seconds: 3)),
            builder: (context, timeoutSnapshot) {
              if (timeoutSnapshot.connectionState == ConnectionState.done) {
                // After 3 seconds, show login screen even if still waiting
                print('Auth timeout reached, showing login screen');
                return const LoginScreen();
              }
              return _buildLoadingScreen(context);
            },
          );
        }
        
        // User is not signed in
        print('❌ User not authenticated, showing login');
        return const LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Initializing Firebase Auth...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Force show login screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Skip to Login'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                // Navigate to debug screen
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const FirebaseDebugTest()),
                );
              },
              child: const Text('Debug Firebase'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String error) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Authentication Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
