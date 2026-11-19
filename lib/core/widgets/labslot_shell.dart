import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/presentation/admin_inventory_and_roles_tabs.dart';
import '../../features/admin/presentation/admin_reports_tab.dart';
import '../../features/custodian/presentation/custodian_desk_tab.dart';
import '../../features/custodian/presentation/custodian_operations_tabs.dart';
import '../../features/student/presentation/student_labs_tab.dart';
import '../../features/student/presentation/student_pass_and_chat_tabs.dart';
import '../models/labslot_models.dart';
import '../providers/labslot_controller.dart';
import '../theme/app_theme.dart';

class LabSlotShell extends ConsumerStatefulWidget {
  const LabSlotShell({super.key});

  @override
  ConsumerState<LabSlotShell> createState() => _LabSlotShellState();
}

class _LabSlotShellState extends ConsumerState<LabSlotShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labSlotProvider);
    final controller = ref.read(labSlotProvider.notifier);
    final user = state.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final navItems = _buildNavItemsForRole(user.role, state);
    final safeIndex = _selectedIndex >= navItems.length ? 0 : _selectedIndex;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.desktop_windows_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LabSlot',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('actor-switcher-menu'),
            tooltip: 'Switch Account (Testing)',
            icon: const Icon(Icons.switch_account_rounded),
            onSelected: (userId) {
              setState(() => _selectedIndex = 0);
              controller.switchActiveAccount(userId);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  'REGISTERED ACCOUNTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              ...state.users.map(
                (u) => PopupMenuItem<String>(
                  value: u.id,
                  child: Row(
                    children: [
                      Icon(
                        u.id == user.id
                            ? Icons.radio_button_checked
                            : Icons.person_outline,
                        size: 18,
                        color: _roleColor(u.role),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.fullName,
                              style: TextStyle(
                                fontWeight: u.id == user.id
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              u.role == UserRole.student
                                  ? '${u.role.label} • ID: ${u.studentIdNumber ?? "N/A"} • Strikes: ${u.strikeCount}/3'
                                  : u.role.label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            key: const Key('sign-out-button'),
            tooltip: 'Sign Out',
            onPressed: () {
              setState(() => _selectedIndex = 0);
              controller.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: safeIndex,
        children: navItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (idx) {
          ScaffoldMessenger.of(context).clearSnackBars();
          setState(() => _selectedIndex = idx);
        },
        destinations: navItems
            .map(
              (item) => NavigationDestination(
                icon: Badge(
                  isLabelVisible: item.badgeCount > 0,
                  label: Text('${item.badgeCount}'),
                  child: Icon(item.icon),
                ),
                selectedIcon: Badge(
                  isLabelVisible: item.badgeCount > 0,
                  label: Text('${item.badgeCount}'),
                  child: Icon(item.selectedIcon, color: AppTheme.primaryBlue),
                ),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  List<_RoleNavItem> _buildNavItemsForRole(
    UserRole role,
    LabSlotState state,
  ) {
    switch (role) {
      case UserRole.student:
        final hasActivePass = state.activeBookingForCurrentUser != null;
        return [
          _RoleNavItem(
            label: 'Labs',
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view_rounded,
            page: StudentLabsTab(
              onBookedNavigateToPass: () => setState(() => _selectedIndex = 1),
            ),
          ),
          _RoleNavItem(
            label: 'Booking Pass',
            icon: Icons.qr_code_2_outlined,
            selectedIcon: Icons.qr_code_2_rounded,
            badgeCount: hasActivePass ? 1 : 0,
            page: const StudentBookingPassTab(),
          ),
          const _RoleNavItem(
            label: 'Help Chat',
            icon: Icons.support_agent_outlined,
            selectedIcon: Icons.support_agent_rounded,
            page: StudentHelpDeskChatTab(),
          ),
        ];

      case UserRole.custodian:
        final pendingQueueCount = state.pendingCheckInBookings.length;
        final openTicketsCount = state.maintenanceTickets
            .where((t) => !t.isResolved)
            .length;
        final unresolvedThreadsCount = state.chatMessages
            .where((m) => !m.isResolved)
            .map((m) => m.studentId)
            .toSet()
            .length;

        return [
          _RoleNavItem(
            label: 'Check-In',
            icon: Icons.badge_outlined,
            selectedIcon: Icons.badge_rounded,
            badgeCount: pendingQueueCount,
            page: const CustodianDeskTab(),
          ),
          _RoleNavItem(
            label: 'Maintenance',
            icon: Icons.build_circle_outlined,
            selectedIcon: Icons.build_circle_rounded,
            badgeCount: openTicketsCount,
            page: const CustodianRoomsAndMaintenanceTab(),
          ),
          _RoleNavItem(
            label: 'Help Inbox',
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum_rounded,
            badgeCount: unresolvedThreadsCount,
            page: const CustodianHelpDeskInboxTab(),
          ),
        ];

      case UserRole.admin:
        final flaggedStudents = state.users
            .where((u) => u.role == UserRole.student && u.isSuspended)
            .length;
        return [
          const _RoleNavItem(
            label: 'Lab Inventory',
            icon: Icons.devices_outlined,
            selectedIcon: Icons.devices_rounded,
            page: AdminInventoryTab(),
          ),
          _RoleNavItem(
            label: 'Users',
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings_rounded,
            badgeCount: flaggedStudents,
            page: const AdminRolesAndStrikesTab(),
          ),
          const _RoleNavItem(
            label: 'CHED Reports',
            icon: Icons.analytics_outlined,
            selectedIcon: Icons.analytics_rounded,
            page: AdminAccreditationReportsTab(),
          ),
        ];
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return AppTheme.primaryBlue;
      case UserRole.custodian:
        return AppTheme.availableGreen;
      case UserRole.admin:
        return AppTheme.primaryIndigo;
    }
  }
}

class _RoleNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final int badgeCount;

  const _RoleNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.badgeCount = 0,
  });
}
