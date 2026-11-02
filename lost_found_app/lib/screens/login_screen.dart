import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/app_background.dart';
import '../widgets/cut_logo_badge.dart';

class LoginScreen extends StatefulWidget {
  final bool startInSignUp;

  const LoginScreen({super.key, this.startInSignUp = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _navyButton = Color(0xFF1C4A7D);
  static const _linkBlue = Color(0xFF8C8CFF);
  static const _labelColor = Color(0xFFE4E9EF);
  static const _fieldText = Color(0xFF1F2A37);
  static const _hintColor = Color(0xFF8A97A6);
  static const _errorRed = Color(0xFFFF8A80);

  // Field keys, in the order they appear on screen
  static const _keys = ['name', 'email', 'phone', 'password', 'confirm'];

  final _service = SupabaseService();
  final _ctl = <String, TextEditingController>{
    for (final k in _keys) k: TextEditingController(),
  };
  final _focus = <String, FocusNode>{
    for (final k in _keys) k: FocusNode(),
  };

  late bool _isSignUp;
  bool _loading = false;

  // A field's mistakes appear as soon as the student leaves it (touched),
  // and every field's mistakes appear once they press the button (submitted).
  bool _submitted = false;
  final _touched = <String>{};

  String? _serverError;
  String? _infoMessage;
  int _shake = 0; // bump to replay the shake animation
  final _serverBannerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.startInSignUp;
    _syncFooter();
    for (final entry in _focus.entries) {
      entry.value.addListener(() {
        if (!entry.value.hasFocus && mounted) {
          setState(() => _touched.add(entry.key));
        }
      });
    }
  }

  @override
  void dispose() {
    // Leaving this page: the footer may show again on the next one
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppBackground.setFooterHidden(this, false));
    for (final c in _ctl.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  String _text(String key) => _ctl[key]!.text.trim();

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  static final _emailFormat = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // Only CUT student/staff emails are allowed
  // (student@stud.cut.ac.za, name@cut.ac.za, ...).
  bool _isCutDomain(String domain) =>
      domain == 'cut.ac.za' || domain.endsWith('.cut.ac.za');

  // Catches near-misses such as name@stud.cut.co.za or name@cut.ac.za.com
  // and offers the corrected address.
  String? _emailSuggestion(String email) {
    final e = email.toLowerCase().trim();
    final at = e.indexOf('@');
    if (at < 1 || at != e.lastIndexOf('@')) return null;
    final local = e.substring(0, at);
    final domain = e.substring(at + 1);
    if (domain.isEmpty || _isCutDomain(domain)) return null;

    // Does the domain contain a "cut" part (…cut.something)?
    final match = RegExp(r'(^|\.)cut(\.|$)').firstMatch(domain);
    if (match == null) return null;
    final prefix = domain.substring(0, match.start + match.group(1)!.length);
    return '$local@${prefix}cut.ac.za';
  }

  // Accepts 0821234567 or +27821234567 (spaces and dashes are ignored).
  // Returns the number as +27..., or null if it isn't valid.
  String? _normalizePhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (RegExp(r'^\+27[0-9]{9}$').hasMatch(cleaned)) return cleaned;
    if (RegExp(r'^0[0-9]{9}$').hasMatch(cleaned)) {
      return '+27${cleaned.substring(1)}';
    }
    return null;
  }

  /// Every current mistake, keyed by field. Empty map = good to go.
  Map<String, String> _validate() {
    final errors = <String, String>{};

    // ----- Full name (sign-up only) -----
    if (_isSignUp) {
      final name = _text('name');
      if (name.isEmpty) {
        errors['name'] = 'Please enter your full name.';
      } else if (!RegExp(r"^\p{L}[\p{L} '\-.]*$", unicode: true)
          .hasMatch(name)) {
        errors['name'] =
            'Names can only contain letters, spaces, hyphens and apostrophes.';
      } else if (name.split(RegExp(r'\s+')).length < 2) {
        errors['name'] = 'Please enter your first name and your surname.';
      }
    }

    // ----- Email -----
    final email = _text('email');
    if (email.isEmpty) {
      errors['email'] = 'Please enter your CUT email address.';
    } else if (email.contains(RegExp(r'\s'))) {
      errors['email'] = 'Your email address cannot contain spaces.';
    } else if (!email.contains('@')) {
      errors['email'] =
          'Your email is missing the @ symbol. It should look like 12345678@stud.cut.ac.za.';
    } else if (email.split('@').length > 2) {
      errors['email'] = 'Your email has more than one @ symbol.';
    } else if (!_emailFormat.hasMatch(email)) {
      errors['email'] =
          'That is not a complete email address. It should look like name@cut.ac.za.';
    } else {
      final domain = email.toLowerCase().split('@').last;
      if (!_isCutDomain(domain)) {
        errors['email'] = _emailSuggestion(email) != null
            ? "'$domain' is not a CUT domain. CUT emails end in cut.ac.za."
            : 'Only CUT email addresses (ending in cut.ac.za) are allowed.';
      }
    }

    // ----- Phone (sign-up only) -----
    if (_isSignUp) {
      final phone = _text('phone');
      if (phone.isEmpty) {
        errors['phone'] = 'Please enter your phone number.';
      } else if (RegExp(r'[^\d\s\-+()]').hasMatch(phone)) {
        errors['phone'] = 'Your phone number can only contain digits.';
      } else if (_normalizePhone(phone) == null) {
        errors['phone'] =
            'Enter a valid South African number, e.g. 082 123 4567 or +27 82 123 4567.';
      }
    }

    // ----- Password -----
    final password = _text('password');
    if (password.isEmpty) {
      errors['password'] = _isSignUp
          ? 'Please create a password.'
          : 'Please enter your password.';
    } else if (_isSignUp && password.length < 6) {
      errors['password'] =
          'Your password must be at least 6 characters (it has ${password.length}).';
    }

    // ----- Confirm password (sign-up only) -----
    if (_isSignUp) {
      final confirm = _text('confirm');
      if (confirm.isEmpty) {
        errors['confirm'] = 'Please re-enter your password.';
      } else if (confirm != password) {
        errors['confirm'] = 'The passwords do not match.';
      }
    }

    return errors;
  }

  bool _showError(String key) => _submitted || _touched.contains(key);

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _submitted = true;
        _serverError = null;
        _infoMessage = null;
        _shake++;
      });
      // Jump to the first field with a mistake (this also scrolls it into view)
      for (final k in _keys) {
        if (errors.containsKey(k)) {
          _focus[k]!.requestFocus();
          break;
        }
      }
      return;
    }

    final email = _text('email');
    final password = _text('password');

    setState(() {
      _loading = true;
      _serverError = null;
      _infoMessage = null;
    });

    try {
      if (_isSignUp) {
        final res = await _service.signUp(
          email,
          password,
          fullName: _text('name'),
          phone: _normalizePhone(_text('phone')),
        );

        // If email confirmation is switched on in Supabase, there is no
        // session yet: ask the student to confirm, then sign in.
        if (res.session == null) {
          if (!mounted) return;
          setState(() {
            _isSignUp = false;
            _submitted = false;
            _touched.clear();
            _ctl['password']!.clear();
            _ctl['confirm']!.clear();
            _infoMessage =
                'Account created. Check your email to confirm it, then sign in.';
          });
          return;
        }
      } else {
        await _service.signIn(email, password);
      }

      if (!mounted) return;
      // Return to AuthGate, which now shows HomeScreen automatically
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      _showServerError(_friendlyAuthError(e));
    } catch (e) {
      _showServerError(
          'Could not reach the server. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(AuthException e) {
    final m = e.message.toLowerCase();
    if (_isSignUp) {
      if (m.contains('already registered') || m.contains('already exists')) {
        return 'An account with this email already exists. Try signing in instead.';
      }
      if (m.contains('rate limit') || m.contains('too many')) {
        return 'Too many attempts. Please wait a minute and try again.';
      }
      return e.message;
    }
    if (m.contains('not confirmed')) {
      return 'Please confirm your email first. Check your inbox for the link.';
    }
    return 'Login failed. Check your details and try again.';
  }

  void _showServerError(String message) {
    if (!mounted) return;
    setState(() {
      _serverError = message;
      _shake++;
    });
    // Make sure the message is on screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _serverBannerKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  // The footer is hidden on the create-account page only
  void _syncFooter() {
    final hide = _isSignUp;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppBackground.setFooterHidden(this, hide));
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _syncFooter();
      _submitted = false;
      _touched.clear();
      _serverError = null;
      _infoMessage = null;
    });
  }

  void _applySuggestion(String suggestion) {
    final c = _ctl['email']!;
    c.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    setState(() => _serverError = null);
  }

  // ---------------------------------------------------------------------
  // UI pieces
  // ---------------------------------------------------------------------

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(color: _labelColor, fontSize: 14)),
    );
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: width == 0
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  Widget _field({
    required String fieldKey,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    TextCapitalization capitalization = TextCapitalization.none,
    Iterable<String>? autofillHints,
    String? errorText,
    Widget? extra,
    VoidCallback? onSubmit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: _ctl[fieldKey],
            focusNode: _focus[fieldKey],
            obscureText: obscure,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            autofillHints: autofillHints,
            textInputAction:
                onSubmit != null ? TextInputAction.done : TextInputAction.next,
            onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
            // Re-check as they type, so a fixed mistake clears straight away
            onChanged: (_) => setState(() => _serverError = null),
            style: const TextStyle(color: _fieldText, fontSize: 15),
            cursorColor: _navyButton,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: _border(Colors.transparent, 0),
              focusedBorder: _border(_navyButton, 2),
              errorText: errorText,
              errorMaxLines: 4,
              errorStyle: const TextStyle(
                color: _errorRed,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              errorBorder: _border(_errorRed, 2),
              focusedErrorBorder: _border(_errorRed, 2),
            ),
          ),
          if (extra != null) extra,
        ],
      ),
    );
  }

  // Quick left-right shake whenever _shake changes
  Widget _shaking(Widget child) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_shake),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * 9 * (1 - t), 0),
        child: child,
      ),
      child: child,
    );
  }

  Widget _errorBanner(String message, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 16),
      child: _shaking(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x33FF5252),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _errorRed, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: _errorRed, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only the mistakes the student should be seeing right now
    final errors = <String, String>{
      for (final e in _validate().entries)
        if (_showError(e.key)) e.key: e.value,
    };

    final suggestion =
        errors.containsKey('email') ? _emailSuggestion(_text('email')) : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: CutLogoBadge.toolbarHeight,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: CutLogoBadge(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Extra bottom padding keeps the form clear of the footer text
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 64),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSignUp ? 'Create Account' : 'Sign in',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'Join the CUT Lost & Found community'
                        : 'Welcome back to CUT Lost & Found',
                    style: const TextStyle(
                        color: Color(0xFFB8C4D4), fontSize: 14),
                  ),
                  const SizedBox(height: 22),

                  // Summary of what is wrong, shown after pressing the button
                  if (_submitted && errors.isNotEmpty)
                    _errorBanner(
                      errors.length == 1
                          ? 'There is 1 thing to fix. It is highlighted below.'
                          : 'There are ${errors.length} things to fix. They are highlighted below.',
                    ),

                  if (_isSignUp)
                    _field(
                      fieldKey: 'name',
                      label: 'Full Name',
                      hint: 'Enter your first name and surname',
                      capitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      errorText: errors['name'],
                    ),

                  _field(
                    fieldKey: 'email',
                    label: 'Student / Staff Email',
                    hint: 'name@cut.ac.za',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    errorText: errors['email'],
                    extra: suggestion == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: () => _applySuggestion(suggestion),
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                      color: Color(0xFFB8C4D4),
                                      fontSize: 13,
                                      height: 1.35),
                                  children: [
                                    const TextSpan(text: 'Did you mean '),
                                    TextSpan(
                                      text: suggestion,
                                      style: const TextStyle(
                                        color: _linkBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(text: '?  Tap to use it.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),

                  if (_isSignUp)
                    _field(
                      fieldKey: 'phone',
                      label: 'Phone Number',
                      hint: '+27 00 000 0000',
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      errorText: errors['phone'],
                    ),

                  _field(
                    fieldKey: 'password',
                    label: 'Password',
                    hint: _isSignUp
                        ? 'Create a password (6+ characters)'
                        : 'Enter your password',
                    obscure: true,
                    autofillHints: _isSignUp
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    errorText: errors['password'],
                    onSubmit: _isSignUp ? null : _submit,
                  ),

                  if (_isSignUp)
                    _field(
                      fieldKey: 'confirm',
                      label: 'Confirm Password',
                      hint: 'Type your password again',
                      obscure: true,
                      autofillHints: const [AutofillHints.newPassword],
                      errorText: errors['confirm'],
                      onSubmit: _submit,
                    ),

                  // Errors that come back from the server
                  if (_serverError != null)
                    _errorBanner(_serverError!, key: _serverBannerKey),
                  if (_infoMessage != null) ...[
                    Text(
                      _infoMessage!,
                      style: const TextStyle(color: Color(0xFF81C784)),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navyButton,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color.fromRGBO(28, 74, 125, 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _toggleMode,
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : 'No account? Sign up',
                        style: const TextStyle(color: _linkBlue),
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
}