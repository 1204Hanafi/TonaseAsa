import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkRememberMe();
  }

  Future<void> _checkRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldRemember = prefs.getBool('remember_me') ?? false;

      if (shouldRemember && _authService.currentUser != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showErrorDialog('Gagal memuat preferensi pengguna');
    }
  }

  Future<void> _login() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        await _saveLoginPreference();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showErrorDialog('Terjadi Kesalahan Sistem');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog('Email dan password wajib diisi', icon: Icons.warning);
      return false;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showErrorDialog('Format email tidak valid', icon: Icons.warning);
      return false;
    }
    return true;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _saveLoginPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _rememberMe);
  }

  void _handleAuthError(AuthException e) {
    String message;
    IconData icon;
    Color color = Colors.red;

    switch (e.code) {
      case 'user-not-found':
        message = 'Email tidak terdaftar';
        icon = Icons.person_off;
        break;
      case 'wrong-password':
        message = 'Password salah';
        icon = Icons.lock_outline;
        break;
      case 'invalid-email':
        message = 'Format email tidak valid';
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case 'user-disabled':
        message = 'Akun telah dinonaktifkan';
        icon = Icons.block;
        break;
      case 'too-many-requests':
        message = 'Terlalu banyak percobaan login, coba lagi nanti';
        icon = Icons.timelapse;
        break;
      case 'invalid-credential':
        message = 'Periksa kembali email dan password kamu';
        icon = Icons.lock_outline;
        break;
      default:
        message = 'Terjadi kesalahan: ${e.message}';
        icon = Icons.error;
    }
    _showErrorDialog(message, icon: icon, color: color);
  }

  void _showErrorDialog(
    String message, {
    IconData icon = Icons.error,
    Color color = Colors.red,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset('assets/IconInApp.png', width: 200),
                const SizedBox(height: 40),
                Text(
                  'Masuk',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                _buildEmailField(),
                const SizedBox(height: 24),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildRememberMe(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 40),
                _buildLoginButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      key: Key('email-field'),
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.email),
      ),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      key: Key('password-field'),
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) => setState(() => _rememberMe = value ?? false),
        ),
        const Text('Ingat Saya'),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          key: Key('register-button'),
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text(
            'Daftar Akun Baru',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          key: Key('forgot-password-button'),
          onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
          child: const Text(
            'Lupa Password?',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: Key('login-button'),
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'MASUK',
                style: TextStyle(
                  fontSize: 18,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
