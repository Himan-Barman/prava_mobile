import 'dart:convert';
import 'dart:typed_data';

/// Manages skipped message keys for out-of-order message delivery
class SkippedMessageKeys {
  /// Maximum number of keys to skip per chain
  static const int maxSkipPerChain = 1000;

  /// Maximum total skipped keys to store
  static const int maxTotalKeys = 5000;

  /// Key expiration time in milliseconds (7 days)
  static const int expirationMs = 7 * 24 * 60 * 60 * 1000;

  /// Stored skipped keys:  Map<ratchetPublicKeyHex, Map<messageNumber, StoredKey>>
  final Map<String, Map<int, _StoredKey>> _keys;

  /// Private constructor
  SkippedMessageKeys. _(this._keys);

  /// Create empty instance
  factory SkippedMessageKeys.empty() {
    return SkippedMessageKeys._({});
  }

  /// Create from JSON
  factory SkippedMessageKeys.fromJson(Map<String, dynamic> json) {
    final keys = <String, Map<int, _StoredKey>>{};

    for (final entry in json.entries) {
      final chainKeys = <int, _StoredKey>{};
      final chainData = entry.value as Map<String, dynamic>;

      for (final keyEntry in chainData.entries) {
        final messageNum = int.parse(keyEntry.key);
        final stored = keyEntry.value as Map<String, dynamic>;
        chainKeys[messageNum] = _StoredKey(
          key:  Uint8List.fromList((stored['key'] as List).cast<int>()),
          timestamp: stored['timestamp'] as int,
        );
      }

      keys[entry. key] = chainKeys;
    }

    return SkippedMessageKeys. _(keys);
  }

  /// Number of stored keys
  int get count {
    var total = 0;
    for (final chain in _keys.values) {
      total += chain.length;
    }
    return total;
  }

  /// Store a skipped message key
  void storeKey(
    Uint8List ratchetPublicKey,
    int messageNumber,
    Uint8List messageKey,
  ) {
    if (count >= maxTotalKeys) {
      _removeOldest();
    }

    final keyHex = _bytesToHex(ratchetPublicKey);
    _keys. putIfAbsent(keyHex, () => {});
    _keys[keyHex]![messageNumber] = _StoredKey(
      key: Uint8List.fromList(messageKey),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Consume (get and remove) a skipped message key
  Uint8List?  consumeKey(Uint8List ratchetPublicKey, int messageNumber) {
    final keyHex = _bytesToHex(ratchetPublicKey);
    final chain = _keys[keyHex];
    if (chain == null) return null;

    final stored = chain. remove(messageNumber);
    if (stored == null) return null;

    if (chain.isEmpty) {
      _keys.remove(keyHex);
    }

    return stored.key;
  }

  /// Remove expired keys
  void removeExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - expirationMs;

    for (final chain in _keys.values) {
      chain.removeWhere((_, stored) => stored.timestamp < cutoff);
    }

    _keys.removeWhere((_, chain) => chain.isEmpty);
  }

  /// Clear all keys
  void clear() {
    for (final chain in _keys.values) {
      for (final stored in chain.values) {
        _zeroize(stored. key);
      }
    }
    _keys.clear();
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    for (final entry in _keys.entries) {
      final chainData = <String, dynamic>{};
      for (final keyEntry in entry. value.entries) {
        chainData[keyEntry.key. toString()] = {
          'key':  keyEntry.value. key.toList(),
          'timestamp':  keyEntry.value. timestamp,
        };
      }
      result[entry.key] = chainData;
    }

    return result;
  }

  void _removeOldest() {
    int?  oldestTime;
    String? oldestChain;
    int? oldestNumber;

    for (final entry in _keys.entries) {
      for (final keyEntry in entry.value.entries) {
        if (oldestTime == null || keyEntry.value. timestamp < oldestTime) {
          oldestTime = keyEntry. value.timestamp;
          oldestChain = entry.key;
          oldestNumber = keyEntry.key;
        }
      }
    }

    if (oldestChain != null && oldestNumber != null) {
      final stored = _keys[oldestChain]?. remove(oldestNumber);
      if (stored != null) {
        _zeroize(stored.key);
      }
      if (_keys[oldestChain]?.isEmpty ??  false) {
        _keys.remove(oldestChain);
      }
    }
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}

class _StoredKey {
  final Uint8List key;
  final int timestamp;

  _StoredKey({required this.key, required this.timestamp});
}