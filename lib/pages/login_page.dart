import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/content_card.dart';

/// Mirrors src/pages/Login.tsx — email/password sign in / sign up.
/// Actual auth state propagation happens via HomeShell's onAuthStateChange
/// subscription, so this page only needs to trigger the call.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _mode = 'signIn';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (_mode == 'signIn') {
        await AuthService.signIn(email, password);
      } else {
        await AuthService.signUp(email, password);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _fieldDecoration() {
    return const InputDecoration(
      filled: true,
      fillColor: AppColors.slate900,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: AppColors.slate700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: AppColors.slate700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: AppColors.indigo500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignIn = _mode == 'signIn';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: ContentCard(
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  isSignIn ? 'Sign in' : 'Sign up',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate100),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Email', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.slate100, fontSize: 14),
                decoration: _fieldDecoration(),
              ),
              const SizedBox(height: 16),
              const Text('Password', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.slate100, fontSize: 14),
                decoration: _fieldDecoration(),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.red400, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo600,
                    foregroundColor: AppColors.slate100,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  ),
                  child: Text(isSignIn ? 'Sign in' : 'Sign up', style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _mode = isSignIn ? 'signUp' : 'signIn';
                  });
                },
                child: Text(
                  isSignIn ? "Don't have an account? Sign up" : 'Already have an account? Sign in',
                  style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
