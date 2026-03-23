import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/user.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final isTaken = await DatabaseHelper.instance.isUsernameTaken(username);
    if (!mounted) return;

    if (isTaken) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tên tài khoản đã tồn tại')));
      return;
    }

    final user = UserModel(
      username: username,
      email: email,
      password: password,
      createdAt: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.registerUser(user);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đăng ký thành công. Vui lòng đăng nhập.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: Color(0xFF34C759),
                      width: 1.5,
                    ),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Color(0xFF1F2937),
                              ),
                              tooltip: 'Quay lại',
                            ),
                          ),
                          Text(
                            'Tạo tài khoản',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF1F2937),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bắt đầu quản lý chi tiêu cá nhân ngay hôm nay',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AppInput(
                            controller: _usernameController,
                            label: 'Tên tài khoản',
                            hint: 'Chọn tên tài khoản',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Tên tài khoản là bắt buộc';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          AppInput(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'abc@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email là bắt buộc';
                              }
                              if (!value.contains('@')) {
                                return 'Email không hợp lệ';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          AppInput(
                            controller: _passwordController,
                            label: 'Mật khẩu',
                            hint: 'Ít nhất 4 ký tự',
                            icon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Mật khẩu là bắt buộc';
                              }
                              if (value.length < 4) {
                                return 'Mật khẩu phải ít nhất 4 ký tự';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          AppInput(
                            controller: _confirmPasswordController,
                            label: 'Xác nhận mật khẩu',
                            hint: 'Nhập lại mật khẩu',
                            icon: Icons.verified_user_outlined,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _register(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng xác nhận mật khẩu';
                              }
                              if (value != _passwordController.text) {
                                return 'Mật khẩu không trùng khớp';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          AppButton(
                            text: 'Đăng ký',
                            icon: Icons.person_add_alt_1,
                            onPressed: _register,
                            isLoading: _isSubmitting,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
