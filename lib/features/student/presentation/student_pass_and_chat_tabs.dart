import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class StudentBookingPassTab extends ConsumerWidget {
  const StudentBookingPassTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labSlotProvider);
    final controller = ref.read(labSlotProvider.notifier);
    final activeBooking = state.activeBookingForCurrentUser;
    final userHistory = state.bookings
        .where((b) => b.studentId == state.currentUser?.id)
        .toList();
    final timeFormat = DateFormat('h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Digital Booking Pass & Grace Period',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (activeBooking == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No Active Booking Pass',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Select an available green PC station on the Live Labs grid to generate a 1-to-2-hour Booking Pass.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeBooking.roomName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Workstation ${activeBooking.stationNumber} • Coursework: ${activeBooking.courseworkTag}',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: activeBooking.status ==
                                        BookingStatus.checkedIn
                                    ? AppTheme.availableBg
                                    : AppTheme.warningBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activeBooking.status.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: activeBooking.status ==
                                          BookingStatus.checkedIn
                                      ? AppTheme.availableGreen
                                      : AppTheme.warningAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        Wrap(
                          spacing: 28,
                          runSpacing: 20,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: QrImageView(
                                data: activeBooking.qrAuthCode,
                                size: 150,
                              ),
                            ),
                            SizedBox(
                              width: 340,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _passDetailRow(
                                    'Booking Reference Code',
                                    activeBooking.qrAuthCode,
                                  ),
                                  _passDetailRow(
                                    'Student Name & ID',
                                    '${activeBooking.studentName} (${activeBooking.studentIdNumber})',
                                  ),
                                  _passDetailRow(
                                    'Reserved Slot Window',
                                    '${timeFormat.format(activeBooking.scheduledStart)} – ${timeFormat.format(activeBooking.scheduledEnd)} (${activeBooking.durationHours} hr)',
                                  ),
                                  _passDetailRow(
                                    activeBooking.status ==
                                            BookingStatus.checkedIn
                                        ? 'Physical School ID Vault'
                                        : '10-Min Check-In Grace Deadline',
                                    activeBooking.status ==
                                            BookingStatus.checkedIn
                                        ? 'Held in Custodian ${activeBooking.idBinLocation ?? "Tray"}'
                                        : 'Must check in by ${timeFormat.format(activeBooking.gracePeriodDeadline)}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (activeBooking.status == BookingStatus.reserved) ...[
                          const Divider(height: 28),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                key: const Key('cancel-booking-button'),
                                onPressed: () {
                                  final res = controller.cancelPendingBooking(
                                    activeBooking.id,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
                                  );
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel Pending Reservation'),
                              ),
                              ElevatedButton.icon(
                                key: const Key('simulate-grace-expiry-button'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.warningAmber,
                                ),
                                onPressed: () {
                                  final res = controller
                                      .triggerGhostSlotAutoRelease(
                                    activeBooking.id,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message)),
                                  );
                                },
                                icon: const Icon(Icons.timer_off_outlined),
                                label: const Text(
                                  'Simulate 10-Min Grace Expiry (+1 Strike)',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'My Reservation History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final b in userHistory)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(
                      '${b.roomName} • ${b.stationNumber} (${b.courseworkTag})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Code: ${b.qrAuthCode} • ${b.status.label}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class StudentHelpDeskChatTab extends ConsumerStatefulWidget {
  const StudentHelpDeskChatTab({super.key});

  @override
  ConsumerState<StudentHelpDeskChatTab> createState() =>
      _StudentHelpDeskChatTabState();
}

class _StudentHelpDeskChatTabState
    extends ConsumerState<StudentHelpDeskChatTab> {
  final _msgController = TextEditingController();

  static const List<String> _quickPrompts = [
    'Need Admin password to launch Android Emulator',
    'Mouse left-click is sticking on my station',
    'May I request a 15-minute slot extension?',
  ];

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    final res = ref
        .read(labSlotProvider.notifier)
        .sendHelpDeskMessage(messageText: text);
    if (res.success) {
      _msgController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labSlotProvider);
    final currentUser = state.currentUser;
    final messages = state.chatMessages
        .where((m) => m.studentId == currentUser?.id)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Relay Session Help Desk Messages (Custodian Support)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Messages are routed in real time to the on-duty Laboratory Custodian with your room & workstation tag.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final prompt in _quickPrompts)
                        ActionChip(
                          label: Text(
                            prompt,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _sendMessage(prompt),
                        ),
                    ],
                  ),
                  const Divider(height: 22),
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(
                            child: Text(
                              'No help desk messages yet. Tap a quick prompt above or type a message below.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg.senderId == currentUser?.id;
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  constraints:
                                      const BoxConstraints(maxWidth: 480),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppTheme.primaryBlue
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${msg.senderName} (${msg.stationNumber})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isMe
                                              ? Colors.white70
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        msg.message,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('student-chat-input'),
                          controller: _msgController,
                          autofillHints: const [],
                          decoration: const InputDecoration(
                            labelText: 'Help Desk Message',
                            hintText:
                                'Type your message to the Laboratory Custodian...',
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        key: const Key('student-chat-send-button'),
                        onPressed: () => _sendMessage(_msgController.text),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

