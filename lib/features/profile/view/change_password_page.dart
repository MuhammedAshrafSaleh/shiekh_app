// lib/features/profile/view/change_password_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sheikhy_button.dart';
import '../../../core/widgets/sheikhy_page_header.dart';
import '../../../core/widgets/sheikhy_password_field.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  String? _errorCurrent;
  String? _errorNew;
  String? _errorConfirm;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    String? ec;
    String? en;
    String? ef;

    if (_currentPwCtrl.text.isEmpty) {
      ec = 'أدخل كلمة المرور الحالية';
    }
    if (_newPwCtrl.text.length < 6) {
      en = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (_confirmPwCtrl.text != _newPwCtrl.text) {
      ef = 'كلمتا المرور غير متطابقتين';
    }

    setState(() {
      _errorCurrent = ec;
      _errorNew = en;
      _errorConfirm = ef;
    });

    return ec == null && en == null && ef == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final success = await context.read<ProfileCubit>().changePassword(
          currentPassword: _currentPwCtrl.text,
          newPassword: _newPwCtrl.text,
        );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'تم تغيير كلمة المرور بنجاح' : 'فشل تغيير كلمة المرور',
        ),
        backgroundColor: success ? AppColors.primary : AppColors.danger,
        duration: Duration(seconds: success ? 3 : 4),
      ),
    );
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheikhyPageHeader(title: 'تغيير كلمة المرور', showBack: true),
          Expanded(
            child: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final isUpdating = state is ProfileUpdating;
                return SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.pageGutter,
                    AppSpacing.s6,
                    AppSpacing.pageGutter,
                    AppSpacing.s9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hint text
                      Text(
                        'أدخل كلمة مرورك الحالية ثم اختر كلمة مرور جديدة.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.inkMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s6),

                      SheikhyPasswordField(
                        label: 'كلمة المرور الحالية',
                        controller: _currentPwCtrl,
                        hintText: '••••••••',
                        errorText: _errorCurrent,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_errorCurrent != null) {
                            setState(() => _errorCurrent = null);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s5),

                      SheikhyPasswordField(
                        label: 'كلمة المرور الجديدة',
                        controller: _newPwCtrl,
                        hintText: '••••••••',
                        errorText: _errorNew,
                        prefixIcon: const Icon(Icons.lock_reset),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_errorNew != null) {
                            setState(() => _errorNew = null);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s5),

                      SheikhyPasswordField(
                        label: 'تأكيد كلمة المرور الجديدة',
                        controller: _confirmPwCtrl,
                        hintText: '••••••••',
                        errorText: _errorConfirm,
                        prefixIcon: const Icon(Icons.lock_reset),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_errorConfirm != null) {
                            setState(() => _errorConfirm = null);
                          }
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.s7),

                      SheikhyButton.primary(
                        label: 'حفظ كلمة المرور',
                        isLoading: isUpdating,
                        onPressed: isUpdating ? null : _submit,
                        fullWidth: true,
                      ),
                      SizedBox(
                        height: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
