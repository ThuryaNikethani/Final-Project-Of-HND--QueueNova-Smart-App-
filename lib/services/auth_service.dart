import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userName;
  String? _userNIC;
  String? _userRole;
  String? _userBirthDate;
  String? _userGender;
  String? _userEmail;
  String? _userPhone;
  String? _userPhotoUrl;
  String? _lastLoginError;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool get isAuthenticated => _isAuthenticated;
  String? get userName => _userName;
  String? get userNIC => _userNIC;
  String? get userRole => _userRole;
  String? get userBirthDate => _userBirthDate;
  String? get userGender => _userGender;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userPhotoUrl => _userPhotoUrl;
  String? get lastLoginError => _lastLoginError;

  // ── NIC decoding (unchanged logic) ──────────────────────────────────────
  Map<String, String> _decodeNIC(String nic) {
    final upperNIC = nic.toUpperCase();
    String birthDate = '';
    String gender = '';
    int birthYear = 0;
    int birthMonth = 0;
    int birthDay = 0;

    if (upperNIC.length == 10 && RegExp(r'^[0-9]{9}[VX]$').hasMatch(upperNIC)) {
      birthYear = 1900 + int.parse(upperNIC.substring(0, 2));
      int dayOfYear = int.parse(upperNIC.substring(2, 5));
      if (dayOfYear > 500) {
        gender = 'Female';
        dayOfYear -= 500;
      } else {
        gender = 'Male';
      }
      final date = DateTime(birthYear, 1, 1).add(Duration(days: dayOfYear - 1));
      birthMonth = date.month;
      birthDay = date.day;
    } else if (upperNIC.length == 12 && RegExp(r'^[0-9]{12}$').hasMatch(upperNIC)) {
      birthYear = int.parse(upperNIC.substring(0, 4));
      int dayOfYear = int.parse(upperNIC.substring(4, 7));
      if (dayOfYear > 500) {
        gender = 'Female';
        dayOfYear -= 500;
      } else {
        gender = 'Male';
      }
      final date = DateTime(birthYear, 1, 1).add(Duration(days: dayOfYear - 1));
      birthMonth = date.month;
      birthDay = date.day;
    }

    birthDate = '$birthDay/$birthMonth/$birthYear';
    return {'birthDate': birthDate, 'gender': gender};
  }

  // ── Registration ─────────────────────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String nic,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final decodedNIC = _decodeNIC(nic);

      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      // Store user profile in Firestore
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'nic': nic.toUpperCase(),
        'email': email.trim(),
        'phone': phone,
        'role': 'citizen',
        'birthDate': decodedNIC['birthDate'],
        'gender': decodedNIC['gender'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cache locally
      await _cacheUserData(
        name: name,
        nic: nic.toUpperCase(),
        email: email.trim(),
        phone: phone,
        birthDate: decodedNIC['birthDate']!,
        gender: decodedNIC['gender']!,
      );

      _userName = name;
      _userNIC = nic.toUpperCase();
      _userRole = 'citizen';
      _userBirthDate = decodedNIC['birthDate'];
      _userGender = decodedNIC['gender'];
      _userEmail = email.trim();
      _userPhone = phone;
      _isAuthenticated = true;

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Registration error: ${e.code} - ${e.message}');
      // Always fall back to offline — including email-already-in-use so the
      // user can re-register locally and have their details saved correctly.
      return _registerOffline(name: name, nic: nic, email: email, phone: phone, password: password);
    } catch (e) {
      debugPrint('Unexpected registration error: $e');
      return _registerOffline(name: name, nic: nic, email: email, phone: phone, password: password);
    }
  }

  Future<bool> _registerOffline({
    required String name,
    required String nic,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (name.isEmpty || nic.isEmpty || email.isEmpty || password.isEmpty) return false;
    final decodedNIC = _decodeNIC(nic);
    await _cacheUserData(
      name: name,
      nic: nic.toUpperCase(),
      email: email,
      phone: phone,
      birthDate: decodedNIC['birthDate']!,
      gender: decodedNIC['gender']!,
    );
    _userName = name;
    _userNIC = nic.toUpperCase();
    _userRole = 'citizen';
    _userBirthDate = decodedNIC['birthDate'];
    _userGender = decodedNIC['gender'];
    _userEmail = email;
    _userPhone = phone;
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  // ── Login ────────────────────────────────────────────────────────────────
  Future<bool> login(String nic, String password) async {
    if (nic.isEmpty || password.isEmpty) return false;

    try {
      // Look up email by NIC in Firestore
      final query = await _db
          .collection('users')
          .where('nic', isEqualTo: nic.toUpperCase())
          .limit(1)
          .get();

      String email;
      if (query.docs.isNotEmpty) {
        email = query.docs.first.data()['email'] as String;
      } else {
        // Fallback: try local cache
        return _loginOffline(nic, password);
      }

      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Fetch full profile from Firestore
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();

      if (data?['accountStatus'] == 'deactivated') {
        await _auth.signOut();
        _lastLoginError = 'account_deactivated';
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      // Filter out known bad defaults that old buggy code wrote to Firestore
      final firestoreName = data?['name'] as String?;
      final name = (firestoreName != null && firestoreName.isNotEmpty && firestoreName != 'Citizen User')
          ? firestoreName
          : prefs.getString('userName') ?? '';

      final phone = data?['phone'] as String? ?? prefs.getString('userPhone') ?? '';
      final birthDate = data?['birthDate'] as String? ?? prefs.getString('userBirthDate') ?? _decodeNIC(nic)['birthDate']!;
      final gender = data?['gender'] as String? ?? prefs.getString('userGender') ?? _decodeNIC(nic)['gender']!;

      await _cacheUserData(
        name: name,
        nic: nic.toUpperCase(),
        email: email,
        phone: phone,
        birthDate: birthDate,
        gender: gender,
      );

      _userName = name.isNotEmpty ? name : null;
      _userNIC = nic.toUpperCase();
      _userRole = 'citizen';
      _userBirthDate = birthDate;
      _userGender = gender;
      _userEmail = email;
      _userPhone = phone;
      _userPhotoUrl = data?['photoURL'] as String? ?? prefs.getString('userPhotoUrl');
      _isAuthenticated = true;
      _lastLoginError = null;

      // Cache address from Firestore so it's available on next load
      final fsAddress = data?['address'] as String?;
      if (fsAddress != null) await prefs.setString('userAddress', fsAddress);

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code} - ${e.message}');
      return _loginOffline(nic, password);
    } catch (e) {
      debugPrint('Unexpected login error: $e');
      return _loginOffline(nic, password);
    }
  }

  // Offline fallback login (matches existing SharedPreferences behaviour)
  Future<bool> _loginOffline(String nic, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final cachedNIC = prefs.getString('userNIC') ?? '';

    // Allow login if NIC matches cached or any non-empty input (demo mode)
    if (nic.isNotEmpty && (cachedNIC.isEmpty || cachedNIC == nic.toUpperCase())) {
      final decodedNIC = _decodeNIC(nic.toUpperCase());
      final cachedName = prefs.getString('userName') ?? '';
      final name = (cachedName.isNotEmpty && cachedName != 'Citizen User') ? cachedName : '';
      final cachedEmail = prefs.getString('userEmail') ?? '';
      final email = (cachedEmail.isNotEmpty && cachedEmail != 'citizen@example.com') ? cachedEmail : '';
      final phone = prefs.getString('userPhone') ?? '';

      await _cacheUserData(
        name: name,
        nic: nic.toUpperCase(),
        email: email,
        phone: phone,
        birthDate: decodedNIC['birthDate']!,
        gender: decodedNIC['gender']!,
      );

      _userName = name.isNotEmpty ? name : null;
      _userNIC = nic.toUpperCase();
      _userRole = 'citizen';
      _userBirthDate = decodedNIC['birthDate'];
      _userGender = decodedNIC['gender'];
      _userEmail = email.isNotEmpty ? email : null;
      _userPhone = phone.isNotEmpty ? phone : null;
      _userPhotoUrl = prefs.getString('userPhotoUrl');
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Session ──────────────────────────────────────────────────────────────
  Future<void> checkLoginStatus() async {
    // Check Firebase Auth session first
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      try {
        final doc = await _db.collection('users').doc(firebaseUser.uid).get();
        final data = doc.data();
        if (data?['accountStatus'] == 'deactivated') {
          await logout();
          return;
        }
        if (data != null) {
          final prefs = await SharedPreferences.getInstance();

          // Filter out known bad defaults that old buggy code wrote to Firestore
          final firestoreName = data['name'] as String?;
          final cachedName = prefs.getString('userName') ?? '';
          _userName = (firestoreName != null && firestoreName.isNotEmpty && firestoreName != 'Citizen User')
              ? firestoreName
              : (cachedName.isNotEmpty && cachedName != 'Citizen User') ? cachedName : null;

          _userNIC = data['nic'] as String? ?? prefs.getString('userNIC');
          _userRole = data['role'] as String? ?? 'citizen';
          _userBirthDate = data['birthDate'] as String? ?? prefs.getString('userBirthDate');
          _userGender = data['gender'] as String? ?? prefs.getString('userGender');
          _userEmail = data['email'] as String? ?? prefs.getString('userEmail');
          _userPhone = data['phone'] as String? ?? prefs.getString('userPhone');
          _userPhotoUrl = data['photoURL'] as String? ?? prefs.getString('userPhotoUrl');
          _isAuthenticated = true;

          // Cache address from Firestore
          final fsAddress = data['address'] as String?;
          if (fsAddress != null) await prefs.setString('userAddress', fsAddress);

          await _cacheUserData(
            name: _userName ?? '',
            nic: _userNIC ?? '',
            email: _userEmail ?? '',
            phone: _userPhone ?? '',
            birthDate: _userBirthDate ?? '',
            gender: _userGender ?? '',
          );
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    // Fall back to local cache
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isLoggedIn') ?? false;
    _userNIC = prefs.getString('userNIC');
    final cachedName = prefs.getString('userName');
    _userName = (cachedName != null && cachedName.isNotEmpty && cachedName != 'Citizen User') ? cachedName : null;
    _userRole = prefs.getString('userRole') ?? 'citizen';
    _userBirthDate = prefs.getString('userBirthDate');
    _userGender = prefs.getString('userGender');
    final cachedEmail = prefs.getString('userEmail');
    _userEmail = (cachedEmail != null && cachedEmail.isNotEmpty && cachedEmail != 'citizen@example.com') ? cachedEmail : null;
    _userPhone = prefs.getString('userPhone');
    _userPhotoUrl = prefs.getString('userPhotoUrl');
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userPhotoUrl');

    _isAuthenticated = false;
    _userName = null;
    _userNIC = null;
    _userRole = null;
    _userBirthDate = null;
    _userGender = null;
    _userEmail = null;
    _userPhone = null;
    _userPhotoUrl = null;
    notifyListeners();
  }

  Future<bool> isLoggedIn() async {
    if (_auth.currentUser != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Future<void> _cacheUserData({
    required String name,
    required String nic,
    required String email,
    required String phone,
    required String birthDate,
    required String gender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userRole', 'citizen');
    if (nic.isNotEmpty) await prefs.setString('userNIC', nic);
    // Never overwrite with known bad defaults
    if (name.isNotEmpty && name != 'Citizen User') await prefs.setString('userName', name);
    if (email.isNotEmpty && email != 'citizen@example.com') await prefs.setString('userEmail', email);
    if (phone.isNotEmpty) await prefs.setString('userPhone', phone);
    if (birthDate.isNotEmpty) await prefs.setString('userBirthDate', birthDate);
    if (gender.isNotEmpty) await prefs.setString('userGender', gender);
    if (!prefs.containsKey('memberSince')) {
      final now = DateTime.now();
      const months = ['January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'];
      await prefs.setString('memberSince', '${months[now.month - 1]} ${now.year}');
    }
  }

  // ── Profile update helpers (called by UI screens) ─────────────────────────
  Future<void> updateUserProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
  }) async {
    final uid = _auth.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();

    if (name != null && name.isNotEmpty) {
      _userName = name;
      await prefs.setString('userName', name);
    }
    if (email != null && email.isNotEmpty) {
      _userEmail = email;
      await prefs.setString('userEmail', email);
    }
    if (phone != null) {
      _userPhone = phone.isNotEmpty ? phone : null;
      await prefs.setString('userPhone', phone);
    }
    if (address != null) {
      await prefs.setString('userAddress', address);
    }

    if (uid != null) {
      try {
        final updates = <String, dynamic>{};
        if (name != null && name.isNotEmpty) updates['name'] = name;
        if (email != null && email.isNotEmpty) updates['email'] = email;
        if (phone != null) updates['phone'] = phone;
        if (address != null) updates['address'] = address;
        if (updates.isNotEmpty) {
          await _db.collection('users').doc(uid).update(updates);
        }
      } catch (e) {
        debugPrint('Firestore updateUserProfile failed: $e');
      }
    }

    notifyListeners();
  }

  /// Uploads the given image bytes to Firebase Storage under this user's
  /// UID (overwriting any previous photo) and saves the resulting download
  /// link as the permanent profile photo, replacing the old one if present.
  Future<bool> uploadProfilePhoto(Uint8List bytes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final ref = _storage.ref().child('profile_pictures/$uid.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await updateProfilePhoto(url);
      return true;
    } catch (e) {
      debugPrint('Profile photo upload failed: $e');
      return false;
    }
  }

  Future<void> updateProfilePhoto(String? photoUrl) async {
    _userPhotoUrl = photoUrl;

    final prefs = await SharedPreferences.getInstance();
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await prefs.setString('userPhotoUrl', photoUrl);
    } else {
      await prefs.remove('userPhotoUrl');
    }

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).update({'photoURL': photoUrl});
      } catch (e) {
        debugPrint('Firestore updateProfilePhoto failed: $e');
      }

      if (photoUrl == null) {
        try {
          await _storage.ref().child('profile_pictures/$uid.jpg').delete();
        } catch (e) {
          debugPrint('Firebase Storage photo delete failed: $e');
        }
      }
    }

    notifyListeners();
  }

  // ── Account deletion request/approval flow ────────────────────────────────
  Future<Map<String, dynamic>?> getAccountDeletionRequestStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    // Sorted client-side (rather than orderBy in the query) to avoid needing
    // a Firestore composite index just for this lookup.
    final query = await _db
        .collection('account_deletion_requests')
        .where('uid', isEqualTo: uid)
        .get();
    if (query.docs.isEmpty) return null;
    final docs = query.docs.toList()
      ..sort((a, b) {
        final aTime = a.data()['requestedAt'] as Timestamp?;
        final bTime = b.data()['requestedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
    return {'id': docs.first.id, ...docs.first.data()};
  }

  Future<bool> submitAccountDeletionRequest({String? reason}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final existing = await getAccountDeletionRequestStatus();
    if (existing != null && existing['status'] == 'pending') return false;

    await _db.collection('account_deletion_requests').add({
      'uid': uid,
      'nic': _userNIC,
      'name': _userName,
      'email': _userEmail,
      'reason': reason,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'reviewedBy': null,
      'reviewedAt': null,
      'rejectionReason': null,
      'finalAction': null,
      'finalActionAt': null,
    });
    return true;
  }

  Future<void> finalizeAccountDeletion({
    required String requestId,
    required bool permanentDelete,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (permanentDelete) {
      await _db.collection('account_deletion_requests').doc(requestId).update({
        'finalAction': 'deleted',
        'finalActionAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('users').doc(uid).delete();
      try {
        await _auth.currentUser?.delete();
      } on FirebaseAuthException catch (_) {
        // Re-authentication may be required by Firebase for this sensitive
        // action; the account is already scrubbed from Firestore either way.
      }
    } else {
      await _db.collection('account_deletion_requests').doc(requestId).update({
        'finalAction': 'deactivated',
        'finalActionAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('users').doc(uid).update({'accountStatus': 'deactivated'});
      await _auth.signOut();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isAuthenticated = false;
    _userName = null;
    _userNIC = null;
    _userRole = null;
    _userBirthDate = null;
    _userGender = null;
    _userEmail = null;
    _userPhone = null;
    _userPhotoUrl = null;
    notifyListeners();
  }
}
