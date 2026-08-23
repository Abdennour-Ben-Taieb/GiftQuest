import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches the `users/{uid}` document. Fields are flat at the document
/// root (not nested under an "info_abt_user" subcollection).
class UserProfile {
  final String uid;
  final String name;
  final String nickname;
  final String email;
  final String? photoUrl;
  final String dateOfBirth;
  final String? linkedWith; // partner's uid, or null if unpaired
  final String? myShareCode;

  /// Set on my doc when I've entered/scanned someone else's code and am
  /// waiting for them to accept — the uid of the person I'm waiting on.
  final String? pendingPairRequestTo;

  /// Set on my doc when someone else has entered/scanned my code and is
  /// waiting for me to accept — the uid of the person requesting.
  final String? pendingPairRequestFrom;

  const UserProfile({
    required this.uid,
    this.name = '',
    this.nickname = '',
    this.email = '',
    this.photoUrl,
    this.dateOfBirth = '',
    this.linkedWith,
    this.myShareCode,
    this.pendingPairRequestTo,
    this.pendingPairRequestFrom,
  });

  bool get isLinked => linkedWith != null;

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      dateOfBirth: data['dateOfBirth'] as String? ?? '',
      linkedWith: data['linkedWith'] as String?,
      myShareCode: data['myShareCode'] as String?,
      pendingPairRequestTo: data['pendingPairRequestTo'] as String?,
      pendingPairRequestFrom: data['pendingPairRequestFrom'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'nickname': nickname,
      'email': email,
      'photoUrl': photoUrl,
      'dateOfBirth': dateOfBirth,
      'linkedWith': linkedWith,
      'myShareCode': myShareCode,
      'pendingPairRequestTo': pendingPairRequestTo,
      'pendingPairRequestFrom': pendingPairRequestFrom,
    };
  }

  UserProfile copyWith({
    String? name,
    String? nickname,
    String? email,
    String? photoUrl,
    String? dateOfBirth,
    String? linkedWith,
    String? myShareCode,
    String? pendingPairRequestTo,
    String? pendingPairRequestFrom,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      linkedWith: linkedWith ?? this.linkedWith,
      myShareCode: myShareCode ?? this.myShareCode,
      pendingPairRequestTo: pendingPairRequestTo ?? this.pendingPairRequestTo,
      pendingPairRequestFrom:
          pendingPairRequestFrom ?? this.pendingPairRequestFrom,
    );
  }
}
