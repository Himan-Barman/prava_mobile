// Skipped message keys
import 'dart:typed_data';

/// ============================================================
/// Skipped Message Keys Storage
/// ============================================================
/// Handles out-of-order message delivery:
///
/// Problem:
/// • Messages may arrive out of order
/// • Each message key is used exactly once
/// • Must store skipped keys for later use
///
/// Solution:
/// • Store (ratchet_public_key, message_index) -> message_key
/// • Limit maximum stored keys (prevent DoS)
/// • Expire old keys after timeout
///
/// Security Considerations:
/// • Maximum skip limit prevents memory exhaustion
/// • Keys are deleted after use
/// • Optional expiration for old keys
/// ============================================================
final class SkippedMessageKeys {
  final Map<String, SkippedKey> _keys = {};

  /// Maximum number of skipped keys per session
  static const int maxSkippedKeys = 1000;

  /// Maximum keys to skip in a single chain
  static const int maxSkipPerChain = 500;

  /// Key expiration time (24 hours)
  static const Duration keyExpiration = Duration(hours: 24);

  /// Number of stored keys
  int get count => _keys.length;

  /// Check if we have a key for this message
  bool hasKey(Uint8List ratchetPublicKey, int messageIndex) {
    final keyId = _makeKeyId(ratchetPublicKey, messageIndex);
    return _keys.containsKey(keyId);
  }

  /// Get and remove a skipped key
  Uint8List?  consumeKey(Uint8List ratchetPublicKey, int messageIndex) {
    final keyId = _makeKeyId(ratchetPublicKey, messageIndex);
    final skipped = _keys.remove(keyId);

    if (skipped == null) return null;

    // Check expiration
    if (skipped.isExpired) {
      _zeroize(skipped. messageKey);
      return null;
    }

    return skipped.messageKey;
  }

  /// Store a skipped key
  void storeKey(
    Uint8List ratchetPublicKey,
    int messageIndex,
    Uint8List messageKey,
  ) {
    // Enforce maximum keys
    if (_keys.length >= maxSkippedKeys) {
      _evictOldest();
    }

    final keyId = _makeKeyId(ratchetPublicKey, messageIndex);
    _keys[keyId] = SkippedKey(
      messageKey:  Uint8List.fromList(messageKey),
      storedAt: DateTime. now(),
    );
  }

  /// Store multiple skipped keys
  void storeKeys(
    Uint8List ratchetPublicKey,
    Map<int, Uint8List> keys,
  ) {
    for (final entry in keys.entries) {
      storeKey(ratchetPublicKey, entry.key, entry.value);
    }
  }

  /// Remove expired keys
  void removeExpired() {
    final expired = <String>[];

    for (final entry in _keys.entries) {
      if (entry.value. isExpired) {
        expired.add(entry.key);
        _zeroize(entry.value.messageKey);
      }
    }

    for (final keyId in expired) {
      _keys.remove(keyId);
    }
  }

  /// Remove all keys for a ratchet public key
  void removeForRatchetKey(Uint8List ratchetPublicKey) {
    final prefix = _keyPrefix(ratchetPublicKey);
    final toRemove = <String>[];

    for (final entry in _keys.entries) {
      if (entry.key.startsWith(prefix)) {
        toRemove. add(entry.key);
        _zeroize(entry.value.messageKey);
      }
    }

    for (final keyId in toRemove) {
      _keys.remove(keyId);
    }
  }

  /// Clear all keys
  void clear() {
    for (final key in _keys.values) {
      _zeroize(key.messageKey);
    }
    _keys.clear();
  }

  /// Serialize for storage
  Map<String, dynamic> toJson() {
    final keysJson = <String, dynamic>{};

    for (final entry in _keys.entries) {
      keysJson[entry.key] = {
        'messageKey': entry.value. messageKey.toList(),
        'storedAt': entry. value.storedAt.millisecondsSinceEpoch,
      };
    }

    return {'keys': keysJson};
  }

  /// Deserialize from storage
  factory SkippedMessageKeys.fromJson(Map<String, dynamic> json) {
    final instance = SkippedMessageKeys();

    final keysJson = json['keys'] as Map<String, dynamic>? ??  {};
    for (final entry in keysJson.entries) {
      final data = entry.value as Map<String, dynamic>;
      instance._keys[entry. key] = SkippedKey(
        messageKey:  Uint8List. fromList((data['messageKey'] as List).cast<int>()),
        storedAt: DateTime.fromMillisecondsSinceEpoch(data['storedAt'] as int),
      );
    }

    return instance;
  }

  /// Create unique key ID
  String _makeKeyId(Uint8List ratchetPublicKey, int messageIndex) {
    return '${_keyPrefix(ratchetPublicKey)}: $messageIndex';
  }

  /// Get key prefix from ratchet public key
  String _keyPrefix(Uint8List ratchetPublicKey) {
    return ratchetPublicKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Evict oldest key
  void _evictOldest() {
    if (_keys.isEmpty) return;

    String?  oldestKey;
    DateTime?  oldestTime;

    for (final entry in _keys.entries) {
      if (oldestTime == null || entry.value.storedAt. isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.storedAt;
      }
    }

    if (oldestKey != null) {
      final removed = _keys.remove(oldestKey);
      if (removed != null) {
        _zeroize(removed. messageKey);
      }
    }
  }

  /// Zero a buffer
  void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}

/// Stored skipped key
class SkippedKey {
  final Uint8List messageKey;
  final DateTime storedAt;

  const SkippedKey({
    required this.messageKey,
    required this.storedAt,
  });

  /// Check if key is expired
  bool get isExpired {
    final age = DateTime.now().difference(storedAt);
    return age > SkippedMessageKeys.keyExpiration;
  }
}