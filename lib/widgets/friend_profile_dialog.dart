import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class FriendProfileDialog extends StatelessWidget {
  final UserModel friend;

  const FriendProfileDialog({
    super.key,
    required this.friend,
  });

  static void show(BuildContext context, UserModel friend) {
    showDialog(
      context: context,
      builder: (context) => FriendProfileDialog(friend: friend),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contact Info',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Profile Avatar (Large)
            CircleAvatar(
              radius: 60,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                friend.displayName.isNotEmpty
                    ? friend.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Friend Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Section
                  _buildInfoSection(
                    context,
                    icon: Icons.person,
                    title: 'Name',
                    content: friend.displayName,
                  ),
                  
                  if (friend.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      context,
                      icon: Icons.info_outline,
                      title: 'About',
                      content: friend.description,
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    context,
                    icon: Icons.email_outlined,
                    title: 'Email',
                    content: friend.email,
                  ),
                  
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    context,
                    icon: friend.isOnline ? Icons.circle : Icons.circle_outlined,
                    title: 'Status',
                    content: friend.statusText,
                    contentColor: friend.isOnline ? Colors.green : null,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Chat'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDeleteFriendDialog(context),
                    icon: const Icon(Icons.person_remove, color: Colors.white),
                    label: const Text('Delete Friend'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    Color? contentColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: contentColor ?? (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content.isEmpty ? 'Not provided' : content,
                style: TextStyle(
                  fontSize: 16,
                  color: contentColor ?? (isDarkMode ? Colors.white : Colors.black87),
                  fontStyle: content.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Friend'),
        content: Text('Are you sure you want to remove ${friend.displayName} from your friends list?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close dialogs first
              Navigator.of(context).pop(); // Close confirmation dialog
              Navigator.of(context).pop(); // Close friend profile dialog
              
              // Use a slight delay to ensure dialogs are closed before proceeding
              await Future.delayed(const Duration(milliseconds: 100));
              await _deleteFriend(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFriend(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Removing friend...'),
            ],
          ),
        ),
      );

      bool success = await authService.removeFriend(friend.uid);
      
      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.displayName} has been removed from your friends list'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Navigate back to home screen and clear the entire navigation stack
        // This will remove the friend from chat and friends list
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove friend. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error in _deleteFriend: $e');
      
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
