// Identity, PreKey, Ephemeral keys
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader. dart';
import 'random_generator.dart';

/// ============================================================
/// Cryptographic Key Generation
/// ============================================================
/// Implements Signal Protocol key hierarchy:
///
/// Identity Keys (Ed25519):
/// • Long-term device identity
/// • Used for signing pre-keys
/// • Never changes (unless account reset)
///
/// Signed PreKeys (X25519):
/// • Medium-term keys (rotated weekly)
/// • Signed by identity key
/// • Fallback when OTPs exhausted
///
/// One-Time PreKeys (X25519):
/// • Single-use keys
/// • Consumed on first message
/// • Provides forward secrecy
///
/// Ephemeral Keys (X25519):
/// • Per-session keys
/// • Generated during X3DH handshake
///
/// Security:  256-bit security level
/// ============================================================
final class KeyGeneration {
  KeyGeneration._();

  /// Ed25519 key sizes
  static const int ed25519PublicKeySize = 32;
  static const int ed25519SecretKeySize = 64;
  static const int ed25519SeedSize = 32;

  /// X25519 key sizes
  static const int x25519PublicKeySize = 32;
  static const int x25519SecretKeySize = 32;

  // ─────────────────────────────────────────────────────────
  // Identity Keys (Ed25519)
  // ─────────────────────────────────────────────────────────

  /// Generate new Ed25519 identity key pair
  static Future<IdentityKeyPair> generateIdentityKeyPair() async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto.sign. keyPair();

    return IdentityKeyPair(
      publicKey: keyPair.publicKey,
      secretKey: keyPair.secretKey,
    );
  }

  /// Generate identity key pair from seed (deterministic, for recovery)
  static Future<IdentityKeyPair> identityKeyPairFromSeed(Uint8List seed) async {
    if (seed.length != ed25519SeedSize) {
      throw ArgumentError('Seed must be $ed25519SeedSize bytes');
    }

    final sodium = await SodiumLoader.sodium;
    final secureKey = sodium.secureCopy(seed);
    final keyPair = sodium.crypto. sign.seedKeyPair(secureKey);

    return IdentityKeyPair(
      publicKey: keyPair.publicKey,
      secretKey:  keyPair.secretKey,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Signed PreKeys (X25519)
  // ─────────────────────────────────────────────────────────

  /// Generate signed pre-key pair
  static Future<SignedPreKey> generateSignedPreKey({
    required int keyId,
    required SecureKey identityPrivateKey,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Generate X25519 key pair
    final keyPair = sodium. crypto.box.keyPair();

    // Sign the public key with identity key
    final signature = sodium.crypto. sign.detached(
      message: keyPair.publicKey,
      secretKey: identityPrivateKey,
    );

    return SignedPreKey(
      keyId: keyId,
      publicKey:  keyPair.publicKey,
      secretKey: keyPair.secretKey,
      signature:  signature,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ─────────────────────────────────────────────────────────
  // One-Time PreKeys (X25519)
  // ─────────────────────────────────────────────────────────

  /// Generate one-time pre-key pair
  static Future<OneTimePreKey> generateOneTimePreKey({
    required int keyId,
  }) async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto. box.keyPair();

    return OneTimePreKey(
      keyId:  keyId,
      publicKey: keyPair.publicKey,
      secretKey:  keyPair.secretKey,
      createdAt: DateTime. now().millisecondsSinceEpoch,
    );
  }

  /// Generate batch of one-time pre-keys
  static Future<List<OneTimePreKey>> generateOneTimePreKeyBatch({
    required int startId,
    int count = 100,
  }) async {
    if (count < 1 || count > 1000) {
      throw ArgumentError('Count must be 1-1000: $count');
    }

    final keys = <OneTimePreKey>[];
    for (var i = 0; i < count; i++) {
      keys.add(await generateOneTimePreKey(keyId: startId + i));
    }
    return keys;
  }

  // ─────────────────────────────────────────────────────────
  // Ephemeral Keys (X25519)
  // ─────────────────────────────────────────────────────────

  /// Generate ephemeral key pair for X3DH
  static Future<EphemeralKeyPair> generateEphemeralKeyPair() async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto.box.keyPair();

    return EphemeralKeyPair(
      publicKey: keyPair.publicKey,
      secretKey:  keyPair.secretKey,
    );
  }

  /// Generate ratchet key pair for Double Ratchet
  static Future<RatchetKeyPair> generateRatchetKeyPair() async {
    final sodium = await SodiumLoader.sodium;
    final keyPair = sodium.crypto.box.keyPair();

    return RatchetKeyPair(
      publicKey:  keyPair.publicKey,
      secretKey: keyPair.secretKey,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Key Conversion
  // ─────────────────────────────────────────────────────────

  /// Convert Ed25519 public key to X25519
  static Future<Uint8List> ed25519PkToX25519(Uint8List ed25519PublicKey) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.crypto.sign.ed25519PkToCurve25519(ed25519PublicKey);
  }

  /// Convert Ed25519 secret key to X25519
  static Future<SecureKey> ed25519SkToX25519(SecureKey ed25519SecretKey) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.crypto. sign.ed25519SkToCurve25519(ed25519SecretKey);
  }

  // ─────────────────────────────────────────────────────────
  // Symmetric Keys
  // ─────────────────────────────────────────────────────────

  /// Generate symmetric key for local encryption
  static Future<SecureKey> generateSymmetricKey({int length = 32}) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.secureRandom(length);
  }

  /// Generate message key from bytes
  static Future<SecureKey> messageKeyFromBytes(Uint8List bytes) async {
    final sodium = await SodiumLoader.sodium;
    return sodium.secureCopy(bytes);
  }

  // ─────────────────────────────────────────────────────────
  // Key IDs
  // ─────────────────────────────────────────────────────────

  /// Generate random key ID
  static Future<int> generateKeyId() async {
    return RandomGenerator.keyId();
  }

  /// Generate registration ID (Signal protocol compatible)
  static Future<int> generateRegistrationId() async {
    return RandomGenerator.registrationId();
  }
}

/// Identity key pair (Ed25519)
class IdentityKeyPair {
  final Uint8List publicKey;
  final SecureKey secretKey;

  const IdentityKeyPair({
    required this.publicKey,
    required this. secretKey,
  });

  