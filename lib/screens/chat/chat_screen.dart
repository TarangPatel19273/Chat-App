import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/friend_profile_dialog.dart';

class ChatScreen extends StatefulWidget {
  final UserModel friend;

  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();//manages the text input field for messages.
  final ScrollController _scrollController = ScrollController();//lets us control chat scrolling (e.g., move to bottom).
  final ChatService _chatService = ChatService();//instance of the class that talks to the backend (Firestore or any DB).

  // IDs of currently selected messages (for multi-select delete)
  final Set<String> _selectedMessageIds = {};
  // Messages that the current user has hidden locally ("delete for me")
  final Set<String> _locallyDeletedMessageIds = {};


  //Marks friend’s messages as read when chat opens.
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


  //Releases memory when screen is closed by disposing controllers.
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  //Sending Messages
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

  // Handle long press on a message (select message)
  // Only allows selecting messages sent by the current user
  void _onMessageLongPress(MessageModel message, bool isMe) {
    // Only allow selecting own messages
    if (!isMe) return;
    
    setState(() {
      // Toggle selection
      if (_selectedMessageIds.contains(message.messageId)) {
        _selectedMessageIds.remove(message.messageId);
      } else {
        _selectedMessageIds.add(message.messageId);
      }
    });
  }

  // Clear the selected message (when tapping anywhere)
  void _clearSelectedMessage() {
    setState(() {
      _selectedMessageIds.clear();
    });
  }

  // Show delete options and perform the chosen action
  Future<void> _showDeleteOptions() async {
    if (_selectedMessageIds.isEmpty) return;

    // Safety check: Filter out any messages that don't belong to current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get all messages to verify ownership
    final allMessages = await _chatService
        .getMessages(widget.friend.uid)
        .first; // Get first snapshot
    
    // Filter to only include own messages
    final ownMessageIds = allMessages
        .where((m) => m.senderId == currentUser.uid)
        .map((m) => m.messageId)
        .toSet();
    
    // Remove any selected messages that don't belong to the user
    _selectedMessageIds.removeWhere((id) => !ownMessageIds.contains(id));
    
    if (_selectedMessageIds.isEmpty) {
      // No valid messages to delete
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete your own messages'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final String? choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete from me'),
                onTap: () => Navigator.of(context).pop('me'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete from everyone',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.of(context).pop('everyone'),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop('cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    if (choice == 'me') {
      // Hide messages only for current user (local state)
      setState(() {
        _locallyDeletedMessageIds.addAll(_selectedMessageIds);
        _selectedMessageIds.clear();
      });
    } else if (choice == 'everyone') {
      // Delete messages from database so they disappear for both users
      final idsToDelete = List<String>.from(_selectedMessageIds);
      setState(() {
        _selectedMessageIds.clear();
      });

      for (final id in idsToDelete) {
        await _chatService.deleteMessage(widget.friend.uid, id);
      }
    } else {
      // Cancel: just clear selection
      setState(() {
        _selectedMessageIds.clear();
      });
    }
  }

 //Scroll Helper
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


  //UI: Scaffold
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //AppBar:Tapping title opens FriendProfileDialog
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (context) => FriendProfileDialog(friend: widget.friend),
          ),
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
          if (_selectedMessageIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.redAccent,
              onPressed: _showDeleteOptions,
              tooltip: 'Delete selected messages',
            ),
        ],
      ),
      //Input box at bottom.
      body: GestureDetector(
        onTap: _clearSelectedMessage,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            // Messages List
            //Uses a StreamBuilder to listen to real-time updates.
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

                final allMessages = snapshot.data ?? [];
                // Filter out locally "deleted for me" messages
                final messages = allMessages
                    .where((m) => !_locallyDeletedMessageIds.contains(m.messageId))
                    .toList();

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

                //ListView of Messages
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isMe = message.senderId == currentUser?.uid;
                    final bool isSelected =
                        _selectedMessageIds.contains(message.messageId);

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
                        GestureDetector(
                          onLongPress: () =>
                              _onMessageLongPress(message, isMe),
                          onTap: () {
                            if (_selectedMessageIds.isNotEmpty) {
                              // When in selection mode, tap toggles selection
                              _onMessageLongPress(message, isMe);
                            }
                          },
                          child: _buildMessageBubble(message, isMe, isSelected),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // Message Input Box
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
    ));
  }

  //Aligns right for my messages, left for friend’s.
  //Bottom-right corner: timestamp and ✓ checkmarks (single = sent, double = read).
  Widget _buildMessageBubble(MessageModel message, bool isMe, bool isSelected) {
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
          color: isSelected
              ? (isDarkMode ? Colors.blueGrey[700] : Colors.blue[100])
              : (isMe 
                  ? Theme.of(context).primaryColor 
                  : (isDarkMode ? Colors.grey[700] : Colors.grey[200])),
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


  //Date Formatting (Today,YesterDay etc..)
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
