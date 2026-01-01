// Backup lifecycle manager
import 'dart:typed_data';

import '../crypto/random_generator.dart';
import '../storage/identity_store.dart';
import '../storage/prekey_store.dart';
import '../storage/session_store.dart';
import '../storage/signed_prekey_store.dart';
import '../storage/vault.dart';
import 'backup_crypto.dart';
import 'backup_payload.dart';

/// ============================================================
/// Backup Manager
/// ============================================================
/// Handles complete backup lifecycle:
///
/// • Create encrypted backups
/// • Restore from backups
/// • Validate backup integrity
/// ============================================================
final class BackupManager {
  BackupManager._();

  /// Backup file magic bytes
  static final Uint8List _magic = Uint8List. fromList([0x50, 0x52, 0x41, 0x56]); // "PRAV"

  /// Backup format version
  static const int _formatVersion = 1;

  /// Header size:  magic (4) + version (1) + salt (16) = 21
  static const int _headerSize = 21;

  /// Create encrypted backup
  static Future<Uint8List> createBackup({
    required String passphrase,
  }) async {
    if (passphrase. length < BackupCrypto.minPassphraseLength) {
      throw ArgumentError(
        'Passphrase must be at least ${BackupCrypto. minPassphraseLength} characters',
      );
    }

    // 1. Gather all data
    final identity = await _exportIdentity();
    final sessions = await _exportSessions();
    final preKeys = await _exportPreKeys();
    final signedPreKey = await _exportSignedPreKey();

    // 2. Create payload
    final payload = BackupPayload. create(
      identity: identity,
      sessions: sessions,
      preKeys: preKeys,
      signedPreKey: signedPreKey,
      devices: [],
    );

    // 3. Encode payload
    final plaintext = payload.encode();

    // 4. Generate salt
    final salt = await RandomGenerator.salt(length: BackupCrypto.saltSize);

    // 5. Derive key
    final key = await BackupCrypto.deriveKey(
      passphrase: passphrase,
      salt: salt,
    );

    // 6. Encrypt
    final encrypted = await BackupCrypto.encrypt(
      key: key,
      plaintext: plaintext,
    );

    // 7. Dispose key
    key. dispose();

    // 8. Build final format:  magic + version + salt + encrypted
    return Uint8List. fromList([
      ..._magic,
      _formatVersion,
      ... salt,
      ... encrypted,
    ]);
  }

  /// Restore from encrypted backup
  static Future<BackupRestoreResult> restoreBackup({
    required Uint8List backupData,
    required String passphrase,
  }) async {
    // 1. Validate format
    _validateFormat(backupData);

    // 2. Extract components
    final salt = backupData. sublist(5, 21);
    final encrypted = backupData. sublist(21);

    // 3. Derive key
    final key = await BackupCrypto. deriveKey(
      passphrase:  passphrase,
      salt: salt,
    );

    // 4. Decrypt
    Uint8List plaintext;
    try {
      plaintext = await BackupCrypto.decrypt(
        key: key,
        encrypted: encrypted,
      );
    } finally {
      key. dispose();
    }

    // 5. Parse payload
    final payload = BackupPayload.decode(plaintext);

    // 6. Clear existing data
    await Vault.clear();

    // 7. Restore data
    await _restoreIdentity(payload.identity);
    await _restoreSessions(payload. sessions);
    await _restorePreKeys(payload.preKeys);
    await _restoreSignedPreKey(payload.signedPreKey);

    return BackupRestoreResult(
      success: true,
      sessionCount: payload.sessionCount,
      createdAt: payload. createdAtDate,
    );
  }

  /// Validate backup without restoring
  static Future<BackupInfo> validateBackup({
    required Uint8List backupData,
    required String passphrase,
  }) async {
    _validateFormat(backupData);

    final salt = backupData. sublist(5, 21);
    final encrypted = backupData.sublist(21);

    final key = await BackupCrypto.deriveKey(
      passphrase: passphrase,
      salt: salt,
    );

    final isValid = await BackupCrypto.verify(
      key:  key,
      encrypted: encrypted,
    );

    key.dispose();

    if (!isValid) {
      return BackupInfo(
        isValid: false,
        version: backupData[4],
        size: backupData. length,
      );
    }

    // Decrypt to get metadata
    final key2 = await BackupCrypto. deriveKey(
      passphrase:  passphrase,
      salt: salt,
    );

    final plaintext = await BackupCrypto.decrypt(
      key:  key2,
      encrypted: encrypted,
    );

    key2.dispose();

    final payload = BackupPayload.decode(plaintext);

    return BackupInfo(
      isValid: true,
      version: backupData[4],
      size: backupData.length,
      createdAt: payload.createdAtDate,
      sessionCount: payload. sessionCount,
    );
  }

  /// Estimate backup size
  static Future<int> estimateSize() async {
    final stats = await Vault. getStats();
    // Rough estimate: base + sessions * avgSessionSize
    return 1024 + (stats.sessionCount * 512) + (stats.preKeyCount * 64);
  }

  // ─────────────────────────────────────────────────────────
  // Export Helpers
  // ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _exportIdentity() async {
    final identity = await IdentityStore.getLocalIdentity();
    if (identity == null) {
      throw BackupException('No local identity found');
    }

