// lib/services/telegram_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuflix/models/content_item.dart';

class TelegramService {
  static const String _botTokenKey = 'telegram_bot_token';
  static const String _chatIdKey = 'telegram_chat_id';
  static SharedPreferences? _prefs;

  // Initialize SharedPreferences with error handling
  static Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs;
    } catch (e) {
      // print('SharedPreferences error: $e');
      return null;
    }
  }

  // Get stored bot token
  static Future<String?> getStoredBotToken() async {
    try {
      final prefs = await _getPrefs();
      return prefs?.getString(_botTokenKey);
    } catch (e) {
      // print('Error getting stored bot token: $e');
      return null;
    }
  }

  // Save bot token
  static Future<void> saveBotToken(String token) async {
    try {
      final prefs = await _getPrefs();
      await prefs?.setString(_botTokenKey, token);
    } catch (e) {
      // print('Error saving bot token: $e');
    }
  }

  // Get stored chat ID
  static Future<String?> getStoredChatId() async {
    try {
      final prefs = await _getPrefs();
      return prefs?.getString(_chatIdKey);
    } catch (e) {
      return null;
    }
  }

  // Save chat ID
  static Future<void> saveChatId(String chatId) async {
    try {
      final prefs = await _getPrefs();
      await prefs?.setString(_chatIdKey, chatId);
    } catch (e) {
      // print('Error saving chat ID: $e');
      return;
    }
  }

  // Check if setup is complete
  static Future<bool> isSetupComplete() async {
    final botToken = await getStoredBotToken();
    final chatId = await getStoredChatId();
    return botToken != null && chatId != null && botToken.isNotEmpty && chatId.isNotEmpty;
  }

  // Clear stored credentials (for reset)
  static Future<void> clearStoredCredentials() async {
    try {
      final prefs = await _getPrefs();
      await prefs?.remove(_botTokenKey);
      await prefs?.remove(_chatIdKey);
    } catch (e) {
      return;
    }
  }

  // Auto-detect chat ID from bot updates
  static Future<String?> getChatId(String botToken) async {
    try {
      final url = 'https://api.telegram.org/bot$botToken/getUpdates';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (!data['ok']) {
          throw Exception('Bot token is invalid');
        }
        
        final results = data['result'] as List;
        
        if (results.isEmpty) {
          return null;
        }

        // Process latest updates first to find chat ID
        for (final update in results.reversed) {
          final message = update['message'];
          if (message != null) {
            final chat = message['chat'];
            if (chat != null) {
              final chatId = chat['id'].toString();
              // Automatically save the chat ID when found
              await saveChatId(chatId);
              return chatId;
            }
          }
        }
        return null;
      } else {
        throw Exception('Failed to fetch updates: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Send content files to Telegram (with automatic setup check)
  static Future<bool> sendContentFiles({
    required ContentItem content,
    required int linkIndex,
    String? providedBotToken, // Optional: for first-time setup
  }) async {
    try {
      String? botToken = providedBotToken ?? await getStoredBotToken();
      String? chatId = await getStoredChatId();

      // If we have a provided token but no stored chat ID, fetch it
      if (botToken != null && chatId == null) {
        chatId = await getChatId(botToken);
        if (chatId == null) {
          throw Exception('CHAT_ID_NOT_FOUND');
        }
      }

      // If we still don't have both, throw error
      if (botToken == null || chatId == null) {
        throw Exception('SETUP_INCOMPLETE');
      }

      // Save the bot token if it was provided
      if (providedBotToken != null) {
        await saveBotToken(providedBotToken);
      }

      final links = content.availableLinks;
      if (linkIndex >= links.length) return false;

      final fileIds = links[linkIndex].split(',').map((id) => id.trim()).toList();
      final caption = _createCaption(content, linkIndex);
      
      bool allSuccess = true;
      for (int i = 0; i < fileIds.length; i++) {
        final fileId = fileIds[i];
        final episodeCaption = fileIds.length > 1 
            ? '$caption - Episode ${i + 1}' 
            : caption;
            
        final success = await _sendSingleFile(
          botToken: botToken,
          chatId: chatId,
          fileId: fileId,
          caption: episodeCaption,
        );
        
        if (!success) {
          allSuccess = false;
        }
        
        if (i < fileIds.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      
      return allSuccess;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> _sendSingleFile({
    required String botToken,
    required String chatId,
    required String fileId,
    required String caption,
  }) async {
    try {
      final endpoints = [
        'sendDocument',
        'sendVideo', 
        'sendAudio',
        'sendAnimation',
      ];
      
      for (final endpoint in endpoints) {
        final url = 'https://api.telegram.org/bot$botToken/$endpoint';
        
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'chat_id': chatId,
            _getFileFieldName(endpoint): fileId,
            'caption': caption,
          },
        );
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['ok']) {
            return true;
          }
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
      }
    
      return false;
    } catch (e) {
      return false;
    }
  }

  static String _getFileFieldName(String endpoint) {
    switch (endpoint) {
      case 'sendVideo': return 'video';
      case 'sendAudio': return 'audio';
      case 'sendAnimation': return 'animation';
      default: return 'document';
    }
  }

  static String _createCaption(ContentItem content, int linkIndex) {
    String caption = '🎬 ${content.name}';
    
    if (content.isTVShow || content.isAnimeSeries) {
      final seasonNumber = linkIndex + 1;
      caption += ' - Season $seasonNumber';
    }
    
    caption += '\n📺 ${content.contentType}';
    if (content.category.isNotEmpty) {
      caption += ' • ${content.category}';
    }
    
    caption += '\n\n🎯 Sent via CU-FLIX\n NOTE: We Do Not Own Any Content And This App Is Only For Testing Purpose.';
    
    return caption;
  }

  static bool isValidBotToken(String token) {
    final regex = RegExp(r'^\d+:[A-Za-z0-9_-]+$');
    return regex.hasMatch(token);
  }
}
