import '../../domain/entities/chat_models.dart';
import '../datasources/asset_bundle_datasource.dart';
import '../mappers/market_mappers.dart';

class ChatRepository {
  ChatRepository(this._assets);
  final AssetBundleDataSource _assets;

  static const _asset = 'assets/mock/chat_threads.json';

  Future<List<ChatThread>> threads() async {
    final fixture = await _assets.loadJson(_asset);
    final items = (fixture['threads'] as List).cast<Map<String, dynamic>>();
    return items.map(chatThreadFromMap).toList();
  }

  Future<List<ChatMessage>> messages(String threadId) async {
    final fixture = await _assets.loadJson(_asset);
    final key = 'messages_$threadId';
    final items = (fixture[key] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map(chatMessageFromMap).toList();
  }
}
