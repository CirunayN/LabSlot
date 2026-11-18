import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class StudentLabsTab extends ConsumerWidget {
  final VoidCallback onBookedNavigateToPass;

  const StudentLabsTab({super.key, required this.onBookedNavigateToPass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labSlotProvider);
    final controller = ref.read(labSlotProvider.notifier);
    final selectedRoom = state.selectedRoom;
    final filteredStations = state.stationsForRoom(selectedRoom.id);
    final allRoomStations = state.stationsForRoom(
      selectedRoom.id,
      applyFilters: false,
    );

    final availableCount = allRoomStations
        .where((s) => s.status == PcStatus.available)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fair-use strike warning banner if user has strikes
          if ((state.currentUser?.strikeCount ?? 0) > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (state.currentUser?.isSuspended ?? false)
                    ? AppTheme.reservedBg
                    : AppTheme.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (state.currentUser?.isSuspended ?? false)
                      ? AppTheme.reservedRed
                      : AppTheme.warningAmber,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: (state.currentUser?.isSuspended ?? false)
                        ? AppTheme.reservedRed
                        : AppTheme.warningAmber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (state.currentUser?.isSuspended ?? false)
                          ? 'Fair-Use Restriction Active: You have ${state.currentUser?.strikeCount} unexcused no-show strikes. Advance slot reservations are blocked until reset by an Administrator.'
                          : 'Fair-Use Notice: You have ${state.currentUser?.strikeCount}/3 no-show strikes. Please check in within the 10-minute grace period.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Section 1: Live Laboratory Rooms Selector
          const Text(
            '1. Campus Computer Laboratories (Live Status)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 125,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.rooms.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final room = state.rooms[index];
                final isSelected = room.id == selectedRoom.id;
                final roomStations = state.stationsForRoom(
                  room.id,
                  applyFilters: false,
                );
                final freeCount = roomStations
                    .where((s) => s.status == PcStatus.available)
                    .length;

                return InkWell(
                  key: Key('room-card-${room.code}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => controller.selectRoom(room.id),
                  child: Container(
                    width: 265,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                room.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(child: _buildRoomStatusBadge(room.status)),
                          ],
                        ),
                        Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                room.buildingFloor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              room.status == RoomStatus.open
                                  ? '$freeCount/${roomStations.length} Free'
                                  : room.status.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: room.status == RoomStatus.open
                                    ? AppTheme.availableGreen
                                    : AppTheme.maintenanceSlate,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: Coursework Toolchain & Hardware Spec Filter
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          '2. Filter PCs by Coursework Software & Hardware Specs',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      if (state.selectedSoftwareFilters.isNotEmpty ||
                          state.minimumRamFilterGb > 0 ||
                          state.onlyAvailableFilter)
                        TextButton.icon(
                          onPressed: controller.clearAllFilters,
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text('Reset Filters'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in LabSlotController.allSoftwareTags)
                        FilterChip(
                          key: Key('filter-chip-$tag'),
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: state.selectedSoftwareFilters.contains(tag),
                          onSelected: (_) =>
                              controller.toggleSoftwareFilter(tag),
                        ),
                      FilterChip(
                        label: const Text(
                          '32GB RAM Only',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: state.minimumRamFilterGb == 32,
                        onSelected: (v) =>
                            controller.setMinimumRamFilter(v ? 32 : 0),
                      ),
                      FilterChip(
                        label: const Text(
                          'Available Only',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: state.onlyAvailableFilter,
                        onSelected: controller.toggleOnlyAvailableFilter,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Section 3: Interactive Visual PC Station Grid
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '3. ${selectedRoom.name} — Interactive Workstation Grid',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${selectedRoom.currentSubjectNote} • $availableCount available out of ${allRoomStations.length} stations',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              _buildLegendRow(),
            ],
          ),
          const SizedBox(height: 12),

          if (filteredStations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    'No PC stations match the selected coursework software / RAM filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 235,
                mainAxisExtent: MediaQuery.sizeOf(context).width < 600 ? 174 : 158,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: filteredStations.length,
              itemBuilder: (context, index) {
                final pc = filteredStations[index];
                return _PcStationCard(
                  station: pc,
                  room: selectedRoom,
                  onTapBook: () =>
                      _showBookingOrDefectModal(context, ref, selectedRoom, pc),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRoomStatusBadge(RoomStatus status) {
    final Color bg;
    final Color fg;
    switch (status) {
      case RoomStatus.open:
        bg = AppTheme.availableBg;
        fg = AppTheme.availableGreen;
      case RoomStatus.classInSession:
        bg = AppTheme.warningBg;
        fg = AppTheme.warningAmber;
      case RoomStatus.closed:
        bg = AppTheme.maintenanceBg;
        fg = AppTheme.maintenanceSlate;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildLegendRow() {
    return Wrap(
      spacing: 12,
      children: [
        _legendDot(AppTheme.availableGreen, 'Available'),
        _legendDot(AppTheme.warningAmber, 'Reserved'),
        _legendDot(AppTheme.reservedRed, 'Occupied'),
        _legendDot(AppTheme.maintenanceSlate, 'Maintenance'),
      ],
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }

  void _showBookingOrDefectModal(
    BuildContext context,
    WidgetRef ref,
    LabRoom room,
    PcStation station,
  ) {
    int selectedDuration = 1;
    String selectedCoursework = station.installedSoftware.isNotEmpty
        ? station.installedSoftware.first
        : 'Flutter';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isPhone = MediaQuery.sizeOf(ctx).width < 520;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${room.code} • ${station.stationNumber}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            station.status.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Specs: ${station.cpu} • ${station.ramGb}GB RAM • ${station.gpu}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final sw in station.installedSoftware)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sw,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (station.status == PcStatus.available &&
                        room.status == RoomStatus.open) ...[
                      const Text(
                        'Process PC Station Slot Reservation (1–2 Hours)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isPhone) ...[
                        DropdownButtonFormField<int>(
                          initialValue: selectedDuration,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Slot Duration',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 1,
                              child: Text('1 Hour Slot'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('2 Hours Slot (Max)'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedDuration = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCoursework,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Primary Coursework Tool',
                          ),
                          items: [
                            for (final sw in station.installedSoftware)
                              DropdownMenuItem(value: sw, child: Text(sw)),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedCoursework = v);
                            }
                          },
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: selectedDuration,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Slot Duration',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text(
                                      '1 Hour Slot',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text(
                                      '2 Hours Slot (Max)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => selectedDuration = v);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCoursework,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Primary Coursework Tool',
                                ),
                                items: [
                                  for (final sw in station.installedSoftware)
                                    DropdownMenuItem(
                                      value: sw,
                                      child: Text(
                                        sw,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => selectedCoursework = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('confirm-booking-button'),
                          onPressed: () {
                            final res = ref
                                .read(labSlotProvider.notifier)
                                .reservePcStationSlot(
                                  stationId: station.id,
                                  durationHours: selectedDuration,
                                  courseworkTag: selectedCoursework,
                                );
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success
                                    ? AppTheme.availableGreen
                                    : AppTheme.reservedRed,
                              ),
                            );
                            if (res.success) {
                              onBookedNavigateToPass();
                            }
                          },
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text(
                            'Confirm Reservation & Generate Pass',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!station.isDefective)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('open-defect-report-button'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showDefectReportDialog(context, ref, station);
                          },
                          icon: const Icon(
                            Icons.report_problem_outlined,
                            color: AppTheme.warningAmber,
                          ),
                          label: const Text(
                            'Report Defective Hardware / Quarantine PC',
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.maintenanceBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Quarantined Under Maintenance: ${station.defectCategory ?? 'Hardware Defect'} — ${station.defectNotes ?? ''}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDefectReportDialog(
    BuildContext context,
    WidgetRef ref,
    PcStation station,
  ) {
    String selectedCategory = 'Broken Mouse / Peripheral';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Report Defective PC (${station.stationNumber})'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hardware / Software Issue Category',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Broken Mouse / Peripheral',
                          child: Text(
                            'Broken Mouse / Keyboard Peripheral',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'No Network / Internet',
                          child: Text(
                            'No Network / Internet Connection',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Missing Required IDE / Software',
                          child: Text(
                            'Missing Required Coursework IDE',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Monitor / Boot Failure',
                          child: Text(
                            'Monitor Blank / System Boot Failure',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedCategory = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('defect-description-field'),
                      controller: notesController,
                      maxLines: 3,
                      autofillHints: const [],
                      decoration: const InputDecoration(
                        labelText: 'Issue Description',
                        hintText: 'Describe the broken hardware or missing coursework software...',
                      ),
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('submit-defect-button'),
                  onPressed: () {
                    final res = ref
                        .read(labSlotProvider.notifier)
                        .reportDefectivePcStation(
                          stationId: station.id,
                          issueCategory: selectedCategory,
                          description: notesController.text,
                        );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        backgroundColor: res.success
                            ? AppTheme.availableGreen
                            : AppTheme.reservedRed,
                      ),
                    );
                  },
                  child: const Text('Submit & Quarantine PC'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PcStationCard extends StatelessWidget {
  final PcStation station;
  final LabRoom room;
  final VoidCallback onTapBook;

  const _PcStationCard({
    required this.station,
    required this.room,
    required this.onTapBook,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color badgeBg;
    final Color badgeFg;

    switch (station.status) {
      case PcStatus.available:
        borderColor = AppTheme.availableGreen;
        badgeBg = AppTheme.availableBg;
        badgeFg = AppTheme.availableGreen;
      case PcStatus.reserved:
        borderColor = AppTheme.warningAmber;
        badgeBg = AppTheme.warningBg;
        badgeFg = AppTheme.warningAmber;
      case PcStatus.occupied:
        borderColor = AppTheme.reservedRed;
        badgeBg = AppTheme.reservedBg;
        badgeFg = AppTheme.reservedRed;
      case PcStatus.maintenance:
        borderColor = AppTheme.maintenanceSlate;
        badgeBg = AppTheme.maintenanceBg;
        badgeFg = AppTheme.maintenanceSlate;
    }

    return InkWell(
      key: Key('station-card-${station.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTapBook,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.desktop_windows_rounded,
                      size: 16,
                      color: borderColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      station.stationNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      station.status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${station.ramGb}GB RAM • ${station.gpu}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final sw in station.installedSoftware.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sw,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
