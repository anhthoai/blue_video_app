import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/locale_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common/app_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    tooltip: l10n.selectLanguage,
                    onSelected: (languageCode) {
                      ref
                          .read(localeProvider.notifier)
                          .setLocale(Locale(languageCode));
                    },
                    itemBuilder: (context) => _languageOptions
                        .map(
                          (option) => PopupMenuItem<String>(
                            value: option.code,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(option.flag),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(option.label)),
                                if (currentLocale.languageCode == option.code)
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _displayLanguageForCode(currentLocale.languageCode),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Logo
                const AppLogo(
                  size: 100,
                  borderRadius: 20,
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  l10n.welcomeBack,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 8),

                Text(
                  l10n.signInToAccount,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),

                const SizedBox(height: 32),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseEnterEmail;
                    }
                    if (!value.contains('@')) {
                      return l10n.pleaseEnterValidEmail;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseEnterPassword;
                    }
                    if (value.length < 6) {
                      return l10n.passwordMinLength;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Remember Me & Forgot Password Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  l10n.rememberMe,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                final email = _emailController.text.trim();
                                final location = Uri(
                                  path: '/auth/forgot-password',
                                  queryParameters:
                                      email.isEmpty ? null : {'email': email},
                                ).toString();
                                context.push(location);
                              },
                              child: Text(l10n.forgotPassword),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            l10n.rememberMe,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final email = _emailController.text.trim();
                            final location = Uri(
                              path: '/auth/forgot-password',
                              queryParameters:
                                  email.isEmpty ? null : {'email': email},
                            ).toString();
                            context.push(location);
                          },
                          child: Text(l10n.forgotPassword),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(l10n.signIn),
                  ),
                ),

                if (_isBiometricEnabled) ...[
                  const SizedBox(height: 12),
                  Tooltip(
                    message: l10n.signInWithBiometrics,
                    child: IconButton.filledTonal(
                      onPressed: (_isLoading || _isBiometricLoading)
                          ? null
                          : _handleBiometricLogin,
                      iconSize: 28,
                      icon: _isBiometricLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Divider (Hidden - will be used when social login is implemented)
                // Row(
                //   children: [
                //     const Expanded(child: Divider()),
                //     Padding(
                //       padding: const EdgeInsets.symmetric(horizontal: 16),
                //       child: Text(
                //         'OR',
                //         style: Theme.of(context).textTheme.bodySmall,
                //       ),
                //     ),
                //     const Expanded(child: Divider()),
                //   ],
                // ),

                // const SizedBox(height: 24),

                // Social Login Buttons (Hidden - will be implemented in future)
                // Row(
                //   children: [
                //     Expanded(
                //       child: OutlinedButton.icon(
                //         onPressed: () {
                //           // Handle Google login
                //         },
                //         icon: const Icon(Icons.g_mobiledata),
                //         label: const Text('Google'),
                //       ),
                //     ),
                //     const SizedBox(width: 16),
                //     Expanded(
                //       child: OutlinedButton.icon(
                //         onPressed: () {
                //           // Handle Apple login
                //         },
                //         icon: const Icon(Icons.apple),
                //         label: const Text('Apple'),
                //       ),
                //     ),
                //   ],
                // ),

                // const SizedBox(height: 24),

                // Sign Up Link
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${l10n.dontHaveAccount} '),
                    TextButton(
                      onPressed: () {
                        context.go('/auth/register');
                      },
                      child: Text(l10n.signUp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use real auth service
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        rememberMe: _rememberMe,
      );

      if (user != null) {
        // Login successful - navigate to main screen
        if (mounted) {
          context.go('/main');
        }
      } else {
        // Login failed - show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login failed: Invalid credentials'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Login error: $e');
      // Show error message only if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always reset loading state if widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        await _loadBiometricState();
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() {
      _isBiometricLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final hasStoredCredentials =
          await authService.hasStoredBiometricCredentials();
      if (!hasStoredCredentials) {
        if (!mounted) return;
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.biometricSetupRequired)),
        );
        return;
      }

      final user = await authService.signInWithBiometrics(
        localizedReason: l10n.authenticateToLogin,
      );

      if (!mounted) return;

      if (user != null) {
        context.go('/main');
      } else {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.biometricLoginFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('${l10n.biometricLoginError}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isBiometricLoading = false;
      });
      await _loadBiometricState();
    }
  }

  Future<void> _loadBiometricState() async {
    final authService = ref.read(authServiceProvider);
    final enabled = await authService.isBiometricLoginEnabled();

    if (!mounted) return;

    setState(() {
      _isBiometricEnabled = enabled;
    });
  }

  String _displayLanguageForCode(String code) {
    for (final option in _languageOptions) {
      if (option.code == code) return option.shortLabel;
    }
    return 'English';
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.flag,
    required this.label,
    required this.shortLabel,
  });

  final String code;
  final String flag;
  final String label;
  final String shortLabel;
}

const List<_LanguageOption> _languageOptions = [
  _LanguageOption(
    code: 'en',
    flag: '🇺🇸',
    label: 'English',
    shortLabel: 'EN',
  ),
  _LanguageOption(
    code: 'zh',
    flag: '🇨🇳',
    label: '中文',
    shortLabel: '中文',
  ),
  _LanguageOption(
    code: 'ja',
    flag: '🇯🇵',
    label: '日本語',
    shortLabel: '日本語',
  ),
  _LanguageOption(
    code: 'vi',
    flag: '🇻🇳',
    label: 'Tiếng Việt',
    shortLabel: 'VI',
  ),
  _LanguageOption(
    code: 'ko',
    flag: '🇰🇷',
    label: '한국어',
    shortLabel: '한국어',
  ),
  _LanguageOption(
    code: 'th',
    flag: '🇹🇭',
    label: 'ไทย',
    shortLabel: 'ไทย',
  ),
  _LanguageOption(
    code: 'pt',
    flag: '🇵🇹',
    label: 'Português',
    shortLabel: 'PT',
  ),
  _LanguageOption(
    code: 'es',
    flag: '🇪🇸',
    label: 'Español',
    shortLabel: 'ES',
  ),
  _LanguageOption(
    code: 'id',
    flag: '🇮🇩',
    label: 'Bahasa Indonesia',
    shortLabel: 'ID',
  ),
  _LanguageOption(
    code: 'tr',
    flag: '🇹🇷',
    label: 'Türkçe',
    shortLabel: 'TR',
  ),
  _LanguageOption(
    code: 'ar',
    flag: '🇸🇦',
    label: 'العربية',
    shortLabel: 'العربية',
  ),
];
