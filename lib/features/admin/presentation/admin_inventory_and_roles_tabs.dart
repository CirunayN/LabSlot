import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class AdminInventoryTab extends ConsumerStatefulWidget {
  const AdminInventoryTab({super.key});

  @override
  ConsumerState<AdminInventoryTab> createState() => _AdminInventoryTabState();
}

class _AdminInventoryTabState extends ConsumerState<AdminInventoryTab> {
  final _roomCodeController = TextEditingController();
  final _roomNameController = TextEditingController();
  final _roomFloorController = TextEditingController();
  final _roomCapacityController = TextEditingController();

  final _pcNumberController = TextEditingController();
  final _pcCpuController = TextEditingController();
  final _pcGpuController = TextEditingController();
  int _selectedRamGb = 32;
  final Set<String> _selectedSoftware = {'Flutter', 'Android Studio', 'VS Code'};

  @override
  void dispose() {
    _roomCodeController.dispose();
    _roomNameController.dispose();
    _roomFloorController.dispose();
    _roomCapacityController.dispose();
    _pcNumberController.dispose();
    _pcCpuController.dispose();
    _pcGpuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labSlotProvider);
    final controller = ref.read(labSlotProvider.notifier);
    final selectedRoom = state.selectedRoom;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              // Card 1: Create New Laboratory Room
              SizedBox(
                width: 460,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Add New Campus Laboratory Room',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('admin-room-code-field'),
                                controller: _roomCodeController,
                                autofillHints: const [],
                                decoration: const InputDecoration(
                                  labelText: 'Room Code',
                                  hintText: 'e.g., COMLAB-5',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 130,
                              child: TextField(
                                key: const Key('admin-room-capacity-field'),
                                controller: _roomCapacityController,
                                keyboardType: TextInputType.number,
                                autofillHints: const [],
                                decoration: const InputDecoration(
                                  labelText: 'PC Capacity',
                                  hintText: '1–60 (e.g., 10)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const Key('admin-room-name-field'),
                          controller: _roomNameController,
                          autofillHints: const [],
                          decoration: const InputDecoration(
                            labelText: 'Room Title',
                            hintText:
                                'Enter room name (e.g., ComLab 5 – AI & Data Science)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _roomFloorController,
                          autofillHints: const [],
                          decoration: const InputDecoration(
                            labelText: 'Building & Floor Location',
                            hintText:
                                'Enter floor & building (e.g., 4th Floor, IT Building)',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: const Key('admin-create-room-button'),
                            onPressed: () {
                              final cap = int.tryParse(
                                    _roomCapacityController.text.trim(),
                                  ) ??
                                  0;
                              final res = controller.addLabRoom(
                                code: _roomCodeController.text,
                                name: _roomNameController.text,
                                buildingFloor: _roomFloorController.text,
                                initialStationsCount: cap,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success
                                      ? AppTheme.availableGreen
                                      : AppTheme.reservedRed,
                                ),
                              );
                              if (res.success) {
                                _roomCodeController.clear();
                                _roomNameController.clear();
                                _roomFloorController.clear();
                                _roomCapacityController.clear();
                              }
                            },
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text(
                              'Validate Capacity & Create Laboratory Room',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Card 2: Configure PC Hardware Specs & Software Tags
              SizedBox(
                width: 480,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Configure PC Station Hardware & Software Tags',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedRoom.id,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Target Laboratory',
                                ),
                                items: [
                                  for (final r in state.rooms)
                                    DropdownMenuItem(
                                      value: r.id,
                                      child: Text(
                                        r.code,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) controller.selectRoom(v);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 130,
                              child: TextField(
                                key: const Key('admin-pc-number-field'),
                                controller: _pcNumberController,
                                autofillHints: const [],
                                decoration: const InputDecoration(
                                  labelText: 'Station ID',
                                  hintText: 'e.g., PC-13',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _pcCpuController,
                                autofillHints: const [],
                                decoration: const InputDecoration(
                                  labelText: 'CPU Model',
                                  hintText: 'e.g., Intel Core i7-13700',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 130,
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedRamGb,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'RAM (GB)',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 16,
                                    child: Text('16 GB'),
                                  ),
                                  DropdownMenuItem(
                                    value: 32,
                                    child: Text('32 GB'),
                                  ),
                                  DropdownMenuItem(
                                    value: 64,
                                    child: Text('64 GB'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedRamGb = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pcGpuController,
                          autofillHints: const [],
                          decoration: const InputDecoration(
                            labelText: 'GPU Specification',
                            hintText: 'Enter GPU model (e.g., NVIDIA RTX 3060 12GB)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in LabSlotController.allSoftwareTags)
                              FilterChip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                selected: _selectedSoftware.contains(tag),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSoftware.add(tag);
                                    } else {
                                      _selectedSoftware.remove(tag);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: const Key('admin-save-pc-button'),
                            onPressed: () {
                              final res = controller.addOrUpdatePcStation(
                                roomId: selectedRoom.id,
                                stationNumber: _pcNumberController.text,
                                cpu: _pcCpuController.text,
                                ramGb: _selectedRamGb,
                                gpu: _pcGpuController.text,
                                installedSoftware: _selectedSoftware.toList(),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success
                                      ? AppTheme.availableGreen
                                      : AppTheme.reservedRed,
                                ),
                              );
                            },
                            icon: const Icon(Icons.save_rounded),
                            label: const Text(
                              'Save / Update Workstation Specs & Tags',
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
        ],
      ),
    );
  }
}

class AdminRolesAndStrikesTab extends ConsumerWidget {
  const AdminRolesAndStrikesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labSlotProvider);
    final controller = ref.read(labSlotProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage User Roles (RBAC) & Fair-Use 3-Strike Suspensions',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Assign system roles (Student, Laboratory Custodian, System Administrator) and enforce or reset 3-strike no-show booking suspensions.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          for (final u in state.users)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              u.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (u.isSuspended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.reservedBg,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'SUSPENDED (3+ Strikes)',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.reservedRed,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${u.email} • ID: ${u.studentIdNumber} • ${u.courseDepartment}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Text(
                          'No-Show Strikes: ${u.strikeCount} / 3',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: u.isSuspended
                                ? AppTheme.reservedRed
                                : AppTheme.availableGreen,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 215,
                          child: DropdownButtonFormField<UserRole>(
                            initialValue: u.role,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'RBAC Role',
                            ),
                            items: [
                              for (final role in UserRole.values)
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    role.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                            ],
                            onChanged: (newRole) {
                              if (newRole != null) {
                                final res = controller.updateUserRole(
                                  u.id,
                                  newRole,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.message)),
                                );
                              }
                            },
                          ),
                        ),
                        OutlinedButton.icon(
                          key: Key('reset-strikes-${u.id}'),
                          onPressed: () {
                            final res = controller
                                .resetOrAdjustStudentStrikes(u.id, 0);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message)),
                            );
                          },
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          label: const Text('Reset Strikes (0)'),
                        ),
                        OutlinedButton.icon(
                          key: Key('enforce-suspension-${u.id}'),
                          onPressed: () {
                            final res = controller
                                .resetOrAdjustStudentStrikes(u.id, 3);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message)),
                            );
                          },
                          icon: const Icon(
                            Icons.gavel_rounded,
                            size: 18,
                            color: AppTheme.reservedRed,
                          ),
                          label: const Text('Set 3 Strikes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}