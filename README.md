# Provider Classes Overview

## 1. ConversationProvider
**Purpose**: Manages individual conversation interactions with comprehensive AI chat functionality, including message sending, voice mode integration, and conversation state management.

**Key Properties**:
- `conversation`: Current conversation object, can be pre-existing or lazily created
- `status`: Represents the current chat status (e.g., `idle`, `sendingPrompt`, `answering`, `speaking`)
- `isVoiceMode`: Boolean indicating if voice mode is currently active
- `isResponding`: Boolean indicating if the AI is currently processing or responding
- `messages`: List of messages in the current conversation
- `title`: Dynamically generated conversation title
- `assistant`: Optional AI assistant associated with the conversation
- `voiceModeProvider`: Integrated voice mode functionality handler
- `controller`: Text editing controller for message input
- `scrollController`: Scroll controller for managing conversation view scrolling

**Constructor Parameters**:
- `context`: BuildContext for UI interactions
- `onDelete`: Callback function when a conversation is deleted
- `onCreate`: Callback function when a conversation is created
- `conversation`: Optional pre-existing conversation
- `lazyConversationCreation`: Flag to control when conversation thread is created

**Key Methods**:
- `send()`:
  - Sends a message to the AI model
  - Supports streaming responses
  - Manages conversation state and UI updates
  - Optional chunk-based response handling
  - Automatically creates conversation thread if not exists

- `setup()`:
  - Loads messages for an existing conversation
  - Sorts messages by date
  - Populates conversation message list

- `delete()`:
  - Deletes the current conversation thread
  - Calls the `onDelete` callback
  - Resets conversation state

- `updateConversation()`:
  - Updates the current conversation
  - Triggers UI refresh
  - Calls `setup()` to load messages

- `updateVoiceMode()`:
  - Switches between standard and realtime voice mode providers
  - Configures voice interaction handlers

**Usage Example**:
```dart
ConversationProvider conversationProvider = ConversationProvider(
  context: context,
  onDelete: (id) => print('Conversation deleted: $id'),
  onCreate: (conversation) => print('New conversation created'),
  lazyConversationCreation: true,
);

// Send a message
await conversationProvider.send(
  onChunk: (chunk) => print('Receiving response: $chunk')
);

// Toggle between voice mode implementations
conversationProvider.updateVoiceMode(true); // Use realtime API
```

**Voice Mode Integration**:
- Supports both standard and realtime voice mode
- Manages transcription, listening, and speaking states
- Provides error handling and UI status updates

**Error Handling**:
- Integrated error reporting via `_showError()` method
- Supports custom error reporting callbacks
- Logs status changes and errors

**State Management**:
- Extends `ChangeNotifier` for reactive UI updates
- Automatically manages conversation thread lifecycle
- Provides granular status tracking

**Performance Considerations**:
- Implements throttling for scroll and UI updates
- Lazy conversation creation option
- Efficient message loading and sorting

## 2. ConversationsProvider
**Purpose**: Manages multiple conversations with paginated loading, sorting, and CRUD operations. Provides a centralized way to handle conversation lists and their lifecycle management.

**Key Properties**:
- `conversations`: List of all loaded conversations
- `ignoreUpdatedAtOnSort`: Flag to control sorting behavior (uses createdAt instead of updatedAt)
- `context`: BuildContext for UI interactions and dialog displays

**Constructor Parameters**:
- `context`: BuildContext for UI interactions
- `ignoreUpdatedAtOnSort`: Optional boolean to ignore updatedAt when sorting (defaults to false)

**Key Methods**:
- `setup()`:
  - Initializes and loads conversations from saved thread IDs
  - Retrieves conversation titles and populates the conversations list
  - Implements streaming for efficient loading
  - Handles errors with adaptive dialog display
  - Should be called in initState

- `add(Conversation newConversation)`:
  - Adds a new conversation to the list
  - Updates existing conversation if ID already exists
  - Inserts new conversations at the beginning of the list
  - Automatically sorts conversations after addition

- `delete(String id)`:
  - Removes conversation with specified ID from the list
  - Triggers UI updates via notifyListeners()

**Pagination Features**:
- Extends `PaginatedRepository<Conversation>` mixin
- `chunkSize`: Set to 1 for individual conversation loading
- `maxConcurrency`: Set to 3 for concurrent loading operations
- `count()`: Returns total number of saved conversations
- `fetch()`: Loads conversations with limit and skip parameters

