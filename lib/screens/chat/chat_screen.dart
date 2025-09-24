import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/storage_debug_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/friend_profile_dialog.dart';

class ChatScreen extends StatefulWidget {
  final UserModel friend;

  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final StorageDebugService _debugService = StorageDebugService();
  bool _isUploading = false;
  File? _selectedImage;
  bool _showImagePreview = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when entering chat
    _chatService.markMessagesAsRead(widget.friend.uid);
    // Also listen to scroll to mark messages as read when user views older messages
    _scrollController.addListener(() {
      // Debounced simple behavior: on any scroll, attempt marking as read again
      _chatService.markMessagesAsRead(widget.friend.uid);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Clear the input immediately for better UX
    _messageController.clear();

    // Send the message
    await _chatService.sendMessage(widget.friend.uid, messageText);

    // Scroll to bottom after sending message
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendSelectedImage() async {
    if (_selectedImage == null) return;

    try {
      setState(() {
        _isUploading = true;
      });

      // Debug Firebase Storage configuration
      await _debugService.debugStorageConfiguration();
      
      // Test image upload first
      print('Testing image upload before sending message...');
      await _debugService.testImageUpload(_selectedImage!);
      
      // Send image through chat service
      await _chatService.sendImageMessage(widget.friend.uid, _selectedImage!);

      // Clear preview and reset state
      setState(() {
        _selectedImage = null;
        _showImagePreview = false;
        _isUploading = false;
      });

      // Scroll to bottom after sending image
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image sent successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      print('Image send error: $e');
      
      // Show more detailed error message
      String errorMessage = 'Failed to send image';
      
      if (e.toString().contains('object-not-found')) {
        errorMessage = 'Firebase Storage not configured properly.\nPlease check your Firebase project settings.';
      } else if (e.toString().contains('unauthorized') || e.toString().contains('permission')) {
        errorMessage = 'Storage permission denied.\nFirebase Storage rules may be too restrictive.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error.\nCheck your internet connection.';
      } else {
        errorMessage = 'Upload failed: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _sendSelectedImage(),
          ),
        ),
      );
    }
  }

  void _cancelImageSelection() {
    setState(() {
      _selectedImage = null;
      _showImagePreview = false;
    });
  }

  Future<void> _pickImageSimple() async {
    try {
      // Show image source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick image directly
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        // User cancelled or no image selected
        return;
      }

      // Show image preview
      setState(() {
        _selectedImage = File(pickedFile.path);
        _showImagePreview = true;
      });

      // Scroll to bottom to show the preview
      _scrollToBottom();

    } catch (e) {
      // Handle any errors (including permission issues)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to access ${e.toString().contains('camera') ? 'camera' : 'gallery'}. Please check app permissions in Settings.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
            textColor: Colors.white,
          ),
        ),
      );
      print('Error picking image: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => FriendProfileDialog.show(context, widget.friend),
          child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              radius: 18,
              child: Text(
                widget.friend.displayName.isNotEmpty
                    ? widget.friend.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friend.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.friend.statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.friend.isOnline ? Colors.green : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
        actions: [
          // Temporary debug button - remove after fixing storage
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              print('\n🔍 RUNNING COMPREHENSIVE STORAGE TEST...');
              await _debugService.fullStorageTest();
              
              // Show result in UI too
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Storage test completed! Check console for results.'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Test Firebase Storage',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.friend.uid).asBroadcastStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading messages'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with ${widget.friend.displayName}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Auto scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isMe = message.senderId == currentUser?.uid;
                    
                    // Group messages by date
                    bool showDateHeader = false;
                    if (index == 0) {
                      showDateHeader = true;
                    } else {
                      final previousMessage = messages[index - 1];
                      final currentDate = DateTime(
                        message.timestamp.year,
                        message.timestamp.month,
                        message.timestamp.day,
                      );
                      final previousDate = DateTime(
                        previousMessage.timestamp.year,
                        previousMessage.timestamp.month,
                        previousMessage.timestamp.day,
                      );
                      showDateHeader = !currentDate.isAtSameMomentAs(previousDate);
                    }

                    return Column(
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatDate(message.timestamp),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        _buildMessageBubble(message, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // Image Preview Section
          if (_showImagePreview && _selectedImage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[850] 
                    : Colors.grey[100],
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[700]! 
                        : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[300] 
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Image Preview
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey[600]! 
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Action Buttons
                      Expanded(
                        child: Row(
                          children: [
                            // Cancel Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isUploading ? null : _cancelImageSelection,
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Send Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isUploading ? null : _sendSelectedImage,
                                icon: _isUploading 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.send, size: 18),
                                label: Text(_isUploading ? 'Sending...' : 'Send'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[900] 
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Image picker button
                  IconButton(
                    onPressed: _pickImageSimple,
                    icon: Icon(
                      Icons.image,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[400] 
                          : Colors.grey[600],
                    ),
                    tooltip: 'Select Image',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey[400] 
                              : Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey[800] 
                            : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: message.type == MessageType.image 
            ? const EdgeInsets.all(4) 
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe 
              ? Theme.of(context).primaryColor 
              : (isDarkMode ? Colors.grey[700] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message content based on type
            if (message.type == MessageType.image && message.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 40, color: Colors.grey),
                          Text('Failed to load image', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Text(
                message.message,
                style: TextStyle(
                  color: isMe 
                      ? Colors.white 
                      : (isDarkMode ? Colors.white : Colors.black87),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Timestamp and read status
            Padding(
              padding: message.type == MessageType.image 
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: isMe 
                          ? Colors.white70 
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                      fontSize: 12,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      color: message.isRead ? Colors.blue[300] : Colors.white70,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}
