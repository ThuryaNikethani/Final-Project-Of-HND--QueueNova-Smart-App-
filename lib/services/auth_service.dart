import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:queuenova_mobile/config/backend_config.dart';
import 'package:queuenova_mobile/services/push_notification_service.dart';

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
  String? _lastRegisterError;
  String? _lastDeletionRequestError;
  String? _lastPasswordChangeError;

  // ── Two-factor (OTP) pending state ──────────────────────────────────────
  // Set when login() finds `two_factor_enabled` on and credentials check out
  // but the OTP hasn't been verified yet — isAuthenticated stays false until
  // verifyTwoFactorCode() succeeds.
  String? _twoFactorUid;
  Map<String, String>? _twoFactorPendingProfile;

  bool get twoFactorPending => _twoFactorUid != null;
  String? get twoFactorPendingPhone => _twoFactorPendingProfile?['phone'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  String? get lastRegisterError => _lastRegisterError;
  String? get lastDeletionRequestError => _lastDeletionRequestError;
  String? get lastPasswordChangeError => _lastPasswordChangeError;

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
    _lastRegisterError = null;
    try {
      final normalizedNic = nic.toUpperCase();
      final decodedNIC = _decodeNIC(normalizedNic);

      // Reject registration if this NIC is already registered to an account.
      // A direct doc-ID lookup (rather than a field query) so it works under
      // a rule that only allows `get`, not `list`, before the user is signed in.
      final existingIndex = await _db.collection('nic_index').doc(normalizedNic).get();
      if (existingIndex.exists) {
        _lastRegisterError = 'duplicate_nic';
        return false;
      }

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
        'nic': normalizedNic,
        'email': email.trim(),
        'phone': phone,
        'role': 'citizen',
        'birthDate': decodedNIC['birthDate'],
        'gender': decodedNIC['gender'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Public NIC -> uid/email index so login can look up the email before
      // the user is authenticated, without exposing the full profile.
      await _db.collection('nic_index').doc(normalizedNic).set({
        'uid': uid,
        'email': email.trim(),
      });

      // Cache locally
      await _cacheUserData(
        name: name,
        nic: normalizedNic,
        email: email.trim(),
        phone: phone,
        birthDate: decodedNIC['birthDate']!,
        gender: decodedNIC['gender']!,
      );

      _userName = name;
      _userNIC = normalizedNic;
      _userRole = 'citizen';
      _userBirthDate = decodedNIC['birthDate'];
      _userGender = decodedNIC['gender'];
      _userEmail = email.trim();
      _userPhone = phone;
      _isAuthenticated = true;

      await PushNotificationService.instance.registerToken(collection: 'users', docId: uid);

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Registration error: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        // A real duplicate account — do not fall back to offline registration,
        // that would let the same person re-register under the same identity.
        _lastRegisterError = 'duplicate_email';
        return false;
      }
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

    final normalizedNic = nic.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    final cachedNic = prefs.getString('userNIC');
    if (cachedNic != null && cachedNic.isNotEmpty && cachedNic == normalizedNic) {
      _lastRegisterError = 'duplicate_nic';
      return false;
    }

    final decodedNIC = _decodeNIC(normalizedNic);
    await _cacheUserData(
      name: name,
      nic: normalizedNic,
      email: email,
      phone: phone,
      birthDate: decodedNIC['birthDate']!,
      gender: decodedNIC['gender']!,
    );
    _userName = name;
    _userNIC = normalizedNic;
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
      // Look up email by NIC via the public nic_index doc (a direct doc-ID
      // lookup, since the user isn't signed in yet and can't query `users`).
      final indexDoc = await _db.collection('nic_index').doc(nic.toUpperCase()).get();

      String email;
      if (indexDoc.exists) {
        email = indexDoc.data()!['email'] as String;
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
      final photoUrl = data?['photoURL'] as String? ?? prefs.getString('userPhotoUrl');
      final fsAddress = data?['address'] as String?;

      // Two-factor requires a phone number to send the OTP to — without one
      // there's nothing to verify against, so fall through to a normal login
      // rather than locking the citizen out entirely.
      final twoFactorOn = (prefs.getBool('two_factor_enabled') ?? false) && phone.isNotEmpty;
      if (twoFactorOn) {
        _twoFactorUid = uid;
        _twoFactorPendingProfile = {
          'nic': nic.toUpperCase(),
          'name': name,
          'email': email,
          'phone': phone,
          'birthDate': birthDate,
          'gender': gender,
          if (photoUrl != null) 'photoUrl': photoUrl,
          if (fsAddress != null) 'address': fsAddress,
        };
        await _sendTwoFactorCode(uid: uid, phone: phone);
        notifyListeners();
        return true;
      }

      await _finalizeLogin(
        uid: uid,
        nic: nic.toUpperCase(),
        name: name,
        email: email,
        phone: phone,
        birthDate: birthDate,
        gender: gender,
        photoUrl: photoUrl,
        address: fsAddress,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code} - ${e.message}');
      return _loginOffline(nic, password);
    } catch (e) {
      debugPrint('Unexpected login error: $e');
      return _loginOffline(nic, password);
    }
  }

  /// Completes login: caches profile data locally, flips [isAuthenticated],
  /// registers the push token (respecting the notifications preference), and
  /// notifies listeners. Called directly by [login] when two-factor is off,
  /// or by [verifyTwoFactorCode] once the OTP checks out.
  Future<void> _finalizeLogin({
    required String uid,
    required String nic,
    required String name,
    required String email,
    required String phone,
    required String birthDate,
    required String gender,
    String? photoUrl,
    String? address,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await _cacheUserData(
      name: name,
      nic: nic,
      email: email,
      phone: phone,
      birthDate: birthDate,
      gender: gender,
    );

    _userName = name.isNotEmpty ? name : null;
    _userNIC = nic;
    _userRole = 'citizen';
    _userBirthDate = birthDate;
    _userGender = gender;
    _userEmail = email;
    _userPhone = phone;
    _userPhotoUrl = photoUrl;
    _isAuthenticated = true;
    _lastLoginError = null;

    if (address != null) await prefs.setString('userAddress', address);

    if (prefs.getBool('notifications_enabled') ?? true) {
      await PushNotificationService.instance.registerToken(collection: 'users', docId: uid);
    }

    notifyListeners();
  }

  /// Generates a fresh 6-digit code, stores it (5 min expiry) in
  /// `otp_codes/{uid}`, and sends it to [phone] via the backend's Twilio
  /// relay (`/api/sms/send`).
  Future<void> _sendTwoFactorCode({required String uid, required String phone}) async {
    final code = (100000 + Random().nextInt(900000)).toString();
    await _db.collection('otp_codes').doc(uid).set({
      'code': code,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
    });
    try {
      await http.post(
        Uri.parse('${BackendConfig.baseUrl}/api/sms/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'message': 'Your QueueNova verification code is $code. It expires in 5 minutes.'}),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('_sendTwoFactorCode SMS send failed: $e');
    }
  }

  /// Verifies [code] against the pending two-factor login started by
  /// [login]. On success, completes the login via [_finalizeLogin]. On
  /// failure, sets [lastLoginError] to `invalid_otp` or `otp_expired`.
  Future<bool> verifyTwoFactorCode(String code) async {
    final uid = _twoFactorUid;
    final profile = _twoFactorPendingProfile;
    if (uid == null || profile == null) {
      _lastLoginError = 'no_pending_verification';
      return false;
    }
    try {
      final doc = await _db.collection('otp_codes').doc(uid).get();
      final data = doc.data();
      final expiresAt = data?['expiresAt'] as Timestamp?;
      if (data == null || expiresAt == null || DateTime.now().isAfter(expiresAt.toDate())) {
        _lastLoginError = 'otp_expired';
        return false;
      }
      if (data['code'] != code) {
        _lastLoginError = 'invalid_otp';
        return false;
      }

      await _db.collection('otp_codes').doc(uid).delete();
      await _finalizeLogin(
        uid: uid,
        nic: profile['nic']!,
        name: profile['name']!,
        email: profile['email']!,
        phone: profile['phone']!,
        birthDate: profile['birthDate']!,
        gender: profile['gender']!,
        photoUrl: profile['photoUrl'],
        address: profile['address'],
      );
      _twoFactorUid = null;
      _twoFactorPendingProfile = null;
      return true;
    } catch (e) {
      debugPrint('verifyTwoFactorCode error: $e');
      _lastLoginError = 'unknown';
      return false;
    }
  }

  /// Regenerates and resends the OTP for the in-progress two-factor login.
  Future<bool> resendTwoFactorCode() async {
    final uid = _twoFactorUid;
    final phone = _twoFactorPendingProfile?['phone'];
    if (uid == null || phone == null) return false;
    await _sendTwoFactorCode(uid: uid, phone: phone);
    return true;
  }

  /// Cancels an in-progress two-factor login (e.g. user backs out of the OTP
  /// screen) without completing authentication.
  void cancelTwoFactorLogin() {
    _twoFactorUid = null;
    _twoFactorPendingProfile = null;
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

          if (prefs.getBool('notifications_enabled') ?? true) {
            await PushNotificationService.instance
                .registerToken(collection: 'users', docId: firebaseUser.uid);
          }

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
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await PushNotificationService.instance.unregisterToken(collection: 'users', docId: uid);
    }

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
    if (!prefs.containsKey('memberSinceMonth')) {
      final now = DateTime.now();
      await prefs.setInt('memberSinceMonth', now.month);
      await prefs.setInt('memberSinceYear', now.year);
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

  /// Encodes the given image bytes and saves them directly on the user's
  /// Firestore profile document, replacing any previous photo. No separate
  /// file storage involved — just one Firestore write.
  Future<bool> uploadProfilePhoto(Uint8List bytes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      await updateProfilePhoto(base64Encode(bytes));
      return true;
    } catch (e) {
      debugPrint('Profile photo save failed: $e');
      return false;
    }
  }

  Future<void> updateProfilePhoto(String? photoData) async {
    // Write to Firestore first so a failure here throws and is surfaced to
    // the caller, instead of silently leaving only a local copy that
    // disappears once the local cache is cleared on logout.
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({'photoURL': photoData});
    }

    _userPhotoUrl = photoData;

    final prefs = await SharedPreferences.getInstance();
    if (photoData != null && photoData.isNotEmpty) {
      await prefs.setString('userPhotoUrl', photoData);
    } else {
      await prefs.remove('userPhotoUrl');
    }

    notifyListeners();
  }

  // ── Account deletion request/approval flow ────────────────────────────────

  /// Resolves the current citizen's Firebase uid. Prefers the live
  /// FirebaseAuth session; falls back to the `nic_index` lookup (the same
  /// one the web app's `_notifyCitizenByNic` uses) so this flow still works
  /// when the citizen is authenticated via the offline-login fallback
  /// (cached NIC, no live Firebase Auth session).
  Future<String?> _resolveDeletionUid() async {
    final liveUid = _auth.currentUser?.uid;
    if (liveUid != null) return liveUid;
    final nic = _userNIC;
    if (nic == null || nic.isEmpty) return null;
    try {
      final indexDoc = await _db.collection('nic_index').doc(nic.toUpperCase()).get();
      return indexDoc.data()?['uid'] as String?;
    } catch (e) {
      debugPrint('_resolveDeletionUid nic_index lookup failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAccountDeletionRequestStatus() async {
    final uid = await _resolveDeletionUid();
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
    _lastDeletionRequestError = null;
    final uid = await _resolveDeletionUid();
    if (uid == null) {
      _lastDeletionRequestError = 'not_signed_in';
      return false;
    }

    try {
      final existing = await getAccountDeletionRequestStatus();
      if (existing != null && existing['status'] == 'pending') {
        _lastDeletionRequestError = 'already_pending';
        return false;
      }

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

      await _db.collection('staff_notifications').add({
        'title': 'New Account Deletion Request',
        'message': '${_userName ?? 'A citizen'} (${_userNIC ?? uid}) has requested account deletion.',
        'type': 'account_deletion',
        'action': 'View Details',
        'targetRoles': const ['admin', 'serviceProcessor'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('submitAccountDeletionRequest failed: $e');
      _lastDeletionRequestError = e.toString();
      return false;
    }
  }

  Future<void> finalizeAccountDeletion({
    required String requestId,
    required bool permanentDelete,
  }) async {
    final uid = await _resolveDeletionUid();
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

  /// Reauthenticates with [currentPassword] (Firebase requires a recent
  /// sign-in before allowing a password change) then sets [newPassword].
  /// On failure, [lastPasswordChangeError] holds a FirebaseAuthException
  /// code (e.g. `wrong-password`, `weak-password`) or `not_signed_in`.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _lastPasswordChangeError = null;
    final user = _auth.currentUser;
    final email = _userEmail;
    if (user == null || email == null) {
      _lastPasswordChangeError = 'not_signed_in';
      return false;
    }
    try {
      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      _lastPasswordChangeError = e.code;
      return false;
    } catch (e) {
      _lastPasswordChangeError = 'unknown';
      return false;
    }
  }

  /// Files a data-export request against this citizen's account, mirroring
  /// `submitAccountDeletionRequest`'s pattern — a real Firestore record plus
  /// a staff notification, rather than a no-op client-side toast.
  Future<bool> submitDataDownloadRequest() async {
    final uid = await _resolveDeletionUid();
    if (uid == null) return false;
    try {
      await _db.collection('data_download_requests').add({
        'uid': uid,
        'nic': _userNIC,
        'name': _userName,
        'email': _userEmail,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('staff_notifications').add({
        'title': 'Data Download Request',
        'message': '${_userName ?? 'A citizen'} (${_userNIC ?? uid}) requested a copy of their personal data.',
        'type': 'data_download',
        'action': 'View Details',
        'targetRoles': const ['admin'],
        'readBy': <String>[],
        'dismissedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('submitDataDownloadRequest failed: $e');
      return false;
    }
  }

  /// Writes this citizen's profile data to a JSON file in the app's
  /// documents directory and returns its path, or null on failure.
  Future<String?> exportPersonalDataToDevice() async {
    try {
      final uid = await _resolveDeletionUid();
      final data = {
        'uid': uid,
        'name': _userName,
        'nic': _userNIC,
        'email': _userEmail,
        'phone': _userPhone,
        'birthDate': _userBirthDate,
        'gender': _userGender,
        'role': _userRole,
        'exportedAt': DateTime.now().toIso8601String(),
      };
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/queuenova_personal_data_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      return file.path;
    } catch (e) {
      debugPrint('exportPersonalDataToDevice failed: $e');
      return null;
    }
  }
}
