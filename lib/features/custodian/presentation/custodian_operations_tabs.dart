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
    final operationalStations = state.stations
        .where((s) => !s.isDefective && s.status != PcStatus.maintenance)
        .toList();
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isPhone ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Manage Laboratory Room Availability
          const Text(
            '1. Laboratory Room Availability',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Switch room state between Open Lab, Class in Session, and Closed. Pending walk-in bookings are automatically cancelled without penalty if a room closes.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          if (state.rooms.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No laboratory rooms added yet. Ask a System Administrator to create rooms in Lab Inventory.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            )
          else
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
                            '${room.code} - ${room.name}',
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
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
                                      final note =
                                          statusOption == RoomStatus.open
                                              ? 'Open Lab for Vacant Period Coding'
                                              : statusOption ==
                                                      RoomStatus.classInSession
                                                  ? 'Scheduled Lecture in Session'
                                                  : 'Closed for Scheduled Maintenance';
                                      final res =
                                          controller.updateRoomAvailability(
                                        roomId: room.id,
                                        newStatus: statusOption,
                                        subjectNote: note,
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                                  label: Text(
                                    'Open Lab',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  icon: Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                  ),
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
                                  label: Text(
                                    'Closed',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  icon: Icon(Icons.lock_outline, size: 16),
                                ),
                              ],
                              selected: {room.status},
                              onSelectionChanged: (selection) {
                                final chosen = selection.first;
                                final note = chosen == RoomStatus.open
                                    ? 'Open Lab for Vacant Period Coding'
                                    : chosen == RoomStatus.classInSession
                                        ? 'Scheduled Lecture in Session'
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
                          OutlinedButton.icon(
                            key: Key('edit-room-note-${room.id}'),
                            onPressed: () =>
                                _showCustomNoteDialog(context, ref, room),
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: const Text('Edit Note'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

          const SizedBox(height: 26),

          // Section 2: Maintenance Queue + Direct Flag Defective PC button
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Maintenance Queue (${openTickets.length} Quarantined)',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tracks Last Logged Station User for accountability. Flag faulty units or log repair notes to restore them.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                key: const Key('custodian-flag-defect-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningAmber,
                ),
                onPressed: operationalStations.isEmpty
                    ? null
                    : () => _showFlagDefectDialog(
                          context,
                          ref,
                          state.rooms,
                          operationalStations,
                        ),
                icon: const Icon(Icons.report_problem_outlined, size: 18),
                label: const Text('Flag Defective PC'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (openTickets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'All workstations are operational. Zero unresolved maintenance tickets.',
                    textAlign: TextAlign.center,
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
                          label: const Text('Resolve Ticket'),
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
                  title: Text(
                    '${t.roomName} • ${t.stationNumber} (${t.issueCategory})',
                  ),
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

  void _showCustomNoteDialog(
    BuildContext context,
    WidgetRef ref,
    LabRoom room,
  ) {
    final noteController = TextEditingController();
    RoomStatus selectedStatus = room.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Update ${room.code} Status Note'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<RoomStatus>(
                    initialValue: selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Room Status'),
                    items: [
                      for (final s in RoomStatus.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedStatus = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    autofillHints: const [],
                    decoration: const InputDecoration(
                      labelText: 'Custom Room Note',
                      hintText:
                          'Enter subject, class, or maintenance note (e.g., IT-302 Make-up Class)',
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
              onPressed: () {
                final res = ref
                    .read(labSlotProvider.notifier)
                    .updateRoomAvailability(
                      roomId: room.id,
                      newStatus: selectedStatus,
                      subjectNote: noteController.text,
                    );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.message)),
                );
              },
              child: const Text('Save Room Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFlagDefectDialog(
    BuildContext context,
    WidgetRef ref,
    List<LabRoom> rooms,
    List<PcStation> operationalStations,
  ) {
    String selectedStationId = operationalStations.first.id;
    String selectedCategory = 'Broken Mouse / Peripheral';
    final notesController = TextEditingController();

    String roomCodeFor(String roomId) {
      final match = rooms.where((r) => r.id == roomId);
      return match.isNotEmpty ? match.first.code : 'LAB';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Flag Defective PC Station'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('custodian-flag-station-dropdown'),
                    initialValue: selectedStationId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select PC Station',
                    ),
                    items: [
                      for (final st in operationalStations)
                        DropdownMenuItem(
                          value: st.id,
                          child: Text(
                            '${roomCodeFor(st.roomId)} • ${st.stationNumber} (${st.status.label})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedStationId = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Issue Category',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Broken Mouse / Peripheral',
                        child: Text('Broken Mouse / Keyboard Peripheral'),
                      ),
                      DropdownMenuItem(
                        value: 'No Network / Internet',
                        child: Text('No Network / Internet Connection'),
                      ),
                      DropdownMenuItem(
                        value: 'Missing Required IDE / Software',
                        child: Text('Missing Required Coursework IDE'),
                      ),
                      DropdownMenuItem(
                        value: 'Monitor / Boot Failure',
                        child: Text('Monitor Blank / System Boot Failure'),
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
                    key: const Key('custodian-flag-notes-field'),
                    controller: notesController,
                    maxLines: 3,
                    autofillHints: const [],
                    decoration: const InputDecoration(
                      labelText: 'Defect Description',
                      hintText:
                          'Enter hardware fault details to quarantine this unit...',
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
              key: const Key('custodian-confirm-flag-button'),
              onPressed: () {
                final res = ref
                    .read(labSlotProvider.notifier)
                    .reportDefectivePcStation(
                      stationId: selectedStationId,
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
              child: const Text('Quarantine PC'),
            ),
          ],
        ),
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
                SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.success
                      ? AppTheme.availableGreen
                      : AppTheme.reservedRed,
                ),
              );
            },
            child: const Text('Confirm Repair'),
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
  String? _selectedStudentId;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _sendReply(ChatMessage threadAnchor) {
    final res = ref.read(labSlotProvider.notifier).sendHelpDeskMessage(
          messageText: _replyController.text,
          targetStudentId: threadAnchor.studentId,
          targetRoomId: threadAnchor.roomId,
          targetStationNumber: threadAnchor.stationNumber,
        );
    if (res.success) {
      _replyController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppTheme.reservedRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labSlotProvider);
    final allMessages = state.chatMessages;
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    // Group conversations by studentId (latest message per thread)
    final Map<String, List<ChatMessage>> threadsByStudent = {};
    for (final msg in allMessages) {
      threadsByStudent.putIfAbsent(msg.studentId, () => []).add(msg);
    }
    final studentIds = threadsByStudent.keys.toList();

    final String? activeStudentId = studentIds.isEmpty
        ? null
        : (studentIds.contains(_selectedStudentId)
            ? _selectedStudentId
            : studentIds.first);
    final activeThread =
        activeStudentId != null ? threadsByStudent[activeStudentId]! : <ChatMessage>[];
    final threadAnchor = activeThread.isNotEmpty ? activeThread.last : null;
    final threadResolved =
        activeThread.isNotEmpty && activeThread.every((m) => m.isResolved);

    return Padding(
      padding: EdgeInsets.all(isPhone ? 12 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(isPhone ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Help Desk Inbox',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Select a student thread to reply or mark resolved.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (activeStudentId != null && !threadResolved)
                        OutlinedButton.icon(
                          key: const Key('resolve-chat-thread-button'),
                          onPressed: () {
                            final res = ref
                                .read(labSlotProvider.notifier)
                                .resolveHelpDeskThread(activeStudentId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res.message)),
                            );
                          },
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: AppTheme.availableGreen,
                          ),
                          label: const Text('Mark Resolved'),
                        ),
                    ],
                  ),
                  if (studentIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final sid in studentIds) ...[
                            Builder(
                              builder: (context) {
                                final tMsgs = threadsByStudent[sid]!;
                                final last = tMsgs.last;
                                final isResolved =
                                    tMsgs.every((m) => m.isResolved);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    key: Key('chat-thread-chip-$sid'),
                                    selected: sid == activeStudentId,
                                    avatar: Icon(
                                      isResolved
                                          ? Icons.check_circle
                                          : Icons.mark_chat_unread_rounded,
                                      size: 16,
                                      color: isResolved
                                          ? AppTheme.availableGreen
                                          : AppTheme.warningAmber,
                                    ),
                                    label: Text(
                                      '${last.studentName} (${last.stationNumber})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onSelected: (_) =>
                                        setState(() => _selectedStudentId = sid),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 22),
                  Expanded(
                    child: activeThread.isEmpty
                        ? const Center(
                            child: Text(
                              'No help desk inquiries yet.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: activeThread.length,
                            itemBuilder: (context, index) {
                              final msg = activeThread[index];
                              final isStaff = msg.senderRole != UserRole.student;
                              return Align(
                                alignment: isStaff
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  constraints:
                                      const BoxConstraints(maxWidth: 520),
                                  decoration: BoxDecoration(
                                    color: isStaff
                                        ? AppTheme.availableBg
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                  if (threadAnchor != null) ...[
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
                                  'Type your response to ${threadAnchor.studentName} (${threadAnchor.stationNumber})...',
                            ),
                            onSubmitted: (_) => _sendReply(threadAnchor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: const Key('custodian-chat-reply-button'),
                          onPressed: () => _sendReply(threadAnchor),
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
