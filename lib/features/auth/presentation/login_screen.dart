import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _departmentController = TextEditingController();

  UserRole _selectedSignUpRole = UserRole.student;
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _studentIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthAction() async {
    setState(() => _isLoading = true);
    final controller = ref.read(labSlotProvider.notifier);

    final ActionResult res;
    if (_isSignUpMode) {
      res = await controller.signUpWithCredentials(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _fullNameController.text,
        studentIdNumber: _selectedSignUpRole == UserRole.student
            ? _studentIdController.text
            : null,
        courseDepartment: _departmentController.text,
        role: _selectedSignUpRole,
      );
    } else {
      res = await controller.signInWithCredentials(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor:
            res.success ? AppTheme.availableGreen : AppTheme.reservedRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isPhone ? 14 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(isPhone ? 18 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.computer_rounded,
                            color: AppTheme.primaryBlue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LabSlot',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Campus Computer Laboratory Booking System',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Sign In'),
                            icon: Icon(Icons.login_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Create Account'),
                            icon: Icon(Icons.person_add_alt_1_rounded, size: 16),
                          ),
                        ],
                        selected: {_isSignUpMode},
                        onSelectionChanged: (selection) {
                          setState(() => _isSignUpMode = selection.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isSignUpMode) ...[
                      DropdownButtonFormField<UserRole>(
                        key: const Key('signup-role-dropdown'),
                        initialValue: _selectedSignUpRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Account Role',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        items: [
                          for (final r in UserRole.values)
                            DropdownMenuItem(
                              value: r,
                              child: Text(
                                r.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedSignUpRole = v);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('signup-fullname-field'),
                        controller: _fullNameController,
                        autofillHints: const [],
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_selectedSignUpRole == UserRole.student) ...[
                        TextField(
                          key: const Key('signup-id-field'),
                          controller: _studentIdController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofillHints: const [],
                          decoration: const InputDecoration(
                            labelText: 'Student ID (6 Digits)',
                            hintText: 'Enter 6-digit student ID (e.g., 123456)',
                            prefixIcon: Icon(Icons.badge_outlined),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        key: const Key('signup-department-field'),
                        controller: _departmentController,
                        autofillHints: const [],
                        decoration: InputDecoration(
                          labelText: _selectedSignUpRole == UserRole.student
                              ? 'Course / Department'
                              : 'Department / Office',
                          hintText: _selectedSignUpRole == UserRole.student
                              ? 'Enter degree program (e.g., BSIT - 3rd Year)'
                              : 'Enter office or unit (e.g., Laboratory Services)',
                          prefixIcon: const Icon(Icons.school_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('signup-email-field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [],
                        decoration: const InputDecoration(
                          labelText: 'Campus Email Address',
                          hintText: 'Enter your campus email address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        key: const Key('login-email-field'),
                        controller: _identifierController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [],
                        decoration: const InputDecoration(
                          labelText: 'Email or 6-Digit Student ID',
                          hintText: 'Enter campus email or 6-digit student ID',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('login-password-field'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [],
                      onSubmitted: (_) {
                        if (!_isLoading) _handleAuthAction();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: _isSignUpMode
                            ? 'Create a password (min. 6 characters)'
                            : 'Enter your account password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('sign-in-button'),
                        onPressed: _isLoading ? null : _handleAuthAction,
                        icon: Icon(
                          _isSignUpMode
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                        ),
                        label: Text(
                          _isLoading
                              ? 'Processing...'
                              : (_isSignUpMode
                                  ? 'Create Account'
                                  : 'Sign In to LabSlot'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
