import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class InAppNotification extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const InAppNotification({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  @override
  State<InAppNotification> createState() => _InAppNotificationState();
}

class _InAppNotificationState extends State<InAppNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start animation
    _animationController.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    widget.onTap?.call();
                    _dismiss();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getNotificationColor().withOpacity(0.1),
                          _getNotificationColor().withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: _getNotificationColor().withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getNotificationColor(),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getNotificationIcon(),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.notification.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.notification.message,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Close button
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                          onPressed: _dismiss,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getNotificationColor() {
    switch (widget.notification.type) {
      case 'friend_added':
        return Colors.green;
      case 'message':
        return Colors.blue;
      case 'friend_request':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon() {
    switch (widget.notification.type) {
      case 'friend_added':
        return Icons.person_add;
      case 'message':
        return Icons.message;
      case 'friend_request':
        return Icons.person_add_alt_1;
      default:
        return Icons.notifications;
    }
  }
}

class InAppNotificationOverlay {
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context,
    NotificationModel notification, {
    VoidCallback? onTap,
  }) {
    // Remove existing notification if any
    hide();

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 60, // Below app bar and tabs
        left: 0,
        right: 0,
        child: InAppNotification(
          notification: notification,
          onDismiss: hide,
          onTap: onTap,
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}
