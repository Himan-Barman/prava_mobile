// Identity entity (Isar)
import 'package: isar/isar.dart';

part 'identity_entity.g.dart';

/// Trust levels for identity keys
enum TrustLevel {
  /// Not yet trusted (new contact)
  untrusted,

  /// Trusted (accepted by user)
  trusted,

  /// Verified (safety number verified)
  verified,

  /// Blocked (explicitly distrusted)
  blocked,
}

/// ============================================================
/// Identity Entity - Database Model
/// ============================================================
/// Stores identity keys for local and remote users. 
/// ============================================================
@Collection()
class IdentityEntity {
  Id id = Isar.autoIncrement;

  /// User identifier
  @Index()
  late String odid;

  /// Device identifier
  @Index()
  late String deviceId;

  /// Registration ID (Signal protocol)
  late int registrationId;

  /// Ed25519 public key (32 bytes)
  late List<int> publicKey;

  /// Ed25519 private key (64 bytes) - only for local identity
  List<int>? privateKey;

  /// Whether this is our local identity
  @Index()
  late bool isLocal;

  /// Trust level
  @Enumerated(EnumType.ordinal)
  TrustLevel trustLevel = TrustLevel.untrusted;

  /// Creation timestamp
  late int createdAt;

  /// When key was last changed
  int?  keyChangedAt;

  /// When identity was verified
  int? verifiedAt;

  /// Composite index for lookups
  @Index(composite: [CompositeIndex('deviceId')])
  String get odidDevice => '$odid:$deviceId';
}