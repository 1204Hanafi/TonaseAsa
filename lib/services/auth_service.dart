import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service untuk handle autentikasi menggunakan Firebase Auth.
/// Menyediakan: registrasi, login, logout, dan reset password.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({@visibleForTesting FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Registrasi user baru dengan email & password.
  /// Throw [AuthException] jika gagal (contoh error code: 'email-already-in-use').
  Future<User?> signUp(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: e.message ?? 'Terjadi kesalahan saat registrasi',
      );
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Terjadi kesalahan tidak diketahui: $e',
      );
    }
  }

  /// Login dengan email & password.
  /// Throw [AuthException] jika gagal (contoh error code: 'wrong-password').
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: e.message ?? 'Terjadi kesalahan saat login',
      );
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Terjadi kesalahan tidak diketahui: $e',
      );
    }
  }

  /// Logout user.
  /// Return `true` jika berhasil.
  Future<bool> signOut() async {
    await _auth.signOut();
    return _auth.currentUser == null;
  }

  /// Kirim email reset password.
  /// Throw [AuthException] jika gagal (contoh error code: 'user-not-found').
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: e.message ?? 'Terjadi kesalahan saat mengatur ulang password',
      );
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Terjadi kesalahan tidak diketahui: $e',
      );
    }
  }
}

/// Exception kustom untuk error autentikasi.
class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({required this.code, required this.message});

  @override
  String toString() => 'AuthException(code: $code, message: $message)';
}