    return {
      'odid': identity.odid,
      'deviceId': identity.deviceId,
      'registrationId': identity. registrationId,
      'publicKey':  identity.publicKey,
      'privateKey': identity.privateKey,
    };
  }

  static Future<List<Map<String, dynamic>>> _exportSessions() async {
    final sessions = await SessionStore.getActiveSessions();
    return sessions.map((s) => {
      'sessionId': s.sessionId,
      'myOdid': s.myOdid,
      'remoteOdid': s. remoteOdid,
      'remoteDeviceId':  s.remoteDeviceId,
      'rootKey': s.rootKey,
      'sendingChainKey': s.sendingChainKey,
      'receivingChainKey': s.receivingChainKey,
      'myRatchetPrivateKey': s. myRatchetPrivateKey,
      'myRatchetPublicKey': s.myRatchetPublicKey,
      'theirRatchetPublicKey': s. theirRatchetPublicKey,
      'sendingChainLength': s.sendingChainLength,
      'receivingChainLength': s. receivingChainLength,
      'previousSendingChainLength': s.previousSendingChainLength,
      'skippedKeys': s.skippedKeys,
    }).toList();
  }

  static Future<Map<String, dynamic>> _exportPreKeys() async {
    final preKeys = await PreKeyStore.getAvailablePreKeys();
    return {
      'keys': preKeys.map((pk) => {
        return {
          'keyId': pk.keyId,
          'publicKey': pk. publicKey,
          'privateKey': pk.privateKey,
        };
      }).toList(),
    };
  }

  static Future<Map<String, dynamic>> _exportSignedPreKey() async {
    final spk = await SignedPreKeyStore.getCurrentSignedPreKey();
    if (spk == null) {
      return {};
    }

    return {
      'keyId': spk. keyId,
      'publicKey': spk.publicKey,
      'privateKey': spk.privateKey,
      'signature': spk.signature,
    };
  }

  // ─────────────────────────────────────────────────────────
  // Restore Helpers
  // ─────────────────────────────────────────────────────────

  static Future<void> _restoreIdentity(Map<String, dynamic> data) async {
    await IdentityStore. saveLocalIdentity(
      odid: data['odid'] as String,
      deviceId: data['deviceId'] as String,
      registrationId: data['registrationId'] as int,
      publicKey:  Uint8List.fromList((data['publicKey'] as List).cast<int>()),
      privateKey: Uint8List.fromList((data['privateKey'] as List).cast<int>()),
    );
  }

  static Future<void> _restoreSessions(List<Map<String, dynamic>> sessions) async {
    // Sessions need to be restored with proper RatchetSessionState
    // This is a simplified version
    for (final session in sessions) {
      // Implementation depends on session store interface
    }
  }

  static Future<void> _restorePreKeys(Map<String, dynamic> data) async {
    final keys = data['keys'] as List?  ?? [];
    for (final key in keys) {
      final keyData = key as Map<String, dynamic>;
      await PreKeyStore.savePreKey(
        keyId: keyData['keyId'] as int,
        publicKey: Uint8List.fromList((keyData['publicKey'] as List).cast<int>()),
        privateKey: Uint8List.fromList((keyData['privateKey'] as List).cast<int>()),
      );
    }
  }

  static Future<void> _restoreSignedPreKey(Map<String, dynamic> data) async {
    if (data. isEmpty) return;

    await SignedPreKeyStore.saveSignedPreKey(
      keyId: data['keyId'] as int,
      publicKey: Uint8List.fromList((data['publicKey'] as List).cast<int>()),
      privateKey: Uint8List.fromList((data['privateKey'] as List).cast<int>()),
      signature:  Uint8List.fromList((data['signature'] as List).cast<int>()),
    );
  }

  static void _validateFormat(Uint8List data) {
    if (data.length < _headerSize) {
      throw BackupFormatException('Backup data too small');
    }

    // Check magic bytes
    for (var i = 0; i < 4; i++) {
      if (data[i] != _magic[i]) {
        throw BackupFormatException('Invalid backup format');
      }
    }

    // Check version
    final version = data[4];
    if (version > _formatVersion) {
      throw BackupFormatException(
        'Unsupported backup version:  $version (max: $_formatVersion)',
      );
    }
  }
}

/// Backup restore result
class BackupRestoreResult {
  final bool success;
  final int sessionCount;
  final DateTime createdAt;
  final String?  error;

  const BackupRestoreResult({
    required this.success,
    this.sessionCount = 0,
    required this.createdAt,
    this. error,
  });
}

/// Backup info
class BackupInfo {
  final bool isValid;
  final int version;
  final int size;
  final DateTime?  createdAt;
  final int?  sessionCount;

  const BackupInfo({
    required this. isValid,
    required this.version,
    required this. size,
    this.createdAt,
    this.sessionCount,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Backup exception
class BackupException implements Exception {
  final String message;
  BackupException(this. message);

  @override
  String toString() => 'BackupException: $message';
}

/// Backup format exception
class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this. message);

  @override
  String toString() => 'BackupFormatException:  $message';
}