import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isEditing = false;
  bool _isLoading = false;
  UserModel? _currentUserData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getCurrentUserData();
      
      if (userData != null && mounted) {
        setState(() {
          _currentUserData = userData;
          _displayNameController.text = userData.displayName;
          _emailController.text = userData.email;
          _descriptionController.text = userData.description;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    final newDisplayName = _displayNameController.text.trim();
    final newDescription = _descriptionController.text.trim();
    
    if (newDisplayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      print('Updating profile for user: ${currentUser.uid}');
      print('New display name: $newDisplayName');
      print('New description: $newDescription');

      // Update Firebase Auth display name
      await currentUser.updateDisplayName(newDisplayName);
      await currentUser.reload();
      
      // Update in Firebase Realtime Database
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateUserProfile(currentUser.uid, newDisplayName, newDescription);
      
      // Update local state
      if (_currentUserData != null) {
        setState(() {
          _currentUserData = _currentUserData!.copyWith(
            displayName: newDisplayName,
            description: newDescription,
          );
          _isEditing = false;
          _isLoading = false;
        });
      }

      print('Profile updated successfully in both Auth and Database');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          _currentUserData?.displayName.isNotEmpty == true
                              ? _currentUserData!.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Profile Information Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Display Name Field
                          _buildProfileField(
                            label: 'Display Name',
                            controller: _displayNameController,
                            icon: Icons.person,
                            isEditable: _isEditing,
                          ),
                          const SizedBox(height: 20),

                          // Description Field
                          _buildProfileField(
                            label: 'Description',
                            controller: _descriptionController,
                            icon: Icons.description,
                            isEditable: _isEditing,
                            maxLines: 3,
                            hintText: 'Tell us about yourself...',
                          ),
                          const SizedBox(height: 20),

                          // Email Field (Read-only)
                          _buildProfileField(
                            label: 'Email',
                            controller: _emailController,
                            icon: Icons.email,
                            isEditable: false,
                          ),
                          const SizedBox(height: 20),

                          // User ID (Read-only)
                          _buildInfoRow(
                            'User ID',
                            _auth.currentUser?.uid ?? 'N/A',
                            Icons.fingerprint,
                          ),
                          const SizedBox(height: 12),

                          // Member Since (Read-only)
                          _buildInfoRow(
                            'Member Since',
                            _formatDate(_currentUserData?.lastSeen ?? DateTime.now()),
                            Icons.calendar_today,
                          ),
                          const SizedBox(height: 12),

                          // Online Status
                          _buildStatusRow(),
                          const SizedBox(height: 12),

                          // Dark Mode Toggle
                          _buildThemeToggleRow(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isEditing = false;
                                _displayNameController.text = _currentUserData?.displayName ?? '';
                                _descriptionController.text = _currentUserData?.description ?? '';
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Show confirmation dialog
                          bool shouldSignOut = await _showSignOutDialog();
                          if (shouldSignOut) {
                            try {
                              final authService = Provider.of<AuthService>(context, listen: false);
                              await authService.signOut();
                              
                              // Add a small delay to ensure sign-out is complete
                              await Future.delayed(const Duration(milliseconds: 500));
                              
                              // Show sign out message
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Signed out successfully'),
                                    backgroundColor: Colors.blue,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                
                                // Wait a bit more for the message to show, then navigate
                                await Future.delayed(const Duration(milliseconds: 500));
                                
                                if (mounted) {
                                  // Navigate to login and clear stack
                                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                                }
                              }
                            } catch (e) {
                              print('Error during sign out: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error signing out: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditable,
    int maxLines = 1,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[300] 
                : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: isEditable,
          maxLines: maxLines,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: isEditable ? hintText : null,
            hintStyle: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[400] 
                  : Colors.grey[600],
            ),
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[400] 
                  : Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[600]! 
                    : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[600]! 
                    : Colors.grey[300]!,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700]! 
                    : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.blue,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isEditable 
                ? (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[800] 
                    : Colors.white)
                : (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[850] 
                    : Colors.grey[50]),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(Icons.circle, size: 20, color: Colors.green),
        const SizedBox(width: 12),
        Text(
          'Status: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[600],
          ),
        ),
        Text(
          'Online',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggleRow() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Row(
          children: [
            Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              size: 20,
              color: themeProvider.isDarkMode ? Colors.purple : Colors.orange,
            ),
            const SizedBox(width: 12),
            Text(
              'Theme: ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            Expanded(
              child: Text(
                themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                style: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.purple : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Switched to ${value ? "Dark" : "Light"} Mode!',
                    ),
                    duration: const Duration(seconds: 1),
                    backgroundColor: value ? Colors.grey[800] : Colors.blue,
                  ),
                );
              },
              activeColor: Colors.purple,
              activeTrackColor: Colors.purple.withOpacity(0.3),
              inactiveThumbColor: Colors.orange,
              inactiveTrackColor: Colors.orange.withOpacity(0.3),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<bool> _showSignOutDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    ) ?? false;
  }
}
