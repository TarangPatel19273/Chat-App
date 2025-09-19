# Chatting App

A real-time Flutter chat application with Firebase backend that allows users to register, add friends, and chat in real-time.

## Features

- ✅ User Authentication (Sign up/Sign in with email & password)
- ✅ Add friends by email address
- ✅ Real-time messaging with Firebase Realtime Database
- ✅ Online/Offline status indicators
- ✅ Message read receipts (single/double check marks)
- ✅ Beautiful Material Design UI
- ✅ Responsive chat interface
- ✅ Message timestamps and date grouping
- ✅ Auto-scroll to latest messages

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Firebase Authentication
  - Firebase Realtime Database
- **State Management**: Provider
- **UI**: Material Design 3

## Firebase Setup

This project uses Firebase for backend services. The `google-services.json` file is already configured for the Android app.

### Firebase Console Configuration

1. **Authentication**: Email/Password sign-in method is enabled
2. **Realtime Database**: Database rules configured for authenticated users
3. **Project ID**: `chatting-app-a09ac`

### Database Structure

```
users/
  {userId}/
    uid: string
    email: string
    displayName: string
    isOnline: boolean
    lastSeen: timestamp
    friends: array of friend user IDs

chats/
  {chatRoomId}/  // Format: "{userId1}_{userId2}" (sorted)
    messages/
      {messageId}/
        senderId: string
        receiverId: string
        message: string
        timestamp: timestamp
        isRead: boolean
    lastMessage/
      message: string
      senderId: string
      timestamp: timestamp
```

## Getting Started

### Prerequisites

- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code
- Android emulator or physical device

### Installation

1. **Clone/Download the project** to your local machine

2. **Navigate to project directory**:
   ```bash
   cd Chatting_App
   ```

3. **Get dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the app**:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── user_model.dart       # User data model
│   └── message_model.dart    # Message data model
├── services/
│   ├── auth_service.dart     # Authentication logic
│   └── chat_service.dart     # Chat/messaging logic
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart    # Login UI
│   │   └── register_screen.dart # Registration UI
│   ├── home/
│   │   └── home_screen.dart     # Main app screen with tabs
│   └── chat/
│       └── chat_screen.dart     # Individual chat interface
└── android/
    └── app/
        └── google-services.json # Firebase configuration
```

## Usage

### Registration
1. Launch the app
2. Tap "Sign Up" on the login screen
3. Fill in your name, email, and password
4. Tap "Create Account"

### Adding Friends
1. Go to the "Friends" tab
2. Tap the menu button (three dots) → "Add Friend"
3. Enter your friend's email address
4. They will appear in your friends list once added

### Chatting
1. Tap on a friend from the "Friends" tab to start a chat
2. Type your message and tap the send button
3. Messages appear in real-time
4. Online status and read receipts are shown

## Key Features Explained

### Real-time Messaging
- Messages are synchronized instantly using Firebase Realtime Database
- Auto-scroll to latest messages
- Message grouping by date

### User Status
- Green dot indicates online users
- "Last seen" timestamp for offline users
- Status updates automatically

### Message Features
- Single check mark: Message sent
- Double check mark: Message read
- Timestamp for each message
- Message bubbles with different colors for sender/receiver

## Development

### Adding New Features

1. **Models**: Add new data models in `lib/models/`
2. **Services**: Add business logic in `lib/services/`
3. **UI**: Create new screens in `lib/screens/`

### Firebase Rules

Current database rules allow authenticated users to read/write their own data and chat with friends.

## Troubleshooting

### Common Issues

1. **Build Errors**: Run `flutter clean` and `flutter pub get`
2. **Firebase Connection**: Ensure `google-services.json` is in the correct location
3. **Android Build Issues**: Check that all Gradle files are properly configured

### Performance Tips

- Use `flutter run --release` for better performance
- Enable R8 code shrinking (already configured)
- Optimize images in the `assets/` folder

## Contributing

1. Fork the project
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Firebase console for backend issues
3. Check Flutter doctor: `flutter doctor`

---

**Note**: This app is configured to work with the specific Firebase project. For production use, you should create your own Firebase project and update the configuration files accordingly.
