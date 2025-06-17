// lib/services/telegram_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuflix/models/content_item.dart';

class TelegramService {
  /* ─────────────────── Preference keys ─────────────────── */
  static const _botTokenKey = 'telegram_bot_token';
  static const _chatIdKey   = 'telegram_chat_id';
  static SharedPreferences? _prefs;

  /* ─────────── Shared-Preferences helpers ─────────── */
  static Future<SharedPreferences?> _prefsAsync() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<String?> _getToken() async =>
      (await _prefsAsync())?.getString(_botTokenKey);

  static Future<String?> _getChatId() async =>
      (await _prefsAsync())?.getString(_chatIdKey);

  static Future<void> _saveToken(String token) async =>
      (await _prefsAsync())?.setString(_botTokenKey, token.trim());

  static Future<void> _saveChatId(String chatId) async =>
      (await _prefsAsync())?.setString(_chatIdKey, chatId);

  static Future<void> clearCredentials() async {
    final p = await _prefsAsync();
    await p?.remove(_botTokenKey);
    await p?.remove(_chatIdKey);
  }

  /* ──────────────── Validation helpers ──────────────── */
  static final _tokenRegex =
      RegExp(r'^[0-9]{8,10}:[A-Za-z0-9_\-]{35}$');            // format check [26]

  static bool isTokenFormatValid(String token) =>
      _tokenRegex.hasMatch(token.trim());

  /// remote check against `getMe` [25]
  static Future<bool> _isTokenValid(String token) async {
    final r = await http.get(
        Uri.parse('https://api.telegram.org/bot$token/getMe'));
    return r.statusCode == 200 &&
        (jsonDecode(r.body)['ok'] as bool? ?? false);
  }

  /* ───────────── Chat-ID discovery helper ───────────── */
  /* ─ inside TelegramService.dart ─ */

/* 1. guarantee the chat-ID is stored the very first time it is discovered */
static Future<String?> _fetchChatId(String token) async {
  final updatesUri = Uri.parse('https://api.telegram.org/bot$token/getUpdates');
  http.Response res = await http.get(updatesUri);

  if (res.statusCode == 409) {
    await http.get(Uri.parse(
      'https://api.telegram.org/bot$token/deleteWebhook?drop_pending_updates=true'));
    res = await http.get(updatesUri);
  }

  if (res.statusCode != 200) return null;
  final data = jsonDecode(res.body);
  if (data['ok'] != true) return null;

  for (final upd in (data['result'] as List).reversed) {
    final chat = upd['message']?['chat'];
    if (chat?['id'] != null) {
      final chatId = chat['id'].toString();
      await _saveChatId(chatId);         // <-- NEW line (persists chat-ID)
      return chatId;
    }
  }
  return null;
}

  /* ───────────── Public convenience API ───────────── */
  static Future<bool> isSetupComplete() async =>
      (await _getToken())?.isNotEmpty == true &&
      (await _getChatId())?.isNotEmpty == true;

  /// Saves credentials after verifying token & chat-id
  static Future<bool> saveCredentials(String token) async {
    if (!isTokenFormatValid(token)) return false;
    if (!await _isTokenValid(token)) return false;
    await _saveToken(token);
    final chatId = await _fetchChatId(token);
    if (chatId == null) return false;
    await _saveChatId(chatId);
    return true;
  }

  /* ───────────── Sending files to Telegram ───────────── */
  static Future<bool> sendContent({
    required ContentItem content,
    required int linkIndex,
    String? tempTokenOverride,
  }) async {
    final token = tempTokenOverride?.trim() ?? await _getToken();
    final chatId = await _getChatId() ?? await _recoverChatId(token);

    if (token == null || chatId == null) {
      throw Exception('SETUP_INCOMPLETE');
    }

    final links = content.availableLinks;
    if (linkIndex >= links.length) return false;

    final ids = links[linkIndex].split(',').map((e) => e.trim()).toList();
    final baseCaption = _buildCaption(content, linkIndex);

    var overall = true;
    for (var i = 0; i < ids.length; i++) {
      final ok = await _sendSingleFile(
        token: token,
        chatId: chatId,
        fileId: ids[i],
        caption:
            ids.length == 1 ? baseCaption : '$baseCaption – Episode ${i + 1}',
      );
      overall &= ok;
      if (i < ids.length - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return overall;
  }

  /* ───── Back-compat wrappers for old method names ───── */
  static Future<bool> sendContentFiles({
    required ContentItem content,
    required int linkIndex,
    String? providedBotToken,
  }) =>
      sendContent(
        content: content,
        linkIndex: linkIndex,
        tempTokenOverride: providedBotToken,
      );

  static Future<void> clearStoredCredentials() => clearCredentials();
  static Future<String?> getStoredBotToken() => _getToken();
  static Future<void> saveBotToken(String token) => _saveToken(token);
  static bool isValidBotToken(String token) => isTokenFormatValid(token);

  /* ───────────── Internal single-file sender ───────────── */
  static const _endpoints = [
    'sendDocument',
    'sendVideo',
    'sendAudio',
    'sendAnimation',
  ];

  static Future<bool> _sendSingleFile({
    required String token,
    required String chatId,
    required String fileId,
    required String caption,
  }) async {
    for (final ep in _endpoints) {
      final resp = await http.post(
        Uri.parse('https://api.telegram.org/bot$token/$ep'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'chat_id': chatId,
          _fileField(ep): fileId,
          'caption': caption,
        },
      );
      if (resp.statusCode == 200 &&
          (jsonDecode(resp.body)['ok'] as bool? ?? false)) {
        return true; // success
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return false; // all endpoints failed
  }

  static String _fileField(String ep) =>
      ep == 'sendVideo'
          ? 'video'
          : ep == 'sendAudio'
              ? 'audio'
              : ep == 'sendAnimation'
                  ? 'animation'
                  : 'document';

  /* ───────────── Caption builder ───────────── */
  static String _buildCaption(ContentItem c, int idx) {
    final sb = StringBuffer('🎬 ${c.name}');
    if (c.isTVShow || c.isAnimeSeries) sb.write(' – Season ${idx + 1}');
    sb.write('\n📺 ${c.contentType}');
    if (c.category.isNotEmpty) sb.write(' • ${c.category}');
    sb.write(
        '\n\n🎯 Sent via CU-FLIX\nNOTE: This app is for testing purposes and hosts no content.');
    return sb.toString();
  }

  /* ───────────── Chat-id recovery helper ───────────── */
  static Future<String?> _recoverChatId(String? token) async {
  if (token == null) return null;
  var chatId = await _getChatId();
  chatId ??= await _fetchChatId(token);
  return chatId;
}
}
