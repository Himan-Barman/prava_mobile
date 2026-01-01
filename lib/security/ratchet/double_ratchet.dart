import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import '../crypto/hashing.dart';
import '../crypto/key_generation.dart';
import 'chain_key.dart';
import 'message_keys.dart';
import 'skipped_keys.dart';

/// ============================================================
/// Double Ratchet Algorithm
/// ============================================================
/// Core encryption engine for Signal Protocol: 
///
/// Two Ratchets:
/// 1.  Diffie-Hellman Ratchet (asymmetric)
///    • Updates root key with new DH output
///    • Triggered on receiving new ratchet public key
///    • Provides post-compromise security
///
/// 2. Symmetric-Key Ratchet (chain keys)
///    • Derives message keys from chain key
///    • Advances after each message
///    • Provides forward secrecy
///
/// Security Properties:
/// • Forward secrecy:  Compromise doesn't reveal past messages
/// • Post-compromise security: Session heals after compromise
/// • Out-of-order tolerance: Handles network reordering
///
/// Standards:  Signal Protocol Specification
/// ============================================================
final class DoubleRatchet {
  /// Current root key
  Uint8List _rootKey;

  /// Sending chain key (for encrypting)
  ChainKey?  _sendingChainKey;

  /// Receiving chain key (for decrypting)
  ChainKey? _receivingChainKey;

  /// My current ratchet key pair
  RatchetKeyPair? _myRatchetKeyPair;

  /// Their current ratchet public key
  Uint8List? _theirRatchetPublicKey;

  /// Number of messages sent in current sending chain
  int _sendingChainLength = 0;

  /// Number of messages received in current receiving chain
  int _receivingChainLength = 0;

  /// Previous sending chain length (for message header)
  int _previousSendingChainLength = 0;

  /// Skipped message keys for out-of-order delivery
  final SkippedMessageKeys _skippedKeys;

  /// Session ID for logging
  final String sessionId;

  DoubleRatchet._({
    required Uint8List rootKey,
    ChainKey? sendingChainKey,
    ChainKey?  receivingChainKey,
    RatchetKeyPair?  myRatchetKeyPair,
    Uint8List?  theirRatchetPublicKey,
    int sendingChainLength = 0,
    int receivingChainLength = 0,
    int previousSendingChainLength = 0,
    SkippedMessageKeys?  skippedKeys,
    required this.sessionId,
  })  : _rootKey = rootKey,
        _sendingChainKey = sendingChainKey,
        _receivingChainKey = receivingChainKey,
        _myRatchetKeyPair = myRatchetKeyPair,
        _theirRatchetPublicKey = theirRatchetPublicKey,
        _sendingChainLength = sendingChainLength,
        _receivingChainLength = receivingChainLength,
        _previousSendingChainLength = previousSendingChainLength,
        _skippedKeys = skippedKeys ?? SkippedMessageKeys();

  /// My current ratchet public key
  Uint8List?  get myRatchetPublicKey => _myRatchetKeyPair?.publicKey;

  /// Their current ratchet public key
  Uint8List? get theirRatchetPublicKey => _theirRatchetPublicKey;

  /// Current sending chain length
  int get sendingChainLength => _sendingChainLength;

  /// Current receiving chain length
  int get receivingChainLength => _receivingChainLength;

  /// Number of skipped keys stored
  int get skippedKeyCount => _skippedKeys.count;

  // ─────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────

