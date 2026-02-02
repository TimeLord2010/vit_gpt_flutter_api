## 1.13.0

- Feat: Added push-to-talk functionality for voice mode
- Feat: Added pause/resume capability for realtime sessions
- Fix: Fixed compilation issues

## 1.12.0

- Feat: New realtime API integration with improved functionality
- Feat: Added message sorting with itemId and previousItemId tracking
- Fix: Fixed realtime voice mode issues

## 1.11.0

- Feat: Implemented audio recording capabilities with mute/unmute controls
- Feat: Enhanced realtime audio player with pause, seek, and configurable buffer handling
- Feat: Added audio routing and sequencing functionality
- Feat: Added meeting report feature
- Feat: Added support for initial messages in conversations
- Feat: Enhanced audio playback with position tracking and auto-play controls
- Fix: Improved memory management for provider disposal
- Fix: Fixed audio clipping issues and pause functionality
- Fix: Resolved duplicate singleton registration in setupUI
- Fix: Fixed realtime voice mode provider microphone handling
- Build: Updated dependencies including flutter_soloud 3.4.1 and vit_gpt_dart_api from pub dev
- Refac: Improved error logging and reduced debug noise

## 1.10.1

- Fix: Mute and unmute microphone now does not interfere on the ai audio in the `RealtimeVoiceModeProvider`.
- Fix: ChatStatus is only changed to listening to user initially when the microphone recording is ready.

## 1.10.0

- `RealtimeVoiceModeProvider` updates "\_audioVolumeStreamController" with the ai player volume
  levels.

## 1.9.1

- Doc: Added documentation for the package

## 1.9.0

- Feat: Added audio play stop stream on realtime audio player;
- Fix: `RealtimeVoiceModeProvider` now correctly sets ChatStatus.listeningToUser on the right times.

## 1.8.1

- Fix: When sending a message using the `ConversationProvider`, the user message is shown as soon
  as possible, instead of when the connection to the response stream is stablished.

## 1.8.0

- Feat: Creates messages in OpenAI thread when using realtime API.

## 1.7.1

- Fix: Fixed messages order when using realtime API.

## 1.7.0

- BREAKING: Removed isolate support from `RealtimeVoiceModeProvider`. If you really need to remove workload from the main thread, implement this in a custom realtime audio player.
- Feat: Added indicator for voice mode starting to all providers under `VoiceModeContract`.
- Fix: `ConversationProvider.isVoiceMode` now only returns true is the voice mode provider is done loading.

## 1.6.1

- Fix: Realtime API no longer freezes the app.

## 1.6.0

- Feat: `VitGptFlutterConfiguration` now includes realtimeAudioPlayer factory method to customize
  the player used in the `RealtimeVoiceModeProvider`.
- Fix: `RealtimeVoiceModeProvider` creates messages in the chat correctly.

## 1.5.6

- Build: updated dependencies.

## 1.5.5

- Refac: Isolate handling.

## 1.5.2

- Fix: fixed isolate binary transport.

## 1.5.1

- Feat: `RealtimeVoiceModeProvider` use isolate extensively.

## 1.5.0

- Feat: Audio player now has "useLegacyAudioPlayer".
- Fix: `SoLoudAudioPlayer` now cleansup the temporary directory.

## 1.4.4

- Fix: Audio player "play".

## 1.4.3

- Fix: Audio player "play" only finishes its future when the audio finished playing.

## 1.4.2

- Fix: Stopping voie interaction will also prevent further audio data from being sent by the server.

## 1.4.1

- Fix: Stopping voice mode in `RealtimeVoiceModeProvider` now stops the AI speech.
- Fix: Stopping voice interaction also stops the AI from speaking.

## 1.4.0

- Feat: `RealtimeVoiceModeProvider` spawns an isolate to decode the base64 data.

## 1.3.1

- Fix: `VitAudioRecorder`.startStream now produces mono audio data.

## 1.3.0

- Feat: Method "startVoiceMode" in `VoiceModeContract` now optionally returns RealtimeModel.
- Fix: Only begins to records user audio when the connection in opened in `RealtimeVoiceModeProvider`.

## 1.2.6

- Build: updated dependencies
- Refac: new player for mp3 files

## 1.2.5

- Feat: `RealtimeVoiceModeProvider` now exposes their `RealtimeModel`.

## 1.2.4

- Feat: `RealtimeVoiceModeProvider` now implements the method "commitUserAudio".

## 1.2.3

- Fix: `RealtimeVoiceModeProvider` correctly notifed the UI when the voice mode is stopped.

## 1.2.2

- Fix: `RealtimeVoiceModeProvider` notifies correctly the UI when the class is listening to the user.

## 1.2.1

- Fix: `RealtimeVoiceModeProvider` now notifies the ui for changes.
- Feat: `RealtimeVoiceModeProvider` now prevents the screen from listening.

## 1.2.0

- Feat: Realtime voice mode.

## 1.1.0

- Fix: Uses a new package for the ogg player so we can build on android platform.

## 1.0.1

- Build: updated dependencies

## 1.0.0

- Feat: `ConversationsProvider` now can ignore updatedAt on sort.

## 0.5.0

- FEAT: Creates a thread/conversation in the API when `ConversationProvider` is created instead of
  when the user first sends a message.

## 0.4.3

- BUILD: Updated dependencies.

## 0.4.2

- FIX: handling transcription in voice mode provider.

## 0.4.1

- FEAT: Using assistant repository factory on `ConversationProvider`.

## 0.4.0

- FEAT: Prevent screen from turning off when in voice mode.

## 0.3.4

- FIX: Stop voice mode notifies the UI

## 0.3.3

- Log: Added logs to voice mode transcription

## 0.3.2

- Fixed: Voice mode provider transcription

## 0.3.1

- Updated dependencies
- Refac to comply with new `TranscribeModel` from dart api.

## 0.3.0

- FEAT: `ConversationProvider` now has onJsonComplete on constructor.

## 0.2.0

- FEAT: `ConversationsProvider` loads conversations in parallel.

## 0.1.1

- miniFEAT: `ConversationProvider` constructor with selected assistant

## 0.1.0

- FEAT: Removed vibration package.
- FEAT: Dynamic function call for when user finishes speaking (by using `VitGptFlutterConfiguration`).
- FIX: Removed call to non existing asset.

## 0.0.6

- FIX: Stop user listening if user canceled voice mode.

## 0.0.5

- Refac: Stop voice interaction

## 0.0.4

- FIX: Stop voice interaction

## 0.0.3

- FIX: Removed test error

## 0.0.2

- Added method "updateUI" to `ConversationProvider` (to prevent error of protected members of a class).

## 0.0.1

- Initial release.