**Usage Example**:
```dart
ConversationsProvider conversationsProvider = ConversationsProvider(
  context,
  ignoreUpdatedAtOnSort: false,
);

// Initialize conversations
await conversationsProvider.setup();

// Add a new conversation
conversationsProvider.add(newConversation);

// Delete a conversation
conversationsProvider.delete(conversationId);

// Access conversations list
List<Conversation> allConversations = conversationsProvider.conversations;
```

**Sorting Behavior**:
- Conversations are sorted by date in descending order (newest first)
- Uses `updatedAt` by default, falls back to `createdAt` if null
- Can be configured to ignore `updatedAt` via constructor parameter

**Error Handling**:
- Displays adaptive dialogs for loading errors
- Handles missing conversations by cleaning up saved references
- Provides detailed error messages with logs
- Graceful fallback for network and API token issues

**State Management**:
- Extends `ChangeNotifier` for reactive UI updates
- Automatically notifies listeners on data changes
- Maintains conversation state consistency

**Performance Optimizations**:
- Concurrent loading with configurable max concurrency
- Chunked loading for better memory management
- Efficient sorting and filtering operations
- Lazy loading with pagination support

## 3. VoiceModeProvider
**Purpose**: Provides voice interaction capabilities using a manual approach that combines speech-to-text transcription, AI text generation, and text-to-speech synthesis to create a voice mode experience.

**Key Properties**:
- `micSendMode`: Configuration for microphone input handling
- `transcriber`: Model for converting speech to text
- `audioVolumeStream`: Stream providing real-time audio volume levels
- `isInVoiceMode`: Boolean indicating if voice mode is currently active
- `isLoadingVoiceMode`: Always returns false as no loading is required

**Key Methods**:
- `startVoiceMode()`:
  - Initiates voice interaction mode
  - Enables wakelock to prevent screen timeout
  - Starts listening to user input
  - Returns null (no realtime model needed)

- `stopVoiceMode()`:
  - Terminates voice interaction mode
  - Disposes of transcriber and speaker resources
  - Disables wakelock
  - Resets status to idle

- `stopVoiceInteraction()`:
  - Interrupts current voice interaction
  - Stops listening or speaking based on current status
  - Handles both user input and AI response interruption

**Voice Processing Flow**:
1. **Listening**: Records user audio with silence detection
2. **Transcription**: Converts recorded audio to text using transcriber
3. **AI Processing**: Sends transcribed text to AI model
4. **Speech Synthesis**: Converts AI response to speech using speaker
5. **Playback**: Plays synthesized speech while continuing to process chunks

**Usage Example**:
```dart

// Start voice interaction
await voiceModeProvider.startVoiceMode();

// Stop voice interaction
await voiceModeProvider.stopVoiceMode();
```

**Features**:
- Automatic silence detection for hands-free operation
- Real-time audio volume monitoring
- Concurrent speech synthesis during AI response streaming
- Wakelock integration to prevent screen timeout
- Comprehensive error handling and reporting

**State Management**:
- Manages complex voice interaction states
- Provides audio volume stream for UI visualization
- Handles transitions between listening, transcribing, thinking, and speaking states

## 4. RealtimeVoiceModeProvider
**Purpose**: Provides voice interaction capabilities using OpenAI's Realtime API for low-latency, real-time voice conversations with AI assistants.

**Key Properties**:
- `realtimeModel`: Handler for OpenAI Realtime API connections
- `realtimePlayer`: Audio player for real-time audio playback
- `recorder`: Audio recorder for capturing user voice
- `audioVolumeStream`: Stream providing real-time audio volume levels
- `isInVoiceMode`: Boolean indicating if voice mode is currently active
- `isLoadingVoiceMode`: Boolean indicating if voice mode is initializing

**Constructor Parameters**:
- `setStatus`: Function to update chat status
- `onStart`: Callback when voice mode starts
- `onTranscriptionStart`: Optional callback for transcription start events
- `onTranscription`: Optional callback for transcription data
- `onTranscriptionEnd`: Optional callback for transcription end events
- `onSpeechEnd`: Optional callback for speech end events
- `onError`: Callback for error handling

**Key Methods**:
- `startVoiceMode()`:
  - Establishes connection to OpenAI Realtime API
  - Initializes real-time audio player
  - Sets up event listeners for transcription and speech
  - Enables wakelock to prevent screen timeout
  - Returns RealtimeModel instance

