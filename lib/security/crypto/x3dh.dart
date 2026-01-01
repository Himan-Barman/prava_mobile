// X3DH key agreement
import 'dart: typed_data';

import 'package: sodium_libs/sodium_libs.dart';

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
/// Output: Shared secret used as initial root key for Double Ratchet
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
  static Future<X3DHInitiatorResult> initiateSession({
    required Uint8List myIdentityPublicKey,
    required SecureKey myIdentityPrivateKey,
    required Uint8List theirIdentityPublicKey,
    required Uint8List theirSignedPreKeyPublic,
    required Uint8List theirSignedPreKeySignature,
    Uint8List?  theirOneTimePreKeyPublic,
    int? theirOneTimePreKeyId,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // ─────────────────────────────────────────────────────
    // Step 1: Verify signed pre-key signature
    // ─────────────────────────────────────────────────────
    final signatureValid = await Signatures. verifyPreKey(
      theirSignedPreKeyPublic,
      theirSignedPreKeySignature,
      theirIdentityPublicKey,
    );

    if (!signatureValid) {
      throw X3DHException('Invalid signed pre-key signature');
    }

    // ─────────────────────────────────────────────────────
    // Step 2: Generate ephemeral key pair
    // ─────────────────────────────────────────────────────
    final ephemeralKeyPair = sodium.crypto.box. keyPair();

    // ─────────────────────────────────────────────────────
    // Step 3: Convert Ed25519 identity keys to X25519
    // ─────────────────────────────────────────────────────
    final myIdentityX25519Sk = sodium.crypto.sign. ed25519SkToCurve25519(
      myIdentityPrivateKey,
    );
    final theirIdentityX25519Pk = sodium.crypto. sign.ed25519PkToCurve25519(
      theirIdentityPublicKey,
    );

    // ─────────────────────────────────────────────────────
    // Step 4: Perform DH calculations
    // ─────────────────────────────────────────────────────

    // DH1:  My identity private * Their signed pre-key public
    final dh1 = sodium. crypto.scalarMult(
      n: myIdentityX25519Sk,
      p: theirSignedPreKeyPublic,
    );

    // DH2: My ephemeral private * Their identity public
    final dh2 = sodium.crypto.scalarMult(
      n: ephemeralKeyPair. secretKey,
      p: theirIdentityX25519Pk,
    );

    // DH3: My ephemeral private * Their signed pre-key public
    final dh3 = sodium.crypto.scalarMult(
      n:  ephemeralKeyPair.secretKey,
      p: theirSignedPreKeyPublic,
    );

    // DH4: My ephemeral private * Their one-time pre-key public (optional)
    Uint8List? dh4;
    if (theirOneTimePreKeyPublic != null) {
      dh4 = sodium.crypto.scalarMult(
        n: ephemeralKeyPair.secretKey,
        p: theirOneTimePreKeyPublic,
      );
    }

    // ─────────────────────────────────────────────────────
    // Step 5: Derive shared secret
    // ─────────────────────────────────────────────────────
    final sharedSecret = await _deriveSharedSecret(
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    // ─────────────────────────────────────────────────────
    // Step 6: Clean up intermediate values
    // ─────────────────────────────────────────────────────
    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);
    myIdentityX25519Sk. dispose();

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
    required Uint8List myIdentityPublicKey,
    required SecureKey myIdentityPrivateKey,
    required Uint8List mySignedPreKeyPublic,
    required SecureKey mySignedPreKeyPrivate,
    SecureKey? myOneTimePreKeyPrivate,
    required Uint8List theirIdentityPublicKey,
    required Uint8List theirEphemeralPublicKey,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // ─────────────────────────────────────────────────────
    // Step 1: Convert Ed25519 identity keys to X25519
    // ─────────────────────────────────────────────────────
    final myIdentityX25519Sk = sodium.crypto.sign.ed25519SkToCurve25519(
      myIdentityPrivateKey,
    );
    final theirIdentityX25519Pk = sodium. crypto.sign.ed25519PkToCurve25519(
      theirIdentityPublicKey,
    );

    // ─────────────────────────────────────────────────────
    // Step 2: Perform DH calculations (reverse of initiator)
    // ─────────────────────────────────────────────────────

    // DH1: My signed pre-key private * Their identity public
    final dh1 = sodium.crypto. scalarMult(
      n: mySignedPreKeyPrivate,
      p: theirIdentityX25519Pk,
    );

    // DH2: My identity private * Their ephemeral public
    final dh2 = sodium.crypto. scalarMult(
      n: myIdentityX25519Sk,
      p: theirEphemeralPublicKey,
    );

    // DH3: My signed pre-key private * Their ephemeral public
    final dh3 = sodium.crypto. scalarMult(
      n: mySignedPreKeyPrivate,
      p: theirEphemeralPublicKey,
    );

    // DH4: My one-time pre-key private * Their ephemeral public (optional)
    Uint8List?  dh4;
    if (myOneTimePreKeyPrivate != null) {
      dh4 = sodium.crypto. scalarMult(
        n: myOneTimePreKeyPrivate,
        p: theirEphemeralPublicKey,
      );
    }

    // ─────────────────────────────────────────────────────
    // Step 3: Derive shared secret
    // ─────────────────────────────────────────────────────
    final sharedSecret = await _deriveSharedSecret(
      dh1: dh1,
      dh2: dh2,
      dh3: dh3,
      dh4: dh4,
    );

    // ─────────────────────────────────────────────────────
    // Step 4: Clean up intermediate values
    // ─────────────────────────────────────────────────────
    _zeroize(dh1);
    _zeroize(dh2);
    _zeroize(dh3);
    if (dh4 != null) _zeroize(dh4);
    myIdentityX25519Sk.dispose();

    return X3DHResponderResult(
      sharedSecret:  sharedSecret,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper Functions
  // ─────────────────────────────────────────────────────────

  /// Derive shared secret from DH outputs
  static Future<SecureKey> _deriveSharedSecret({
    required Uint8List dh1,
    required Uint8List dh2,
    required Uint8List dh3,
    Uint8List? dh4,
  }) async {
    final sodium = await SodiumLoader.sodium;

    // Concatenate DH outputs
    final combined = Uint8List. fromList([
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
    required this. ephemeralPublicKey,
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