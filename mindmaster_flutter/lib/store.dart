// MindMaster — persistence layer.
//
// Keeps the same data model as the web build: player profile,
// per-game/difficulty high scores, full session history, and
// achievements. Backed by shared_preferences (JSON) so it works
// on Android, Linux, and any desktop target without extra setup.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Session {
  final String id;
  final String game;
  final String difficulty;
  final int score;
  final int correct;
  final int total;
  final int errors;
  final int durationSeconds;
  final DateTime timestamp;

  Session({
    required this.id,
    required this.game,
    required this.difficulty,
    required this.score,
    required this.correct,
    required this.total,
    required this.errors,
    required this.durationSeconds,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'game': game,
        'difficulty': difficulty,
        'score': score,
        'correct': correct,
        'total': total,
        'errors': errors,
        'duration': durationSeconds,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        game: j['game'] as String,
        difficulty: (j['difficulty'] as String?) ?? 'medium',
        score: (j['score'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        errors: (j['errors'] as num?)?.toInt() ?? 0,
        durationSeconds: (j['duration'] as num?)?.toInt() ?? 0,
        timestamp:
            DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

class Player {
  Player();

  int xp = 0;
  int level = 1;
  int totalGames = 0;
  bool soundOn = true;
  bool hapticsOn = true;
  String theme = 'dark';

  int get xpToNext => 500 + (level - 1) * 250;

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'level': level,
        'totalGames': totalGames,
        'soundOn': soundOn,
        'hapticsOn': hapticsOn,
        'theme': theme,
      };

  factory Player.fromJson(Map<String, dynamic> j) => Player()
    ..xp = (j['xp'] as num?)?.toInt() ?? 0
    ..level = (j['level'] as num?)?.toInt() ?? 1
    ..totalGames = (j['totalGames'] as num?)?.toInt() ?? 0
    ..soundOn = j['soundOn'] as bool? ?? true
    ..hapticsOn = j['hapticsOn'] as bool? ?? true
    ..theme = j['theme'] as String? ?? 'dark';
}

class Store {
  Store._();

  static final Store instance = Store._();

  late SharedPreferences _prefs;
  Player player = Player();
  final List<Session> sessions = <Session>[];
  final List<String> achievements = <String>[];

  static const _kPlayer = 'mm_player';
  static const _kSessions = 'mm_sessions';
  static const _kAchievements = 'mm_achievements';
  static const _kHighScores = 'mm_highscores';

  /// Hard cap so the JSON blob (and the leaderboard render) stay fast.
  static const _maxSessions = 500;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final pj = _prefs.getString(_kPlayer);
    if (pj != null) {
      try {
        player = Player.fromJson(jsonDecode(pj) as Map<String, dynamic>);
      } catch (_) {
        player = Player();
      }
    }

    final sj = _prefs.getString(_kSessions);
    if (sj != null) {
      try {
        sessions
          ..clear()
          ..addAll((jsonDecode(sj) as List)
              .map((e) => Session.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        sessions.clear();
      }
    }

    final aj = _prefs.getString(_kAchievements);
    if (aj != null) {
      try {
        achievements
          ..clear()
          ..addAll((jsonDecode(aj) as List).cast<String>());
      } catch (_) {
        achievements.clear();
      }
    }
  }

  Future<void> _savePlayer() =>
      _prefs.setString(_kPlayer, jsonEncode(player.toJson()));

  Future<void> _saveSessions() =>
      _prefs.setString(_kSessions, jsonEncode(sessions.map((s) => s.toJson()).toList()));

  Future<void> _saveAchievements() =>
      _prefs.setString(_kAchievements, jsonEncode(achievements));

  /// Record a finished game: bump profile, log the session, and
  /// persist the high score for that game/difficulty.
  Future<void> recordSession(Session s) async {
    sessions.insert(0, s);
    if (sessions.length > _maxSessions) {
      sessions.removeRange(_maxSessions, sessions.length);
    }
    await _saveSessions();

    player.totalGames++;
    player.xp += s.score ~/ 10 + 10;
    while (player.xp >= player.xpToNext) {
      player.xp -= player.xpToNext;
      player.level++;
    }
    await _savePlayer();

    await saveHighScore(s.game, s.difficulty, s.score);
  }

  Future<void> saveHighScore(String game, String difficulty, int score) async {
    final key = '$game:$difficulty';
    final all = _prefs.getString(_kHighScores);
    final map = <String, dynamic>{};
    if (all != null) {
      try {
        map.addAll(jsonDecode(all) as Map<String, dynamic>);
      } catch (_) {}
    }
    final prev = (map[key] as num?)?.toInt() ?? 0;
    if (score > prev) {
      map[key] = score;
      await _prefs.setString(_kHighScores, jsonEncode(map));
    }
  }

  int highScore(String game, String difficulty) {
    final all = _prefs.getString(_kHighScores);
    if (all == null) return 0;
    try {
      final map = jsonDecode(all) as Map<String, dynamic>;
      return (map['$game:$difficulty'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Per-game stats: session count, best score, total score.
  ({int plays, int best, int total}) statsFor(String game) {
    final forGame = sessions.where((s) => s.game == game).toList();
    if (forGame.isEmpty) return (plays: 0, best: 0, total: 0);
    return (
      plays: forGame.length,
      best: forGame.map((s) => s.score).reduce((a, b) => a > b ? a : b),
      total: forGame.fold<int>(0, (sum, s) => sum + s.score),
    );
  }

  List<Session> topScores({int limit = 10}) {
    final sorted = [...sessions]..sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(limit).toList();
  }

  Future<void> unlock(String id) async {
    if (achievements.contains(id)) return;
    achievements.add(id);
    await _saveAchievements();
  }

  Future<void> updateSettings({bool? sound, bool? haptics}) async {
    if (sound != null) player.soundOn = sound;
    if (haptics != null) player.hapticsOn = haptics;
    await _savePlayer();
  }

  Future<void> resetAll() async {
    sessions.clear();
    achievements.clear();
    player = Player();
    await _prefs.remove(_kSessions);
    await _prefs.remove(_kAchievements);
    await _prefs.remove(_kHighScores);
    await _savePlayer();
  }
}