import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

import '../bridge/sodium_loader.dart';
import 'hashing.dart';
import 'signatures.dart';

/// ============================================================
/// Extended Triple Diffie-Hellman (X3DH)
/// ============================================================
/// Implements Signal Protocol X3DH key agreement:  
///
/// Purpose: 
/// • Establish shared secret between two parties
/// • Works asynchronously (recipient can be offline)
/// • Provides forward secrecy and deniability
///
/// Key Agreement (Alice initiates to Bob):
/// DH1 = DH(IKa, SPKb)  - Alice's identity, Bob's signed prekey
/// DH2 = DH(EKa, IKb)   - Alice's ephemeral, Bob's identity
/// DH3 = DH(EKa, SPKb)  - Alice's ephemeral, Bob's signed prekey
/// DH4 = DH(EKa, OPKb)  - Alice's ephemeral, Bob's one-time prekey
///
/// SK = KDF(DH1 || DH2 || DH3 || DH4)
///
/// Output:  Shared secret used as initial root key for Double Ratchet
///
/// Standards: Signal Protocol Specification
/// ============================================================
final class X3DH {
  X3DH._();

  /// Protocol info string for domain separation
  static final Uint8List _info = Uint8List. fromList(
    'PravaX3DH_v1'. codeUnits,
  );

  /// X25519 key size
  static const int keySize = 32;

  // ─────────────────────────────────────────────────────────
  // Session Initiation (Alice/Sender)
  // ─────────────────────────────────────────────────────────

