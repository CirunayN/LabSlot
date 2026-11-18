import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class CustodianDeskTab extends ConsumerStatefulWidget {
  const CustodianDeskTab({super.key});

  @override
  ConsumerState<CustodianDeskTab> createState() => _CustodianDeskTabState();
}

class _CustodianDeskTabState extends ConsumerState<CustodianDeskTab> {
  final _searchCodeController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labSlotProvider);
    final timeFormat = DateFormat('h:mm a');

    final pendingList = state.pendingCheckInBookings.where((b) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return b.qrAuthCode.toLowerCase().contains(q) ||
          b.studentName.toLowerCase().contains(q) ||
          b.stationNumber.toLowerCase().contains(q);
    }).toList();

    final activeList = state.activeCheckedInBookings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Counter Search Bar (QR Reference Code / Student Name)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('custodian-qr-search-field'),
                      controller: _searchCodeController,
                      autofillHints: const [],
                      decoration: const InputDecoration(
                        labelText:
                            'Search Pending Check-In Queue',
                        hintText:
                            'Enter QR pass code, student name, or PC number (e.g., LS-4092-PC05)',
                        prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        _searchCodeController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 1: Pending Check-In Queue & Physical School ID Escrow
          Text(
            '1. Process Student Check-In & Physical ID Escrow (${pendingList.length} Pending)',
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inspect student Booking Pass within the 10-minute grace period, collect their physical school ID, and assign a desk tray bin.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          if (pendingList.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No pending reservations waiting for counter check-in.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            )
          else
            for (final b in pendingList)
              _PendingCheckInCard(booking: b, timeFormat: timeFormat),

          const SizedBox(height: 28),

          // Section 2: Active Sessions & Check-Out / Station Release
          Text(
            '2. Active Lab Sessions — Process Check-Out & Return ID (${activeList.length} Seated)',
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verify physical school ID return from the assigned tray bin and release the workstation back to Available.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          if (activeList.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No active checked-in workstation sessions right now.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            )
          else
            for (final b in activeList)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.reservedBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${b.stationNumber} • OCCUPIED',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppTheme.reservedRed,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                child: Text(
                                  'Physical ID Vault: ${b.idBinLocation ?? "Bin-01"}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${b.studentName} (${b.studentIdNumber})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${b.roomName} • Slot: ${timeFormat.format(b.scheduledStart)} – ${timeFormat.format(b.scheduledEnd)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        key: Key('checkout-button-${b.id}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.availableGreen,
                        ),
                        onPressed: () {
                          final res = ref
                              .read(labSlotProvider.notifier)
                              .processStudentCheckOut(b.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: res.success
                                  ? AppTheme.availableGreen
                                  : AppTheme.reservedRed,
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_returned_rounded),
                        label: Text(
                          'Return ID (${b.idBinLocation ?? "Bin"}) & Check Out',
                        ),
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

class _PendingCheckInCard extends ConsumerStatefulWidget {
  final Booking booking;
  final DateFormat timeFormat;

  const _PendingCheckInCard({
    required this.booking,
    required this.timeFormat,
  });

  @override
  ConsumerState<_PendingCheckInCard> createState() =>
      _PendingCheckInCardState();
}

class _PendingCheckInCardState extends ConsumerState<_PendingCheckInCard> {
  String _selectedBin = 'Bin-14';

  static final List<String> _trayBins = [
    for (int i = 1; i <= 25; i++) 'Bin-${i.toString().padLeft(2, '0')}',
  ];

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Pass Code: ${b.qrAuthCode}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppTheme.warningAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Grace Deadline: ${widget.timeFormat.format(b.gracePeriodDeadline)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${b.studentName} (${b.studentIdNumber})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${b.roomName} • Workstation ${b.stationNumber} (${b.durationHours} hr • ${b.courseworkTag})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 145,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBin,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'ID Tray Bin',
                    ),
                    items: [
                      for (final bin in _trayBins)
                        DropdownMenuItem(value: bin, child: Text(bin)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedBin = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  key: Key('checkin-button-${b.id}'),
                  onPressed: () {
                    final res = ref
                        .read(labSlotProvider.notifier)
                        .processStudentCheckIn(
                          bookingId: b.id,
                          idBinLocation: _selectedBin,
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
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: const Text('Confirm Check-In'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}