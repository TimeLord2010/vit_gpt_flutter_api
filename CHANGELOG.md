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

* BUILD: Updated dependencies.

## 0.4.2

* FIX: handling transcription in voice mode provider.

## 0.4.1

* FEAT: Using assistant repository factory on `ConversationProvider`.

## 0.4.0

* FEAT: Prevent screen from turning off when in voice mode.

## 0.3.4

* FIX: Stop voice mode notifies the UI

## 0.3.3

* Log: Added logs to voice mode transcription

## 0.3.2

* Fixed: Voice mode provider transcription

## 0.3.1

* Updated dependencies
* Refac to comply with new `TranscribeModel` from dart api.

## 0.3.0

* FEAT: `ConversationProvider` now has onJsonComplete on constructor.

## 0.2.0

* FEAT: `ConversationsProvider` loads conversations in parallel.

## 0.1.1

* miniFEAT: `ConversationProvider` constructor with selected assistant

## 0.1.0

* FEAT: Removed vibration package.
* FEAT: Dynamic function call for when user finishes speaking (by using `VitGptFlutterConfiguration`).
* FIX: Removed call to non existing asset.

## 0.0.6

* FIX: Stop user listening if user canceled voice mode.

## 0.0.5

* Refac: Stop voice interaction

## 0.0.4

* FIX: Stop voice interaction

## 0.0.3

* FIX: Removed test error

## 0.0.2

* Added method "updateUI" to `ConversationProvider` (to prevent error of protected members of a class).

## 0.0.1

* Initial release.