  /// Initiate X3DH session as sender
  ///
  /// Alice calls this to establish a session with Bob.  
  /// Returns shared secret and ephemeral public key to send to Bob.
  ///
  /// Note: This implementation assumes identity keys are already X25519.
  /// If using Ed25519 identity keys, convert them before calling this method.
  static Future<X3DHInitiatorResult> initiateSession({
    required Uint8List myIdentityPublicKeyX25519,
    required SecureKey myIdentityPrivateKeyX25519,
    required Uint8List theirIdentityPublicKeyX25519,
    required Uint8List theirSignedPreKeyPublic,
    required Uint8List theirSignedPreKeySignature,
    required Uint8List theirIdentityPublicKeyEd25519,
    Uint8List? theirOneTimePreKeyPublic,
    int? theirOneTimePreKeyId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Step 1: Verify signed pre-key signature
    final signatureValid = await Signatures.verifyPreKey(
      theirSignedPreKeyPublic,
      theirSignedPreKeySignature,
      theirIdentityPublicKeyEd25519,
    );

    if (!signatureValid) {
      throw X3DHException('Invalid signed pre-key signature');
    }

    // Step 2: Generate ephemeral key pair
    final ephemeralKeyPair = sodium.crypto. box. keyPair();

    // Step 3: Perform DH calculations

    // DH1:  My identity private * Their signed pre-key public
    final dh1 = _scalarMult(
      sodium,
      myIdentityPrivateKeyX25519,
      theirSignedPreKeyPublic,
    );

    // DH2: My ephemeral private * Their identity public
    final dh2 = _scalarMult(
      sodium,
      ephemeralKeyPair. secretKey,
      theirIdentityPublicKeyX25519,
    );

    // DH3: My ephemeral private * Their signed pre-key public
    final dh3 = _scalarMult(
      sodium,
      ephemeralKeyPair.secretKey,
      theirSignedPreKeyPublic,
    );

    // DH4: My ephemeral private * Their one-time pre-key public (optional)
    Uint8List? dh4;
    if (theirOneTimePreKeyPublic != null) {
      dh4 = _scalarMult(
        sodium,
        ephemeralKeyPair. secretKey,
        theirOneTimePreKeyPublic,
      );
    }

    // Step 4: Derive shared secret
    final sharedSecret = await _deriveSharedSecret(
      sodium:  sodium,
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    // Step 5: Clean up intermediate values
    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);

    return X3DHInitiatorResult(
      sharedSecret:  sharedSecret,
      ephemeralPublicKey: ephemeralKeyPair. publicKey,
      usedOneTimePreKeyId: theirOneTimePreKeyId,
    );
  }

  /// Simplified session initiation using X25519 keys directly
  ///
  /// Use this when all keys are already X25519 (recommended approach)
  static Future<X3DHInitiatorResult> initiateSessionSimple({
    required SecureKey myIdentityPrivateKey,
    required Uint8List theirIdentityPublicKey,
    required Uint8List theirSignedPreKeyPublic,
    Uint8List? theirOneTimePreKeyPublic,
    int?  theirOneTimePreKeyId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Generate ephemeral key pair
    final ephemeralKeyPair = sodium.crypto.box.keyPair();

    // DH1: My identity private * Their signed pre-key public
    final dh1 = _scalarMult(
      sodium,
      myIdentityPrivateKey,
      theirSignedPreKeyPublic,
    );

    // DH2: My ephemeral private * Their identity public
    final dh2 = _scalarMult(
      sodium,
      ephemeralKeyPair.secretKey,
      theirIdentityPublicKey,
    );

    // DH3: My ephemeral private * Their signed pre-key public
    final dh3 = _scalarMult(
      sodium,
      ephemeralKeyPair.secretKey,
      theirSignedPreKeyPublic,
    );

    // DH4: Optional
    Uint8List? dh4;
    if (theirOneTimePreKeyPublic != null) {
      dh4 = _scalarMult(
        sodium,
        ephemeralKeyPair.secretKey,
        theirOneTimePreKeyPublic,
      );
    }

    // Derive shared secret
    final sharedSecret = await _deriveSharedSecret(
      sodium: sodium,
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    // Clean up
    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);

    return X3DHInitiatorResult(
      sharedSecret: sharedSecret,
      ephemeralPublicKey: ephemeralKeyPair.publicKey,
      usedOneTimePreKeyId: theirOneTimePreKeyId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Session Completion (Bob/Receiver)
  // ─────────────────────────────────────────────────────────

  /// Complete X3DH session as receiver
  ///
  /// Bob calls this when receiving Alice's initial message.
  static Future<X3DHResponderResult> completeSession({
    required SecureKey myIdentityPrivateKeyX25519,
    required SecureKey mySignedPreKeyPrivate,
    SecureKey? myOneTimePreKeyPrivate,
    required Uint8List theirIdentityPublicKeyX25519,
    required Uint8List theirEphemeralPublicKey,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // DH1: My signed pre-key private * Their identity public
    final dh1 = _scalarMult(
      sodium,
      mySignedPreKeyPrivate,
      theirIdentityPublicKeyX25519,
    );

    // DH2: My identity private * Their ephemeral public
    final dh2 = _scalarMult(
      sodium,
      myIdentityPrivateKeyX25519,
      theirEphemeralPublicKey,
    );

    // DH3: My signed pre-key private * Their ephemeral public
    final dh3 = _scalarMult(
      sodium,
      mySignedPreKeyPrivate,
      theirEphemeralPublicKey,
    );

    // DH4: My one-time pre-key private * Their ephemeral public (optional)
    Uint8List? dh4;
    if (myOneTimePreKeyPrivate != null) {
      dh4 = _scalarMult(
        sodium,
        myOneTimePreKeyPrivate,
        theirEphemeralPublicKey,
      );
    }

    // Derive shared secret
    final sharedSecret = await _deriveSharedSecret(
      sodium: sodium,
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    // Clean up
    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);

    return X3DHResponderResult(
      sharedSecret: sharedSecret,
    );
  }

  /// Simplified session completion using X25519 keys directly
  static Future<X3DHResponderResult> completeSessionSimple({
    required SecureKey myIdentityPrivateKey,
    required SecureKey mySignedPreKeyPrivate,
    SecureKey? myOneTimePreKeyPrivate,
    required Uint8List theirIdentityPublicKey,
    required Uint8List theirEphemeralPublicKey,
  }) async {
    return completeSession(
      myIdentityPrivateKeyX25519: myIdentityPrivateKey,
      mySignedPreKeyPrivate: mySignedPreKeyPrivate,
      myOneTimePreKeyPrivate: myOneTimePreKeyPrivate,
      theirIdentityPublicKeyX25519: theirIdentityPublicKey,
      theirEphemeralPublicKey:  theirEphemeralPublicKey,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper Functions
  // ─────────────────────────────────────────────────────────

  /// Perform X25519 scalar multiplication using crypto_box beforenm
  /// This computes the shared secret between a private and public key
  static Uint8List _scalarMult(
    Sodium sodium,
    SecureKey privateKey,
    Uint8List publicKey,
  ) {
    // Use crypto_box_beforenm which performs X25519 DH
    // It computes:  shared = X25519(privateKey, publicKey)
    // The result is then hashed with HSalsa20, but for our purposes
    // we can use this as our DH output
    
    // Alternative: Use crypto_kx if available, or implement raw scalarmult
    
    // crypto_box. easy uses X25519 internally, we can extract the shared key
    // by using the precalculate method
    final sharedKey = sodium.crypto. box. precalculate(
      publicKey:  publicKey,
      secretKey: privateKey,
    );
    
    // Extract the bytes from the precalculated key
    final sharedBytes = sharedKey.extractBytes();
    sharedKey.dispose();
    
    return sharedBytes;
  }

  /// Derive shared secret from DH outputs
  static Future<SecureKey> _deriveSharedSecret({
    required Sodium sodium,
    required Uint8List dh1,
    required Uint8List dh2,
    required Uint8List dh3,
    Uint8List? dh4,
  }) async {
    // Concatenate DH outputs
    final combined = Uint8List.fromList([
      ... dh1,
      ...dh2,
      ... dh3,
      if (dh4 != null) ...dh4,
    ]);

    // Derive 32-byte shared secret using KDF
    final derivedBytes = await Hashing.deriveKey(
      inputKeyMaterial: combined,
      info: _info,
      outputLength: 32,
    );

    // Zero combined buffer
    _zeroize(combined);

    return sodium.secureCopy(derivedBytes);
  }

  /// Zero-fill a buffer
  static void _zeroize(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}

/// Result of X3DH session initiation (sender side)
class X3DHInitiatorResult {
  /// Shared secret (use as initial root key for Double Ratchet)
  final SecureKey sharedSecret;

  /// Ephemeral public key to send to recipient
  final Uint8List ephemeralPublicKey;

  /// ID of one-time pre-key used (if any)
  final int? usedOneTimePreKeyId;

  const X3DHInitiatorResult({
    required this.sharedSecret,
    required this.ephemeralPublicKey,
    this.usedOneTimePreKeyId,
  });

  /// Dispose shared secret
  void dispose() {
    sharedSecret.dispose();
  }
}

/// Result of X3DH session completion (receiver side)
class X3DHResponderResult {
  /// Shared secret (use as initial root key for Double Ratchet)
  final SecureKey sharedSecret;

  const X3DHResponderResult({
    required this.sharedSecret,
  });

  /// Dispose shared secret
  void dispose() {
    sharedSecret.dispose();
  }
}

/// X3DH-specific exception
class X3DHException implements Exception {
  final String message;

  X3DHException(this.message);

  @override
  String toString() => 'X3DHException:  $message';
}