import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class CustodianRoomsAndMaintenanceTab extends ConsumerWidget {
  const CustodianRoomsAndMaintenanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labSlotProvider);
    final controller = ref.read(labSlotProvider.notifier);

    final openTickets = state.maintenanceTickets
        .where((t) => !t.isResolved)
        .toList();
    final resolvedTickets = state.maintenanceTickets
        .where((t) => t.isResolved)
        .toList();
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isPhone ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Manage Laboratory Room Availability
          const Text(
            '1. Manage Laboratory Room Availability Status',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Switch room state between Open Lab, Class in Session, and Closed. New student bookings are automatically blocked while a class is in session.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          for (final room in state.rooms)
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
                        Text(
                          '${room.code} — ${room.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${room.buildingFloor} • Note: ${room.currentSubjectNote}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    if (isPhone)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final statusOption in RoomStatus.values)
                            ChoiceChip(
                              label: Text(statusOption.label),
                              selected: room.status == statusOption,
                              onSelected: (selected) {
                                if (!selected) return;
                                final note = statusOption == RoomStatus.open
                                    ? 'Open Lab for Vacant Period Coding'
                                    : statusOption == RoomStatus.classInSession
                                        ? 'Scheduled Lecture / Make-up Class in Session'
                                        : 'Closed for Scheduled Maintenance';
                                final res = controller.updateRoomAvailability(
                                  roomId: room.id,
                                  newStatus: statusOption,
                                  subjectNote: note,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.message)),
                                );
                              },
                            ),
                        ],
                      )
                    else
                      SegmentedButton<RoomStatus>(
                        segments: const [
                          ButtonSegment(
                            value: RoomStatus.open,
                            label: Text('Open Lab', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.check_circle_outline, size: 16),
                          ),
                          ButtonSegment(
                            value: RoomStatus.classInSession,
                            label: Text(
                              'Class in Session',
                              style: TextStyle(fontSize: 12),
                            ),
                            icon: Icon(Icons.school_outlined, size: 16),
                          ),
                          ButtonSegment(
                            value: RoomStatus.closed,
                            label: Text('Closed', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.lock_outline, size: 16),
                          ),
                        ],
                        selected: {room.status},
                        onSelectionChanged: (selection) {
                          final chosen = selection.first;
                          final note = chosen == RoomStatus.open
                              ? 'Open Lab for Vacant Period Coding'
                              : chosen == RoomStatus.classInSession
                                  ? 'Scheduled Lecture / Make-up Class in Session'
                                  : 'Closed for Scheduled Maintenance';
                          final res = controller.updateRoomAvailability(
                            roomId: room.id,
                            newStatus: chosen,
                            subjectNote: note,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res.message)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 26),

          // Section 2: Manage PC Station Maintenance Queue
          Text(
            '2. Manage PC Station Maintenance Queue (${openTickets.length} Quarantined)',
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Includes automatic "Last Checked-Out User" hardware trace for accountability. Log repair notes to restore a unit to Available.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          if (openTickets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'All workstations are operational. Zero unresolved maintenance tickets.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            )
          else
            for (final ticket in openTickets)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${ticket.roomName} • ${ticket.stationNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
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
                              ticket.issueCategory,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warningAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Issue Details: ${ticket.description}',
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reported by: ${ticket.reportedByName}  •  Last Logged Station User: ${ticket.lastUserName ?? "N/A"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          key: Key('resolve-ticket-${ticket.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.availableGreen,
                          ),
                          onPressed: () =>
                              _showResolveDialog(context, ref, ticket),
                          icon: const Icon(Icons.build_circle_outlined),
                          label: const Text(
                            'Log Repair Notes & Restore PC to Available',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          if (resolvedTickets.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Recently Resolved Maintenance Logs',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final t in resolvedTickets)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.availableGreen,
                  ),
                  title: Text('${t.roomName} • ${t.stationNumber} (${t.issueCategory})'),
                  subtitle: Text(
                    'Repair Note: ${t.repairNotes ?? "Repaired"} • By ${t.resolvedByName ?? "Custodian"}',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showResolveDialog(
    BuildContext context,
    WidgetRef ref,
    MaintenanceTicket ticket,
  ) {
    final repairController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore ${ticket.stationNumber} to Available'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextField(
              key: const Key('repair-notes-field'),
              controller: repairController,
              maxLines: 3,
              autofillHints: const [],
              decoration: const InputDecoration(
                labelText: 'Technician Repair Notes',
                hintText:
                    'Describe the repair or replacement done before restoring this PC...',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm-restore-pc-button'),
            onPressed: () {
              final res = ref
                  .read(labSlotProvider.notifier)
                  .resolveMaintenanceTicket(
                    ticketId: ticket.id,
                    repairNotes: repairController.text,
                  );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res.message)),
              );
            },
            child: const Text('Confirm Repair & Restore'),
          ),
        ],
      ),
    );
  }
}

class CustodianHelpDeskInboxTab extends ConsumerStatefulWidget {
  const CustodianHelpDeskInboxTab({super.key});

  @override
  ConsumerState<CustodianHelpDeskInboxTab> createState() =>
      _CustodianHelpDeskInboxTabState();
}

class _CustodianHelpDeskInboxTabState
    extends ConsumerState<CustodianHelpDeskInboxTab> {
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _sendReply(ChatMessage lastStudentMsg) {
    final res = ref.read(labSlotProvider.notifier).sendHelpDeskMessage(
          messageText: _replyController.text,
          targetStudentId: lastStudentMsg.studentId,
          targetRoomId: lastStudentMsg.roomId,
          targetStationNumber: lastStudentMsg.stationNumber,
        );
    if (res.success) {
      _replyController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labSlotProvider);
    final messages = state.chatMessages;
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.all(isPhone ? 12 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(isPhone ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Custodian Help Desk Inquiries (Active Station Threads)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Real-time support messages from seated students across laboratories.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 22),
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isStaff = msg.senderRole != UserRole.student;
                        return Align(
                          alignment: isStaff
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxWidth: 520),
                            decoration: BoxDecoration(
                              color: isStaff
                                  ? AppTheme.availableBg
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${msg.senderName} • ${msg.roomName} (${msg.stationNumber})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(msg.message),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (messages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('custodian-chat-reply-field'),
                            controller: _replyController,
                            autofillHints: const [],
                            decoration: InputDecoration(
                              labelText: 'Help Desk Reply',
                              hintText:
                                  'Type your response to ${messages.last.studentName} (${messages.last.stationNumber})...',
                            ),
                            onSubmitted: (_) => _sendReply(messages.last),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: const Key('custodian-chat-reply-button'),
                          onPressed: () => _sendReply(messages.last),
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: Text(isPhone ? 'Reply' : 'Send Reply'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

