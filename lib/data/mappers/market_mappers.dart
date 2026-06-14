import '../../domain/entities/chat_models.dart';
import '../../domain/entities/commodity.dart';
import '../../domain/entities/nearby_buyer.dart';
import '../../domain/entities/product_listing.dart';

Commodity commodityFromMap(Map<String, dynamic> m) {
  return Commodity(
    id: m['id'] as String,
    name: m['name'] as String,
    unit: m['unit'] as String,
    priceNgn: (m['priceNgn'] as num).toInt(),
    changePct: (m['changePct'] as num).toDouble(),
    category: m['category'] as String,
  );
}

ProductListing productFromMap(Map<String, dynamic> m) {
  return ProductListing(
    id: m['id'] as String,
    title: m['title'] as String,
    description: m['description'] as String,
    priceNgn: (m['priceNgn'] as num).toInt(),
    quantityKg: (m['quantityKg'] as num).toInt(),
    state: m['state'] as String,
    city: m['city'] as String,
    sellerId: m['sellerId'] as String,
    sellerName: m['sellerName'] as String,
    sellerRating: (m['sellerRating'] as num).toDouble(),
    verified: m['verified'] as bool,
    availability: switch (m['availability'] as String?) {
      'limited' => ProductAvailability.limited,
      'sold_out' => ProductAvailability.soldOut,
      _ => ProductAvailability.inStock,
    },
    imageUrl: m['imageUrl'] as String,
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
  );
}

NearbyBuyer buyerFromMap(Map<String, dynamic> m) {
  return NearbyBuyer(
    id: m['id'] as String,
    name: m['name'] as String,
    type: m['type'] as String,
    state: m['state'] as String,
    distanceKm: (m['distanceKm'] as num).toInt(),
    rating: (m['rating'] as num).toDouble(),
    verified: m['verified'] as bool,
  );
}

ChatThread chatThreadFromMap(Map<String, dynamic> m) {
  return ChatThread(
    id: m['id'] as String,
    peerId: m['peerId'] as String,
    peerName: m['peerName'] as String,
    peerRole: m['peerRole'] as String,
    lastMessage: m['lastMessage'] as String,
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    unread: (m['unread'] as num).toInt(),
  );
}

ChatMessage chatMessageFromMap(Map<String, dynamic> m) {
  return ChatMessage(
    id: m['id'] as String,
    threadId: m['threadId'] as String,
    fromMe: m['fromMe'] as bool,
    text: m['text'] as String,
    sentAt: DateTime.parse(m['sentAt'] as String),
    kind: switch (m['kind'] as String?) {
      'image' => ChatMessageKind.image,
      'voice' => ChatMessageKind.voice,
      _ => ChatMessageKind.text,
    },
  );
}
