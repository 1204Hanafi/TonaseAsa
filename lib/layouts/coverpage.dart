import 'package:flutter/material.dart';

class CoverPage extends StatefulWidget {
  const CoverPage({super.key});

  @override
  CoverPageState createState() => CoverPageState();
}

class CoverPageState extends State<CoverPage> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  void _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FCFD),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Logo Aplikasi Tonase',
              child: Image.asset(
                'assets/IconTonase.png',
                width: 160,
                errorBuilder:
                    (context, error, stackTrace) =>
                        const Icon(Icons.error_outline, size: 60),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'tonase',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF153441),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
