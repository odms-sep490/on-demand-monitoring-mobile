import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/strings.dart';
import 'session.dart';

enum AuthMode { login, register, verify, forgot, reset, firstLogin }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      fullName = TextEditingController(),
      otp = TextEditingController();
  AuthMode mode = AuthMode.login;
  bool busy = false, remember = true, obscure = true;
  String? error, notice;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    fullName.dispose();
    otp.dispose();
    super.dispose();
  }

  void changeMode(AuthMode next) => setState(() {
    mode = next;
    error = null;
    notice = null;
    password.clear();
  });

  Future<void> execute(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    await execute(() async {
      final api = ref.read(apiProvider), session = ref.read(sessionProvider);
      switch (mode) {
        case AuthMode.login:
          await session.login(email.text, password.text, remember);
          if (session.challenge != null && mounted) {
            changeMode(AuthMode.firstLogin);
          }
        case AuthMode.firstLogin:
          await session.completeFirstLogin(email.text, password.text, remember);
        case AuthMode.register:
          await api.request(
            '/api/auth/register',
            method: 'POST',
            authenticated: false,
            body: {
              'email': email.text.trim(),
              'password': password.text,
              'fullName': fullName.text.trim(),
              'role': 'CUSTOMER',
            },
          );
          if (mounted) changeMode(AuthMode.verify);
        case AuthMode.verify:
          await api.request(
            '/api/auth/verify-otp',
            method: 'POST',
            authenticated: false,
            body: {'email': email.text.trim(), 'otpCode': otp.text.trim()},
          );
          if (mounted) {
            changeMode(AuthMode.login);
            notice = context.tr(
              'Email verified. Sign in to continue.',
              'Email đã xác thực. Vui lòng đăng nhập.',
            );
          }
        case AuthMode.forgot:
          await api.request(
            '/api/auth/forgot-password',
            method: 'POST',
            authenticated: false,
            body: {'email': email.text.trim()},
          );
          if (mounted) changeMode(AuthMode.reset);
        case AuthMode.reset:
          await api.request(
            '/api/auth/reset-password',
            method: 'POST',
            authenticated: false,
            body: {
              'email': email.text.trim(),
              'otpCode': otp.text.trim(),
              'newPassword': password.text,
            },
          );
          if (mounted) {
            changeMode(AuthMode.login);
            notice = context.tr(
              'Password reset. Sign in to continue.',
              'Đã đặt lại mật khẩu. Vui lòng đăng nhập.',
            );
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      AuthMode.login => context.tr('Welcome back', 'Chào mừng trở lại'),
      AuthMode.register => context.tr(
        'Create customer account',
        'Tạo tài khoản khách hàng',
      ),
      AuthMode.verify => context.tr('Verify your email', 'Xác thực email'),
      AuthMode.forgot => context.tr(
        'Recover your account',
        'Khôi phục tài khoản',
      ),
      AuthMode.reset || AuthMode.firstLogin => context.tr(
        'Set a new password',
        'Đặt mật khẩu mới',
      ),
    };
    final showPassword = [
      AuthMode.login,
      AuthMode.register,
      AuthMode.reset,
      AuthMode.firstLogin,
    ].contains(mode);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 76,
                        height: 76,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ODMS',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      Text('OnDemand Monitoring', textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      if (mode == AuthMode.register) ...[
                        TextFormField(
                          controller: fullName,
                          decoration: InputDecoration(
                            labelText: context.tr('Full name', 'Họ và tên'),
                          ),
                          validator: requiredValue,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: email,
                        enabled: !busy && mode != AuthMode.firstLogin,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) =>
                            value != null &&
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value.trim())
                            ? null
                            : context.tr(
                                'Enter a valid email.',
                                'Nhập email hợp lệ.',
                              ),
                      ),
                      if (mode == AuthMode.verify ||
                          mode == AuthMode.reset) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: otp,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'Verification code',
                              'Mã xác thực',
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: requiredValue,
                        ),
                      ],
                      if (showPassword) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: password,
                          obscureText: obscure,
                          autofillHints: [
                            mode == AuthMode.login
                                ? AutofillHints.password
                                : AutofillHints.newPassword,
                          ],
                          decoration: InputDecoration(
                            labelText: context.tr('Password', 'Mật khẩu'),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? requiredValue(value)
                              : mode != AuthMode.login && value.length < 8
                              ? context.tr(
                                  'Use at least 8 characters.',
                                  'Dùng ít nhất 8 ký tự.',
                                )
                              : null,
                        ),
                      ],
                      if (mode == AuthMode.login)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: remember,
                          onChanged: busy
                              ? null
                              : (value) => setState(() => remember = value!),
                          title: Text(
                            context.tr('Remember me', 'Ghi nhớ đăng nhập'),
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (notice != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(notice!),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.tr('Continue', 'Tiếp tục')),
                        ),
                      ),
                      if (mode == AuthMode.login) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => execute(
                                  ref.read(sessionProvider).googleLogin,
                                ),
                          icon: const Icon(Icons.login),
                          label: Text(
                            context.tr(
                              'Continue with Google',
                              'Tiếp tục với Google',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => changeMode(AuthMode.register),
                          child: Text(
                            context.tr('Create an account', 'Tạo tài khoản'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => changeMode(AuthMode.forgot),
                          child: Text(
                            context.tr('Forgot password?', 'Quên mật khẩu?'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => changeMode(AuthMode.verify),
                          child: Text(
                            context.tr('Verify email', 'Xác thực email'),
                          ),
                        ),
                      ] else
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => changeMode(AuthMode.login),
                          child: Text(
                            context.tr('Back to sign in', 'Quay lại đăng nhập'),
                          ),
                        ),
                      if (mode == AuthMode.verify)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => execute(() async {
                                  await ref
                                      .read(apiProvider)
                                      .request(
                                        '/api/auth/resend-otp',
                                        method: 'POST',
                                        authenticated: false,
                                        body: {'email': email.text.trim()},
                                      );
                                  if (context.mounted) {
                                    notice = context.tr(
                                      'A new code has been sent.',
                                      'Đã gửi mã mới.',
                                    );
                                  }
                                }),
                          child: Text(context.tr('Resend code', 'Gửi lại mã')),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? requiredValue(String? value) => value == null || value.trim().isEmpty
      ? context.tr('Required field.', 'Thông tin bắt buộc.')
      : null;
}
