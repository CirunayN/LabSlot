import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(
    text: 'marco.santos@campus.edu.ph',
  );
  final _passwordController = TextEditingController(text: 'password123');
  final _fullNameController = TextEditingController(text: 'Marco Santos');
  final _idNumberController = TextEditingController(text: '2024-01042');
  final _departmentController = TextEditingController(
    text: 'BS Information Technology (3rd Year)',
  );

  UserRole _selectedSignUpRole = UserRole.student;
  bool _isSignUpMode = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _idNumberController.dispose();
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
        studentIdNumber: _idNumberController.text,
        courseDepartment: _departmentController.text,
        role: _selectedSignUpRole,
      );
    } else {
      res = await controller.signInWithCredentials(
        email: _emailController.text,
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
    final state = ref.watch(labSlotProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                // Left Card: Credentials Sign-In / Sign-Up
                SizedBox(
                  width: 420,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.1,
                                  ),
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
                                      'Campus Computer Lab & PC Booking System',
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
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: SupabaseConfig.isLiveConnected
                                  ? AppTheme.availableBg
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  SupabaseConfig.isLiveConnected
                                      ? Icons.cloud_done_rounded
                                      : Icons.bolt_rounded,
                                  size: 16,
                                  color: SupabaseConfig.isLiveConnected
                                      ? AppTheme.availableGreen
                                      : AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  SupabaseConfig.isLiveConnected
                                      ? 'Connected to Live Supabase Cloud'
                                      : 'Interactive RBAC Sandbox Ready',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SegmentedButton<bool>(
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
                          const SizedBox(height: 18),
                          if (_isSignUpMode) ...[
                            const Text(
                              'Full Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                hintText: 'Marco Santos',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _idNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'School / Staff ID',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<UserRole>(
                                    initialValue: _selectedSignUpRole,
                                    decoration: const InputDecoration(
                                      labelText: 'RBAC Role',
                                    ),
                                    items: [
                                      for (final r in UserRole.values)
                                        DropdownMenuItem(
                                          value: r,
                                          child: Text(
                                            r.label,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedSignUpRole = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _departmentController,
                              decoration: const InputDecoration(
                                labelText: 'Course / Department',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const Text(
                            'Campus Email Address',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('login-email-field'),
                            controller: _emailController,
                            decoration: const InputDecoration(
                              hintText: 'student@campus.edu.ph',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('login-password-field'),
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_outline),
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
                                        ? 'Register & Sign In'
                                        : 'Sign In to LabSlot'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Right Card: Quick Actor Switcher (Matches 3 Actors in Use Case Diagram)
                SizedBox(
                  width: 440,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Actor Switcher (RBAC Testing)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Select any of the 3 system actors below to test their exact Use Case modules immediately:',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final u in state.users)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                key: Key('quick-login-${u.id}'),
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  ref
                                      .read(labSlotProvider.notifier)
                                      .loginAsDemoUser(u.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            _roleColor(u.role).withValues(
                                          alpha: 0.14,
                                        ),
                                        child: Icon(
                                          _roleIcon(u.role),
                                          color: _roleColor(u.role),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u.fullName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            Text(
                                              '${u.role.label} • ${u.studentIdNumber}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            if (u.role == UserRole.student)
                                              Text(
                                                u.isSuspended
                                                    ? '3 Strikes (Booking Suspended — Test Error Case)'
                                                    : '${u.strikeCount} Strikes (Eligible to Book)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: u.isSuspended
                                                      ? AppTheme.reservedRed
                                                      : AppTheme.availableGreen,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 15,
                                        color: Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return AppTheme.primaryBlue;
      case UserRole.custodian:
        return AppTheme.availableGreen;
      case UserRole.admin:
        return const Color(0xFF7C3AED);
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school_rounded;
      case UserRole.custodian:
        return Icons.badge_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }
}
