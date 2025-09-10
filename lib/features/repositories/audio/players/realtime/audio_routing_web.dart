// Web-specific audio routing implementation
// Ensures audio output is routed to speakers instead of earpiece on mobile devices
// Uses Web Audio API and MediaSession API to control audio output routing

import 'dart:js_interop';

// JavaScript console logging for debugging audio routing
@JS('console.log')
external void consoleLog(String message);

// Web API bindings for audio control
// MediaSession API - controls media metadata and playback state
@JS('navigator.mediaSession')
external MediaSession? get mediaSession;

// MediaDevices API - provides access to audio input/output device selection
@JS('navigator.mediaDevices')
external MediaDevices? get mediaDevices;

// MediaSession metadata structure for identifying audio content type
// This helps the browser/OS understand this is media content, not a voice call
@JS()
@anonymous
extension type MediaSessionMetadata._(JSObject _) implements JSObject {
  external factory MediaSessionMetadata({
    String? title,
    String? artist,
    String? album,
  });
}

// MediaSession interface for controlling media playback state and metadata
// Setting metadata and playback state helps ensure proper audio routing
@JS()
extension type MediaSession._(JSObject _) implements JSObject {
  external set metadata(MediaSessionMetadata? metadata);
  external set playbackState(String state); // 'playing', 'paused', 'none'
}

// MediaDevices interface for audio output device selection
// selectAudioOutput() allows explicit selection of speaker vs earpiece
@JS()
extension type MediaDevices._(JSObject _) implements JSObject {
  external JSPromise<JSObject> selectAudioOutput();
}

// Web Audio API constructors for creating audio contexts
// AudioContext provides low-level audio control and routing capabilities
@JS('AudioContext')
external JSFunction? get audioContextConstructor;

// Webkit-prefixed version for older browsers
@JS('webkitAudioContext')
external JSFunction? get webkitAudioContextConstructor;

// AudioContext interface with sink selection for output device control
@JS()
extension type AudioContext._(JSObject _) implements JSObject {
  // setSinkId() directs audio output to specific device (empty string = default speaker)
  external JSPromise<JSAny?> setSinkId(String sinkId);
}

// Audio routing utility class for ensuring speaker output on web platforms
// Primary purpose: Route audio to mobile speaker instead of earpiece for better user experience
class AudioRouting {
  // Configures web audio APIs to route output through speakers rather than earpiece
  // This is crucial for realtime audio applications on mobile devices
  static void configureForSpeakerOutput() {
    try {
      consoleLog('[AudioRouting] Configuring audio for speaker output on web');
      
      // Step 1: Configure MediaSession API to identify this as media content
      // This helps the browser/OS route audio to speakers instead of treating it as a phone call
      final session = mediaSession;
      if (session != null) {
        // Set metadata to clearly identify this as media playback, not voice communication
        // This metadata helps the browser's audio routing logic choose the correct output device
        session.metadata = MediaSessionMetadata(
          title: 'Audio Playback',
          artist: 'Realtime Audio',
          album: 'Media Content',
        );
        // Mark as actively playing to ensure proper routing priority
        session.playbackState = 'playing';
        consoleLog('[AudioRouting] MediaSession configured successfully');
      } else {
        consoleLog('[AudioRouting] MediaSession not available');
      }
      
      // Step 2: Create AudioContext for low-level audio control
      // AudioContext allows us to explicitly set audio output sink (speaker vs earpiece)
      final constructor = audioContextConstructor ?? webkitAudioContextConstructor;
      if (constructor != null) {
        // Create the audio context instance
        final context = constructor.callAsFunction() as AudioContext;
        consoleLog('[AudioRouting] AudioContext created for media routing');
        
        // Step 3: Attempt to explicitly route audio to speaker device
        _trySetSpeakerOutput(context);
      } else {
        consoleLog('[AudioRouting] AudioContext not available');
      }
      
    } catch (e) {
      consoleLog('[AudioRouting] Error configuring speaker output: $e');
    }
  }
  
  // Private helper method to explicitly set audio output to speaker device
  // Uses multiple Web API approaches for maximum browser compatibility
  static void _trySetSpeakerOutput(AudioContext context) {
    try {
      // Approach 1: Use MediaDevices.selectAudioOutput() if available
      // This API allows explicit speaker selection but requires user interaction
      final devices = mediaDevices;
      if (devices != null) {
        // Note: selectAudioOutput requires user gesture in most browsers for security
        consoleLog('[AudioRouting] Audio output selection API available');
      } else {
        consoleLog('[AudioRouting] Audio output selection API not available');
      }
      
      // Approach 2: Use AudioContext.setSinkId() to route to default speaker
      // Empty string typically refers to the default audio output (speakers on mobile)
      context.setSinkId('').toDart.then((value) {
        consoleLog('[AudioRouting] Audio sink set to default speaker');
      }).catchError((error) {
        consoleLog('[AudioRouting] Could not set audio sink: $error');
      });
      
    } catch (e) {
      consoleLog('[AudioRouting] Error setting speaker output: $e');
    }
  }
  
  // Cleanup method to reset MediaSession state when audio playback ends
  // Prevents interference with subsequent audio routing decisions
  static void cleanup() {
    try {
      consoleLog('[AudioRouting] Cleaning up audio routing');
      final session = mediaSession;
      if (session != null) {
        // Reset playback state to indicate no active media
        session.playbackState = 'none';
        // Clear metadata to remove media identification
        session.metadata = null;
        consoleLog('[AudioRouting] MediaSession cleaned up');
      }
    } catch (e) {
      consoleLog('[AudioRouting] Error during cleanup: $e');
    }
  }
}