- `stopVoiceMode()`:
  - Closes Realtime API connection
  - Disposes of audio player and recorder resources
  - Disables wakelock
  - Resets status to idle

- `stopVoiceInteraction()`:
  - Interrupts current real-time interaction
  - Stops AI speech or commits user audio based on current state

- `muteMic()` / `unmuteMic()`:
  - Controls microphone recording state
  - Manages audio stream to Realtime API

**Realtime API Integration**:
- Direct WebSocket connection to OpenAI's Realtime API
- Streaming audio input and output
- Real-time transcription and speech synthesis
- Low-latency voice interactions

**Event Handling**:
- `onTranscriptionStart`: Triggered when transcription begins
- `onTranscription`: Receives real-time transcription data
- `onTranscriptionEnd`: Triggered when transcription completes
- `onSpeechEnd`: Triggered when AI speech ends
- `onConnectionOpen`: Handles successful API connection
- `onConnectionClose`: Handles API disconnection
- `onError`: Handles API and connection errors

**Usage Example**:
```dart

// Start realtime voice interaction
RealtimeModel model = await realtimeProvider.startVoiceMode();

// Stop realtime voice interaction
await realtimeProvider.stopVoiceMode();
```

**Features**:
- Ultra-low latency voice interactions via OpenAI Realtime API
- Real-time audio streaming and processing
- Concurrent transcription and speech synthesis
- Advanced audio buffer management
- Comprehensive event system for UI integration

**Performance Advantages**:
- Direct API streaming eliminates transcription delays
- Real-time audio processing
- Optimized buffer management for smooth playback
- Efficient WebSocket communication

**State Management**:
- Manages real-time connection states
- Provides loading state during API connection
- Handles complex audio streaming states
- Prevents unnecessary status updates for performance

---

# Setup and Initialization

## setupUI Function
**Purpose**: Initializes all necessary components, singletons, and configurations required for the VIT GPT Flutter API package to function properly.

**Parameters**:
- `openAiKey`: Optional OpenAI API key for immediate configuration

**Complete Usage Example**:
```dart
import 'package:vit_gpt_flutter_api/features/usecases/setup_ui.dart';

void main() async {
  // Initialize the package with optional API key
  await setupUI(openAiKey: 'your-openai-api-key');

  runApp(MyApp());
}

// Alternative: Initialize without API key and set it later
void main() async {
  await setupUI();

  // Set API key later through LocalStorageRepository
  final repository = GetIt.I<LocalStorageRepository>();
  await repository.saveApiToken('your-openai-api-key');

  runApp(MyApp());
}
```

**Important Notes**:
- **Must be called before runApp()**: Essential for proper package initialization
- **Async function**: Always await the setupUI call
- **One-time setup**: Should only be called once during app startup
- **Dependency injection**: Makes components available throughout the app via GetIt
- **Platform compatibility**: Handles iOS-specific configurations automatically

**Dependencies Registered**:
- `SharedPreferences`: Available via `GetIt.I<SharedPreferences>()`
- `LocalStorageRepository`: Available via `GetIt.I<LocalStorageRepository>()`

---

# Usage Guide

## Using Providers with the Provider Package

The recommended approach is to use these providers with the `provider` package for reactive state management:

### 1. Setup Dependencies

Add to your `pubspec.yaml`:
```yaml
dependencies:
  provider: ^6.0.0
  vit_gpt_flutter_api: ^latest_version
```

### 2. Wrap Your App with Providers

```dart
import 'package:provider/provider.dart';
import 'package:vit_gpt_flutter_api/ui/providers/conversations_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ConversationsProvider(context),
        ),
        // Add other providers as needed
      ],
      child: MyApp(),
    ),
  );
}
```

## Using Providers with addListener/removeListener (StatefulWidget)

If you prefer not to use the provider package, you can manually manage listeners:

### 1. ConversationProvider with Manual Listeners

```dart
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final conversationProvider= ConversationProvider(
      context: context,
      onDelete: (id) => print('Conversation deleted: $id'),
      onCreate: (conversation) => print('New conversation created'),
    );

  @override
  void initState() {
    super.initState();

    // Add listener to rebuild UI when provider changes
    conversationProvider.addListener(_onProviderChanged);

    // Setup conversation if needed
    conversationProvider.setup();
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    conversationProvider.removeListener(_onProviderChanged);
    conversationProvider.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    // Rebuild the widget when provider notifies changes
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    throw new Exception('Not implemented')
  }
}
```
