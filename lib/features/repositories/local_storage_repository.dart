import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

class LocalStorageRepository extends LocalStorageModel {
  final SharedPreferences preferences;
  final Database db;

  LocalStorageRepository(this.preferences, this.db);

  /// Creates any necessary tables, indexes, or triggers required to use
  /// this class.
  ///
  /// Any maintenance to the database could also execute.
  Future<void> prepare() async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS thread_titles (
        id TEXT PRIMARY KEY,
        title TEXT
      );
    ''');
  }

  @override
  Future<void> saveApiToken(String token) async {
    await preferences.setString('apiToken', token);
  }

  @override
  Future<String?> getApiToken() async {
    String? value = preferences.getString('apiToken');
    return value;
  }

  @override
  Future<void> deleteThread(String id) async {
    var ids = await getThreads();
    ids.remove(id);
    await preferences.setStringList('threadIds', ids);

    // Delete the thread title from SQLite
    db.execute(
      'DELETE FROM thread_titles WHERE id = ?',
      [id],
    );
  }

  @override
  Future<List<String>> getThreads() async {
    var ids = preferences.getStringList('threadIds');
    return ids ?? [];
  }

  @override
  Future<void> saveThread(String id) async {
    var ids = await getThreads();
    if (!ids.contains(id)) {
      ids.add(id);
    }
    await preferences.setStringList('threadIds', ids);
  }

  @override
  Future<GptModel?> getChatModel() async {
    var model = preferences.getString('model');
    return GptModel.fromString(model ?? '');
  }

  @override
  Future<void> saveChatModel(GptModel model) async {
    await preferences.setString('model', model.toString());
  }

  @override
  Future<Duration?> getThreadsTtl() async {
    var days = preferences.getInt('threads_ttl');
    return days != null ? Duration(days: days) : null;
  }

  @override
  Future<void> saveThreadsTtl(Duration duration) async {
    await preferences.setInt('threads_ttl', duration.inDays);
  }

  @override
  Future<String?> getTranscriptionLanguage() async {
    var lang = preferences.getString('tts_lang');
    return lang;
  }

  @override
  Future<void> saveTranscriptionLanguage(String lang) async {
    await preferences.setString('tts_lang', lang);
  }

  @override
  Future<bool?> getTtsQuality() async {
    var quality = preferences.getBool('tts_quality');
    return quality;
  }

  @override
  Future<void> saveTtsQuality(bool highQuality) async {
    await preferences.setBool('tts_quality', highQuality);
  }

  @override
  Future<String?> getSpeakerVoice() async {
    return preferences.getString('speaker_voice');
  }

  @override
  Future<void> saveSpeakerVoice(String? voice) async {
    if (voice == null) {
      await preferences.remove('speaker_voice');
      return;
    }
    await preferences.setString('speaker_voice', voice);
  }

  @override
  Future<MicSendMode?> getMicSendMode() async {
    var value = preferences.getString('mic_send_mode');
    if (value == null) return null;
    return MicSendMode.fromString(value);
  }

  @override
  Future<void> saveMicSendMode(MicSendMode value) async {
    await preferences.setString('mic_send_mode', value.toString());
  }

  /// Uses sqlite3 to fetch the thread title.
  @override
  Future<String?> getThreadTitle(String id) async {
    var result = db.select(
      'SELECT title FROM thread_titles WHERE id = ?',
      [id],
    );

    if (result.isNotEmpty) {
      return result.first['title'] as String;
    } else {
      return null;
    }
  }

  /// Uses sqlite3 to save thread title.
  @override
  Future<void> saveThreadTitle(String id, String title) async {
    db.execute(
      'INSERT OR REPLACE INTO thread_titles (id, title) VALUES (?, ?)',
      [id, title],
    );
  }

  /// Should produce a map of thread titles where the keys are the ids and the
  /// values are the titles.
  ///
  /// It is possible that an id is not found in the database, that why we need
  /// a map.
  @override
  Future<Map<String, String>> getThreadsTitle(Iterable<String> ids) async {
    Map<String, String> titlesMap = {};

    // Convert the Iterable into a comma-separated string for SQL IN clause
    var placeholders = ids.map((_) => '?').join(',');

    var query =
        'SELECT id, title FROM thread_titles WHERE id IN ($placeholders)';
    var result = db.select(query, ids.toList());

    for (var row in result) {
      var id = row['id'] as String;
      var title = row['title'] as String;
      titlesMap[id] = title;
    }

    return titlesMap;
  }

  @override
  Future<Duration?> getSentenceInterval() async {
    var inMilli = preferences.getInt('max_sentence_delay');
    if (inMilli == null) return null;
    return Duration(milliseconds: inMilli);
  }

  @override
  Future<void> saveSentenceInterval(Duration value) async {
    await preferences.setInt('max_sentence_delay', value.inMilliseconds);
  }
}
