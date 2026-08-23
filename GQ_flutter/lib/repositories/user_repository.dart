import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  Future<void> saveUser(UserProfile profile) async {
    await _fs.collection('users').doc(profile.uid).set(profile.toFirestore());
  }
}
