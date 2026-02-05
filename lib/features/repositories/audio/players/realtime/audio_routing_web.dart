// Web-specific audio routing implementation
// Ensures audio output is routed to speakers instead of earpiece on mobile devices
// Uses Web Audio API and MediaSession API to control audio output routing

import 'dart:js_interop';
import 'package:web/web.dart' as web;

// Audio routing utility class for ensuring speaker output on web platforms
// Primary purpose: Route audio to mobile speaker instead of earpiece for better user experience
class AudioRouting {
  // Configures web audio APIs to route output through speakers rather than earpiece
  // This is crucial for realtime audio applications on mobile devices
  static void configureForSpeakerOutput() {
    try {
      web.console.log('[AudioRouting] Configuring audio for speaker output on web'.toJS);

      // Step 1: Configure MediaSession API to identify this as media content
      // This helps the browser/OS route audio to speakers instead of treating it as a phone call
      final session = web.window.navigator.mediaSession;
      if (session != null) {
        try {
          // Set metadata to clearly identify this as media playback, not voice communication
          // This metadata helps the browser's audio routing logic choose the correct output device
          session.metadata = web.MediaMetadata(
            web.MediaMetadataInit(
              title: 'Audio Playback',
              artist: 'Realtime Audio',
              album: 'Media Content',
            ),
          );
          // Mark as actively playing to ensure proper routing priority
          session.playbackState = 'playing';
          web.console.log('[AudioRouting] MediaSession configured successfully'.toJS);
        } catch (e) {
          web.console.error('[AudioRouting] Failed to set MediaSession metadata: $e'.toJS);
        }
      } else {
        web.console.log('[AudioRouting] MediaSession not available'.toJS);
      }

      // Step 2: Create AudioContext for low-level audio control
      // AudioContext allows us to explicitly set audio output sink (speaker vs earpiece)
      try {
        final context = web.AudioContext();
        web.console.log('[AudioRouting] AudioContext created for media routing'.toJS);

        // Step 3: Attempt to explicitly route audio to speaker device
        _trySetSpeakerOutput(context);
      } catch (e) {
        web.console.log('[AudioRouting] Could not create AudioContext: $e'.toJS);
      }

    } catch (e) {
      web.console.error('[AudioRouting] Error configuring speaker output: $e'.toJS);
    }
  }

  // Private helper method to explicitly set audio output to speaker device
  // Uses multiple Web API approaches for maximum browser compatibility
  static void _trySetSpeakerOutput(web.AudioContext context) {
    try {
      // Check if MediaDevices API is available
      final devices = web.window.navigator.mediaDevices;
      if (devices != null) {
        // Note: selectAudioOutput requires user gesture in most browsers for security
        web.console.log('[AudioRouting] Audio output selection API available'.toJS);
      } else {
        web.console.log('[AudioRouting] Audio output selection API not available'.toJS);
      }

      // Use AudioContext.setSinkId() to route to default speaker
      // Empty string typically refers to the default audio output (speakers on mobile)
      try {
        // Note: setSinkId may not be available on all browsers/AudioContext implementations
        // We'll try to call it if it exists, but catch any errors
        final sinkIdPromise = (context as dynamic).setSinkId('');
        if (sinkIdPromise != null) {
          sinkIdPromise.then(
            (value) {
              web.console.log('[AudioRouting] Audio sink set to default speaker'.toJS);
            },
            (error) {
              web.console.log('[AudioRouting] Could not set audio sink: $error'.toJS);
            },
          );
        }
      } catch (e) {
        web.console.log('[AudioRouting] setSinkId not supported: $e'.toJS);
      }

    } catch (e) {
      web.console.error('[AudioRouting] Error setting speaker output: $e'.toJS);
    }
  }

  // Cleanup method to reset MediaSession state when audio playback ends
  // Prevents interference with subsequent audio routing decisions
  static void cleanup() {
    try {
      web.console.log('[AudioRouting] Cleaning up audio routing'.toJS);
      final session = web.window.navigator.mediaSession;
      if (session != null) {
        // Reset playback state to indicate no active media
        session.playbackState = 'none';
        // Clear metadata to remove media identification
        session.metadata = null;
        web.console.log('[AudioRouting] MediaSession cleaned up'.toJS);
      }
    } catch (e) {
      web.console.error('[AudioRouting] Error during cleanup: $e'.toJS);
    }
  }
}