  /// Initialize as session initiator (Alice)
  static Future<DoubleRatchet> initializeAsInitiator({
    required SecureKey sharedSecret,
    required Uint8List theirRatchetPublicKey,
    required String sessionId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Generate our initial ratchet key pair
    final myRatchetKeyPair = await KeyGeneration. generateRatchetKeyPair();

    // Perform initial DH
    final dhOutput = sodium.crypto.scalarMult(
      n: myRatchetKeyPair.secretKey,
      p: theirRatchetPublicKey,
    );

    // Derive root key and sending chain key
    final rootKeyBytes = sharedSecret.extractBytes();
    final derived = await Hashing.kdfRootKey(
      rootKey: rootKeyBytes,
      dhOutput: dhOutput,
    );

    // Zero intermediate values
    _zeroize(dhOutput);
    _zeroize(rootKeyBytes);

    return DoubleRatchet. _(
      rootKey: derived.rootKey,
      sendingChainKey: ChainKey.fromBytes(derived.chainKey),
      myRatchetKeyPair: myRatchetKeyPair,
      theirRatchetPublicKey:  Uint8List.fromList(theirRatchetPublicKey),
      sessionId: sessionId,
    );
  }

  /// Initialize as session responder (Bob)
  static Future<DoubleRatchet> initializeAsResponder({
    required SecureKey sharedSecret,
    required RatchetKeyPair myRatchetKeyPair,
    required String sessionId,
  }) async {
    final rootKeyBytes = sharedSecret.extractBytes();

    return DoubleRatchet._(
      rootKey:  Uint8List.fromList(rootKeyBytes),
      myRatchetKeyPair: myRatchetKeyPair,
      sessionId: sessionId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Encryption
  // ─────────────────────────────────────────────────────────

  /// Encrypt a message
  Future<RatchetMessage> encrypt(Uint8List plaintext) async {
    // Ensure we have a sending chain
    if (_sendingChainKey == null) {
      throw RatchetException('No sending chain key available');
    }

    // Advance sending chain to get message key
    final advance = await _sendingChainKey! .advance();
    _sendingChainKey = advance.nextChainKey;

    // Encrypt message
    final encrypted = await MessageKeys. encrypt(
      plaintext: plaintext,
      messageKey: advance.messageKey,
    );

    // Zero message key
    advance. disposeMessageKey();

    // Create message
    final message = RatchetMessage(
      ciphertext: encrypted. ciphertext,
      nonce: encrypted.nonce,
      ratchetPublicKey: _myRatchetKeyPair!.publicKey,
      messageNumber: _sendingChainLength,
      previousChainLength: _previousSendingChainLength,
    );

    _sendingChainLength++;

    return message;
  }

  /// Encrypt with associated data (AEAD)
  Future<RatchetMessage> encryptWithAD(
    Uint8List plaintext,
    Uint8List associatedData,
  ) async {
    if (_sendingChainKey == null) {
      throw RatchetException('No sending chain key available');
    }

    final advance = await _sendingChainKey! .advance();
    _sendingChainKey = advance.nextChainKey;

    final encrypted = await MessageKeys.encrypt(
      plaintext: plaintext,
      messageKey: advance.messageKey,
      associatedData:  associatedData,
    );

    advance.disposeMessageKey();

    final message = RatchetMessage(
      ciphertext: encrypted.ciphertext,
      nonce: encrypted. nonce,
      ratchetPublicKey: _myRatchetKeyPair!.publicKey,
      messageNumber:  _sendingChainLength,
      previousChainLength: _previousSendingChainLength,
    );

    _sendingChainLength++;

    return message;
  }

  // ─────────────────────────────────────────────────────────
  // Decryption
  // ─────────────────────────────────────────────────────────

  /// Decrypt a message
  Future<Uint8List> decrypt(RatchetMessage message) async {
    // Try to use a skipped message key first
    final skippedKey = _skippedKeys.consumeKey(
      message.ratchetPublicKey,
      message.messageNumber,
    );

    if (skippedKey != null) {
      final plaintext = await MessageKeys.decrypt(
        ciphertext: message.ciphertext,
        nonce:  message.nonce,
        messageKey:  skippedKey,
      );
      _zeroize(skippedKey);
      return plaintext;
    }

    // Check if we need to perform DH ratchet step
    final needsDhRatchet = _theirRatchetPublicKey == null ||
        ! _bytesEqual(message.ratchetPublicKey, _theirRatchetPublicKey! );

    if (needsDhRatchet) {
      await _performDhRatchet(message.ratchetPublicKey);
    }

    // Skip any missed messages in current chain
    await _skipMessages(message. messageNumber);

    // Advance receiving chain to get message key
    if (_receivingChainKey == null) {
      throw RatchetException('No receiving chain key available');
    }

    final advance = await _receivingChainKey!.advance();
    _receivingChainKey = advance.nextChainKey;
    _receivingChainLength++;

    // Decrypt message
    final plaintext = await MessageKeys.decrypt(
      ciphertext: message.ciphertext,
      nonce: message. nonce,
      messageKey: advance. messageKey,
    );

    // Zero message key
    advance.disposeMessageKey();

    return plaintext;
  }

  /// Decrypt with associated data (AEAD)
  Future<Uint8List> decryptWithAD(
    RatchetMessage message,
    Uint8List associatedData,
  ) async {
    final skippedKey = _skippedKeys. consumeKey(
      message.ratchetPublicKey,
      message.messageNumber,
    );

    if (skippedKey != null) {
      final plaintext = await MessageKeys.decrypt(
        ciphertext:  message.ciphertext,
        nonce: message.nonce,
        messageKey: skippedKey,
        associatedData: associatedData,
      );
      _zeroize(skippedKey);
      return plaintext;
    }

    final needsDhRatchet = _theirRatchetPublicKey == null ||
        !_bytesEqual(message.ratchetPublicKey, _theirRatchetPublicKey!);

    if (needsDhRatchet) {
      await _performDhRatchet(message.ratchetPublicKey);
    }

    await _skipMessages(message.messageNumber);

    if (_receivingChainKey == null) {
      throw RatchetException('No receiving chain key available');
    }

    final advance = await _receivingChainKey! .advance();
    _receivingChainKey = advance.nextChainKey;
    _receivingChainLength++;

    final plaintext = await MessageKeys.decrypt(
      ciphertext: message.ciphertext,
      nonce: message.nonce,
      messageKey: advance.messageKey,
      associatedData: associatedData,
    );

    advance.disposeMessageKey();

    return plaintext;
  }

  // ─────────────────────────────────────────────────────────
  // DH Ratchet
  // ─────────────────────────────────────────────────────────

  /// Perform DH ratchet step
  Future<void> _performDhRatchet(Uint8List theirNewRatchetPublicKey) async {
    final sodium = await SodiumLoader.sodium;

    // Store previous sending chain length
    _previousSendingChainLength = _sendingChainLength;
    _sendingChainLength = 0;
    _receivingChainLength = 0;

    // Store their new ratchet key
    _theirRatchetPublicKey = Uint8List. fromList(theirNewRatchetPublicKey);

    // DH with our current private key and their new public key
    final dhOutput1 = sodium.crypto.scalarMult(
      n: _myRatchetKeyPair!.secretKey,
      p: theirNewRatchetPublicKey,
    );

    // Derive new receiving chain key
    final derived1 = await Hashing. kdfRootKey(
      rootKey: _rootKey,
      dhOutput:  dhOutput1,
    );
    _rootKey = derived1.rootKey;
    _receivingChainKey = ChainKey.fromBytes(derived1.chainKey);

    // Generate new ratchet key pair
    _myRatchetKeyPair?. dispose();
    _myRatchetKeyPair = await KeyGeneration.generateRatchetKeyPair();

    // DH with our new private key and their public key
    final dhOutput2 = sodium. crypto.scalarMult(
      n: _myRatchetKeyPair! .secretKey,
      p: theirNewRatchetPublicKey,
    );

    // Derive new sending chain key
    final derived2 = await Hashing.kdfRootKey(
      rootKey: _rootKey,
      dhOutput: dhOutput2,
    );
    _rootKey = derived2.rootKey;
    _sendingChainKey = ChainKey.fromBytes(derived2.chainKey);

    // Zero intermediate values
    _zeroize(dhOutput1);
    _zeroize(dhOutput2);
  }

  // ─────────────────────────────────────────────────────────
  // Skipped Messages
  // ─────────────────────────────────────────────────────────

  /// Skip messages and store their keys
  Future<void> _skipMessages(int untilIndex) async {
    if (_receivingChainKey == null) return;

    final toSkip = untilIndex - _receivingChainLength;

    if (toSkip < 0) {
      throw RatchetException('Message index already processed:  $untilIndex');
    }

    if (toSkip > SkippedMessageKeys.maxSkipPerChain) {
      throw RatchetException(
        'Too many skipped messages:  $toSkip (max: ${SkippedMessageKeys.maxSkipPerChain})',
      );
    }

    // Skip messages and store their keys
    while (_receivingChainLength < untilIndex) {
      final advance = await _receivingChainKey!. advance();

      _skippedKeys. storeKey(
        _theirRatchetPublicKey!,
        _receivingChainLength,
        advance.messageKey,
      );

      _receivingChainKey = advance.nextChainKey;
      _receivingChainLength++;
    }
  }

  // ─────────────────────────────────────────────────────────
  // State Management
  // ─────────────────────────────────────────────────────────

  /// Export session state for storage
  RatchetSessionState exportState() {
    return RatchetSessionState(
      sessionId: sessionId,
      rootKey:  Uint8List.fromList(_rootKey),
      sendingChainKey: _sendingChainKey?.toJson(),
      receivingChainKey: _receivingChainKey?.toJson(),
      myRatchetPublicKey: _myRatchetKeyPair?.publicKey,
      theirRatchetPublicKey: _theirRatchetPublicKey,
      sendingChainLength: _sendingChainLength,
      receivingChainLength: _receivingChainLength,
      previousSendingChainLength: _previousSendingChainLength,
      skippedKeys: _skippedKeys.toJson(),
    );
  }

  /// Import session state (requires private key separately)
  static Future<DoubleRatchet> importState({
    required RatchetSessionState state,
    required SecureKey myRatchetPrivateKey,
  }) async {
    final sodium = await SodiumLoader.sodium;

    RatchetKeyPair? myRatchetKeyPair;
    if (state.myRatchetPublicKey != null) {
      myRatchetKeyPair = RatchetKeyPair(
        publicKey:  state.myRatchetPublicKey! ,
        secretKey: myRatchetPrivateKey,
      );
    }

    return DoubleRatchet._(
      rootKey: state. rootKey,
      sendingChainKey: state.sendingChainKey != null
          ? ChainKey. fromJson(state.sendingChainKey!)
          : null,
      receivingChainKey: state.receivingChainKey != null
          ? ChainKey.fromJson(state.receivingChainKey!)
          : null,
      myRatchetKeyPair: myRatchetKeyPair,
      theirRatchetPublicKey: state. theirRatchetPublicKey,
      sendingChainLength: state.sendingChainLength,
      receivingChainLength: state. receivingChainLength,
      previousSendingChainLength: state.previousSendingChainLength,
      skippedKeys: SkippedMessageKeys.fromJson(state.skippedKeys),
      sessionId: state. sessionId,
    );
  }

  /// Clean up expired skipped keys
  void cleanupSkippedKeys() {
    _skippedKeys.removeExpired();
  }

  /// Dispose all sensitive material
  void dispose() {
    _zeroize(_rootKey);
    _sendingChainKey?. dispose();
    _receivingChainKey?.dispose();
    _myRatchetKeyPair?.dispose();
    _skippedKeys.clear();
  }

  // ─────────────────────────────────────────────────────────
  // Utility Functions
  // ─────────────────────────────────────────────────────────

  /// Constant-time byte comparison
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Zero a buffer
  static void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}

/// Encrypted message from Double Ratchet
class RatchetMessage {
  /// Encrypted message content
  final Uint8List ciphertext;

  /// Nonce used for encryption
  final Uint8List nonce;

  /// Sender's current ratchet public key
  final Uint8List ratchetPublicKey;

  /// Message number in current sending chain
  final int messageNumber;

  /// Length of previous sending chain
  final int previousChainLength;

  /// Timestamp when message was created
  final int timestamp;

  RatchetMessage({
    required this.ciphertext,
    required this. nonce,
    required this.ratchetPublicKey,
    required this. messageNumber,
    required this.previousChainLength,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Serialize for transmission
  Map<String, dynamic> toJson() => {
        'ciphertext':  ciphertext. toList(),
        'nonce': nonce. toList(),
        'ratchetPublicKey': ratchetPublicKey. toList(),
        'messageNumber': messageNumber,
        'previousChainLength':  previousChainLength,
        'timestamp': timestamp,
      };

  /// Deserialize from transmission
  factory RatchetMessage. fromJson(Map<String, dynamic> json) {
    return RatchetMessage(
      ciphertext: Uint8List.fromList((json['ciphertext'] as List).cast<int>()),
      nonce: Uint8List.fromList((json['nonce'] as List).cast<int>()),
      ratchetPublicKey: Uint8List.fromList(
        (json['ratchetPublicKey'] as List).cast<int>(),
      ),
      messageNumber: json['messageNumber'] as int,
      previousChainLength: json['previousChainLength'] as int,
      timestamp: json['timestamp'] as int?,
    );
  }

  /// Combined wire format
  Uint8List toBytes() {
    final buffer = <int>[];

    // Header:  ratchetPublicKey (32) + messageNumber (4) + previousChainLength (4)
    buffer.addAll(ratchetPublicKey);
    buffer.addAll(_intToBytes(messageNumber));
    buffer.addAll(_intToBytes(previousChainLength));

    // Nonce (24)
    buffer.addAll(nonce);

    // Ciphertext (variable)
    buffer.addAll(ciphertext);

    return Uint8List.fromList(buffer);
  }

  /// Parse from wire format
  factory RatchetMessage. fromBytes(Uint8List bytes) {
    if (bytes.length < 64) {
      throw ArgumentError('Message too short');
    }

    var offset = 0;

    final ratchetPublicKey = bytes.sublist(offset, offset + 32);
    offset += 32;

    final messageNumber = _bytesToInt(bytes. sublist(offset, offset + 4));
    offset += 4;

    final previousChainLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;

    final nonce = bytes.sublist(offset, offset + 24);
    offset += 24;

    final ciphertext = bytes. sublist(offset);

    return RatchetMessage(
      ciphertext: ciphertext,
      nonce: nonce,
      ratchetPublicKey:  ratchetPublicKey,
      messageNumber: messageNumber,
      previousChainLength: previousChainLength,
    );
  }

  static Uint8List _intToBytes(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  static int _bytesToInt(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}

/// Serializable ratchet session state
class RatchetSessionState {
  final String sessionId;
  final Uint8List rootKey;
  final Map<String, dynamic>? sendingChainKey;
  final Map<String, dynamic>? receivingChainKey;
  final Uint8List? myRatchetPublicKey;
  final Uint8List? theirRatchetPublicKey;
  final int sendingChainLength;
  final int receivingChainLength;
  final int previousSendingChainLength;
  final Map<String, dynamic> skippedKeys;

  const RatchetSessionState({
    required this.sessionId,
    required this.rootKey,
    this.sendingChainKey,
    this.receivingChainKey,
    this.myRatchetPublicKey,
    this.theirRatchetPublicKey,
    required this.sendingChainLength,
    required this.receivingChainLength,
    required this.previousSendingChainLength,
    required this.skippedKeys,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'rootKey': rootKey.toList(),
        'sendingChainKey': sendingChainKey,
        'receivingChainKey': receivingChainKey,
        'myRatchetPublicKey': myRatchetPublicKey?. toList(),
        'theirRatchetPublicKey':  theirRatchetPublicKey?.toList(),
        'sendingChainLength': sendingChainLength,
        'receivingChainLength': receivingChainLength,
        'previousSendingChainLength': previousSendingChainLength,
        'skippedKeys': skippedKeys,
      };

  factory RatchetSessionState.fromJson(Map<String, dynamic> json) {
    return RatchetSessionState(
      sessionId: json['sessionId'] as String,
      rootKey:  Uint8List. fromList((json['rootKey'] as List).cast<int>()),
      sendingChainKey: json['sendingChainKey'] as Map<String, dynamic>?,
      receivingChainKey:  json['receivingChainKey'] as Map<String, dynamic>?,
      myRatchetPublicKey: json['myRatchetPublicKey'] != null
          ?  Uint8List.fromList((json['myRatchetPublicKey'] as List).cast<int>())
          : null,
      theirRatchetPublicKey: json['theirRatchetPublicKey'] != null
          ? Uint8List.fromList(
              (json['theirRatchetPublicKey'] as List).cast<int>())
          : null,
      sendingChainLength: json['sendingChainLength'] as int,
      receivingChainLength: json['receivingChainLength'] as int,
      previousSendingChainLength: json['previousSendingChainLength'] as int,
      skippedKeys: json['skippedKeys'] as Map<String, dynamic>,
    );
  }
}

/// Ratchet-specific exception
class RatchetException implements Exception {
  final String message;

  RatchetException(this.message);

  @override
  String toString() => 'RatchetException:  $message';
}