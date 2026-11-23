import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/models/authenticated_user.dart';
import '../../../core/widgets/section_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.apiService,
    required this.onAuthenticated,
  });

  final PosApiService apiService;
  final ValueChanged<AuthenticatedUser> onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _licenseKey = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureLicense = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _licenseKey.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.apiService.login(
        email: _email.text,
        password: _password.text,
        licenseKey: _licenseKey.text,
      );
      if (mounted) widget.onAuthenticated(user);
    } on PosApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF17834B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mysztech Store Assistant',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to your POS staging account',
                  style: TextStyle(color: Color(0xFF69756E)),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your email.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _licenseKey,
                          obscureText: _obscureLicense,
                          keyboardType: TextInputType.number,
                          autocorrect: false,
                          inputFormatters: const [LicenseKeyInputFormatter()],
                          decoration: InputDecoration(
                            labelText: 'License key (5 digits per group)',
                            prefixIcon: const Icon(Icons.key_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscureLicense
                                  ? 'Show license key'
                                  : 'Hide license key',
                              onPressed: () => setState(
                                () => _obscureLicense = !_obscureLicense,
                              ),
                              icon: Icon(
                                _obscureLicense
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your license key.'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFB54735)),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _loading ? null : _signIn,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_loading ? 'Signing in…' : 'Sign in'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Your credentials are sent to the staging login API and are not saved by this app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF69756E),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LicenseKeyInputFormatter extends TextInputFormatter {
  const LicenseKeyInputFormatter();

  static const _maxDigits = 20;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;

    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitedDigits = digits.length > _maxDigits
        ? digits.substring(0, _maxDigits)
        : digits;
    final formatted = _formatDigits(limitedDigits);

    int formattedOffset(int rawOffset) {
      final safeOffset = rawOffset.clamp(0, newValue.text.length);
      final digitCount = newValue.text
          .substring(0, safeOffset)
          .replaceAll(RegExp(r'\D'), '')
          .length
          .clamp(0, limitedDigits.length);
      if (digitCount == 0) return 0;
      final separators = digitCount ~/ 5 - (digitCount == _maxDigits ? 1 : 0);
      return digitCount + separators;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: formattedOffset(newValue.selection.baseOffset),
        extentOffset: formattedOffset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }

  static String _formatDigits(String digits) {
    final groups = <String>[];
    for (var start = 0; start < digits.length; start += 5) {
      final end = (start + 5).clamp(0, digits.length);
      groups.add(digits.substring(start, end));
    }
    final result = groups.join('-');
    if (digits.isNotEmpty &&
        digits.length < _maxDigits &&
        digits.length % 5 == 0) {
      return '$result-';
    }
    return result;
  }
}
