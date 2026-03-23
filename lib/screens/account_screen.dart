import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../services/session_service.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  final int userId;
  final String username;

  const AccountScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isDeletingAccount = false;
  bool _isNavigating = false;
  bool _isChangingPassword = false;

  Future<void> _goToLogin({String? infoMessage}) async {
    if (!mounted || _isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.of(context).clearSnackBars();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(infoMessage: infoMessage),
      ),
      (route) => false,
    );
  }

  Future<void> _changePassword() async {
    if (_isChangingPassword || _isNavigating || _isDeletingAccount) return;

    var oldPassword = '';
    var newPassword = '';
    var confirmPassword = '';
    String? oldPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đổi mật khẩu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        autofocus: true,
                        obscureText: true,
                        onChanged: (value) {
                          setDialogState(() {
                            oldPassword = value;
                            oldPasswordError = null;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu cũ',
                          hintText: 'Nhập mật khẩu cũ',
                          errorText: oldPasswordError,
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF34C759)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFDCEAD7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759), width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759)),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759), width: 2),
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        obscureText: true,
                        onChanged: (value) {
                          setDialogState(() {
                            newPassword = value;
                            newPasswordError = null;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          hintText: 'Ít nhất 4 ký tự',
                          errorText: newPasswordError,
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF34C759)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFDCEAD7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759), width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759)),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759), width: 2),
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFF34C759)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        obscureText: true,
                        onChanged: (value) {
                          setDialogState(() {
                            confirmPassword = value;
                            confirmPasswordError = null;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          hintText: 'Nhập lại mật khẩu mới',
                          errorText: confirmPasswordError,
                          prefixIcon: const Icon(Icons.verified_user_outlined, color: Color(0xFF34C759)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFDCEAD7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759), width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759)),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF34C759), width: 2),
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (oldPassword.isEmpty) {
                              setDialogState(() {
                                oldPasswordError = 'Vui lòng nhập mật khẩu cũ';
                              });
                              return;
                            }
                            if (newPassword.isEmpty) {
                              setDialogState(() {
                                newPasswordError = 'Vui lòng nhập mật khẩu mới';
                              });
                              return;
                            }
                            if (newPassword.length < 4) {
                              setDialogState(() {
                                newPasswordError = 'Mật khẩu phải ít nhất 4 ký tự';
                              });
                              return;
                            }
                            if (confirmPassword.isEmpty) {
                              setDialogState(() {
                                confirmPasswordError = 'Vui lòng xác nhận mật khẩu';
                              });
                              return;
                            }
                            if (newPassword != confirmPassword) {
                              setDialogState(() {
                                confirmPasswordError = 'Mật khẩu không trùng khớp';
                              });
                              return;
                            }
                            Navigator.of(dialogContext).pop(true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF34C759),
                          ),
                          child: const Text(
                            'Cập nhật',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isChangingPassword = true;
    });

    final user = await DatabaseHelper.instance.getUserById(widget.userId);
    if (!mounted) return;

    if (user == null || user.password != oldPassword) {
      setState(() {
        _isChangingPassword = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu cũ không chính xác')),
      );
      return;
    }

    final success = await DatabaseHelper.instance.updateUserPassword(
      widget.userId,
      newPassword,
    );
    if (!mounted) return;

    setState(() {
      _isChangingPassword = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể cập nhật mật khẩu. Vui lòng thử lại.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cập nhật mật khẩu thành công')),
    );
  }

  Future<void> _logout() async {
    if (_isNavigating || _isDeletingAccount || _isChangingPassword) return;

    await SessionService.clearSession();
    await _goToLogin();
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount || _isNavigating) return;

    final expectedText = 'delete ${widget.username}';
    var confirmText = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDelete = confirmText.trim() == expectedText;

            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xóa tài khoản',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Để xác nhận, nhập chính xác: $expectedText',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        onChanged: (value) {
                          setDialogState(() {
                            confirmText = value;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'delete username',
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canDelete
                              ? () => Navigator.of(dialogContext).pop(true)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF34C759),
                          ),
                          child: const Text('Xóa'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('Hủy'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeletingAccount = true;
    });

    final deletedRows = await DatabaseHelper.instance.deleteUser(widget.userId);
    if (!mounted) return;

    setState(() {
      _isDeletingAccount = false;
    });

    if (deletedRows <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa tài khoản. Vui lòng thử lại.')),
      );
      return;
    }

    await SessionService.clearSession();
    await _goToLogin(infoMessage: 'Đã xóa tài khoản thành công');
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isDanger = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          side: BorderSide(
            color: const Color(0xFF34C759),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: const Color(0xFF2D7D46),
          backgroundColor: Colors.white,
          alignment: Alignment.centerLeft,
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài khoản',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCEAD7)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFEFF8F1),
                    child: Icon(
                      Icons.person_outline,
                      color: Color(0xFF34C759),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.username,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _actionButton(
              label: 'Đổi mật khẩu',
              icon: Icons.lock_outline,
              onPressed: (_isDeletingAccount || _isNavigating || _isChangingPassword)
                  ? null
                  : _changePassword,
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: 'Xóa tài khoản',
              icon: Icons.delete_outline,
              isDanger: true,
              onPressed:
                  (_isDeletingAccount || _isNavigating || _isChangingPassword) ? null : _deleteAccount,
            ),
            if (_isDeletingAccount || _isChangingPassword) ...[
              const SizedBox(height: 10),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _actionButton(
              label: 'Đăng xuất',
              icon: Icons.logout_rounded,
              onPressed:
                  (_isDeletingAccount || _isNavigating || _isChangingPassword) ? null : _logout,
            ),
          ],
        ),
      ),
    );
  }
}
