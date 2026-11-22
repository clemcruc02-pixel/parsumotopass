import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/student_api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import 'staff_workspace.dart';

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.header,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text('M',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        const Text('ParSU Motopass',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Motor sticker application',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(
      {required this.prompt, required this.action, required this.onTap});
  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text.rich(TextSpan(
          text: '$prompt ',
          style: const TextStyle(fontSize: 13),
          children: [
            TextSpan(
                text: action,
                style: const TextStyle(
                    color: AppColors.greenDark, fontWeight: FontWeight.w800)),
          ],
        )),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.demo = kDebugMode &&
      const bool.fromEnvironment('MOTOPASS_DEMO')});
  final bool demo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _identity = '';
  String _password = '';
  bool _busy = false;

  Future<void> _login() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppState.instance.signIn(_identity, _password, demo: widget.demo);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AppState.instance.isStaff
            ? const StaffWorkspace()
            : const MainShell()),
      );
    } on StudentApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 70, 28, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Logo(),
                const SizedBox(height: 36),
                LabeledField(
                    label: 'Campus ID / Email',
                    onChanged: (value) => _identity = value,
                    validator: requiredValidator),
                LabeledField(
                    label: 'Password',
                    hint: '••••••••',
                    obscure: true,
                    onChanged: (value) => _password = value,
                    validator: requiredValidator),
                const SizedBox(height: 8),
                PrimaryButton(label: _busy ? 'Signing in…' : 'Log In',
                    onPressed: _busy ? null : _login),
                const SizedBox(height: 14),
                if (!widget.demo)
                  const Center(child: Text('Contact the campus office for account access.')),
                if (widget.demo && !_busy) _FooterLink(
                  prompt: 'No account yet?',
                  action: 'Sign Up',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _password = '';

  void _create() {
    if (!_formKey.currentState!.validate()) return;
    final state = AppState.instance;
    state.isDemo = true;
    state.studentName = _name.trim().split(' ').first;
    state.fullName = _name.trim();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PageHeader(
              title: 'Sign Up', subtitle: 'Create an account', showBack: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                        label: 'Full name',
                        onChanged: (v) => _name = v,
                        validator: requiredValidator),
                    const LabeledField(
                        label: 'Student ID',
                        hint: 'e.g. 202410654',
                        keyboardType: TextInputType.number,
                        validator: requiredValidator),
                    LabeledField(
                      label: 'School email',
                      hint: 'name@parsu.edu.ph',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    LabeledField(
                      label: 'Password',
                      hint: '••••••••',
                      obscure: true,
                      onChanged: (v) => _password = v,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
                          : null,
                    ),
                    LabeledField(
                      label: 'Confirm password',
                      hint: '••••••••',
                      obscure: true,
                      validator: (v) =>
                          v != _password ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(label: 'Create account', onPressed: _create),
                    const SizedBox(height: 14),
                    _FooterLink(
                      prompt: 'Already have an account?',
                      action: 'Log In',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
