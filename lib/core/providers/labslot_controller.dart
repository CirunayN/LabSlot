import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/labslot_models.dart';

class ActionResult {
  final bool success;
  final String message;

  const ActionResult.ok(this.message) : success = true;
  const ActionResult.err(this.message) : success = false;
}

class LabSlotState {
  final UserProfile? currentUser;
  final List<UserProfile> users;
  final List<LabRoom> rooms;
  final List<PcStation> stations;
  final List<Booking> bookings;
  final List<MaintenanceTicket> maintenanceTickets;
  final List<ChatMessage> chatMessages;
  final String selectedRoomId;
  final Set<String> selectedSoftwareFilters;
  final int minimumRamFilterGb;
  final bool onlyAvailableFilter;

  const LabSlotState({
    required this.currentUser,
    required this.users,
    required this.rooms,
    required this.stations,
    required this.bookings,
    required this.maintenanceTickets,
    required this.chatMessages,
    required this.selectedRoomId,
    required this.selectedSoftwareFilters,
    this.minimumRamFilterGb = 0,
    this.onlyAvailableFilter = false,
  });

  LabSlotState copyWith({
    UserProfile? currentUser,
    bool clearCurrentUser = false,
    List<UserProfile>? users,
    List<LabRoom>? rooms,
    List<PcStation>? stations,
    List<Booking>? bookings,
    List<MaintenanceTicket>? maintenanceTickets,
    List<ChatMessage>? chatMessages,
    String? selectedRoomId,
    Set<String>? selectedSoftwareFilters,
    int? minimumRamFilterGb,
    bool? onlyAvailableFilter,
  }) {
    return LabSlotState(
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
      users: users ?? this.users,
      rooms: rooms ?? this.rooms,
      stations: stations ?? this.stations,
      bookings: bookings ?? this.bookings,
      maintenanceTickets: maintenanceTickets ?? this.maintenanceTickets,
      chatMessages: chatMessages ?? this.chatMessages,
      selectedRoomId: selectedRoomId ?? this.selectedRoomId,
      selectedSoftwareFilters:
          selectedSoftwareFilters ?? this.selectedSoftwareFilters,
      minimumRamFilterGb: minimumRamFilterGb ?? this.minimumRamFilterGb,
      onlyAvailableFilter: onlyAvailableFilter ?? this.onlyAvailableFilter,
    );
  }

  LabRoom get selectedRoom => rooms.firstWhere(
        (r) => r.id == selectedRoomId,
        orElse: () => rooms.first,
      );

  List<PcStation> stationsForRoom(String roomId, {bool applyFilters = true}) {
    final list = stations.where((s) => s.roomId == roomId).toList()
      ..sort((a, b) => a.stationNumber.compareTo(b.stationNumber));
    if (!applyFilters) return list;

    return list.where((station) {
      if (onlyAvailableFilter && station.status != PcStatus.available) {
        return false;
      }
      if (minimumRamFilterGb > 0 && station.ramGb < minimumRamFilterGb) {
        return false;
      }
      if (selectedSoftwareFilters.isNotEmpty) {
        final hasAll = selectedSoftwareFilters.every(
          (tag) => station.installedSoftware.any(
            (s) => s.toLowerCase() == tag.toLowerCase(),
          ),
        );
        if (!hasAll) return false;
      }
      return true;
    }).toList();
  }

  Booking? get activeBookingForCurrentUser {
    if (currentUser == null) return null;
    for (final b in bookings) {
      if (b.studentId == currentUser!.id && b.isActive) {
        return b;
      }
    }
    return null;
  }

  List<Booking> get pendingCheckInBookings =>
      bookings.where((b) => b.status == BookingStatus.reserved).toList();

  List<Booking> get activeCheckedInBookings =>
      bookings.where((b) => b.status == BookingStatus.checkedIn).toList();
}

class LabSlotController extends Notifier<LabSlotState> {
  static const List<String> allSoftwareTags = [
    'Flutter',
    'Android Studio',
    'VS Code',
    'Cisco Packet Tracer',
    'AutoCAD 2025',
    'Blender 3D',
    'Docker',
  ];

  @override
  LabSlotState build() {
    return _createSeedState();
  }

  static LabSlotState _createSeedState() {
    final now = DateTime.now();

    final users = <UserProfile>[
      const UserProfile(
        id: 'usr-student-1',
        studentIdNumber: '2024-01042',
        email: 'marco.santos@campus.edu.ph',
        fullName: 'Marco Santos',
        role: UserRole.student,
        courseDepartment: 'BS Information Technology (3rd Year)',
        strikeCount: 0,
        isSuspended: false,
      ),
      const UserProfile(
        id: 'usr-student-2',
        studentIdNumber: '2024-01889',
        email: 'angela.reyes@campus.edu.ph',
        fullName: 'Angela Reyes',
        role: UserRole.student,
        courseDepartment: 'BS Computer Science (2nd Year)',
        strikeCount: 1,
        isSuspended: false,
      ),
      const UserProfile(
        id: 'usr-student-3',
        studentIdNumber: '2023-00412',
        email: 'kevin.lim@campus.edu.ph',
        fullName: 'Kevin Lim',
        role: UserRole.student,
        courseDepartment: 'BS Multimedia Arts (4th Year)',
        strikeCount: 3,
        isSuspended: true,
      ),
      const UserProfile(
        id: 'usr-custodian-1',
        studentIdNumber: 'STAFF-201',
        email: 'custodian.lab@campus.edu.ph',
        fullName: 'Engr. Ramon Dela Cruz',
        role: UserRole.custodian,
        courseDepartment: 'Campus Laboratory Services',
      ),
      const UserProfile(
        id: 'usr-admin-1',
        studentIdNumber: 'ADMIN-001',
        email: 'admin.its@campus.edu.ph',
        fullName: 'Dr. Elena Villanueva',
        role: UserRole.admin,
        courseDepartment: 'College of Computing & ITS Office',
      ),
    ];

    final rooms = <LabRoom>[
      const LabRoom(
        id: 'room-comlab-1',
        code: 'COMLAB-1',
        name: 'ComLab 1 – Mobile & Full-Stack Lab',
        buildingFloor: '3rd Floor, IT Building',
        status: RoomStatus.open,
        totalCapacity: 12,
        openTime: '07:30',
        closeTime: '19:00',
        currentSubjectNote: 'Open Lab for Vacant Period Coursework',
      ),
      const LabRoom(
        id: 'room-comlab-2',
        code: 'COMLAB-2',
        name: 'ComLab 2 – Cisco Networking Lab',
        buildingFloor: '3rd Floor, IT Building',
        status: RoomStatus.classInSession,
        totalCapacity: 8,
        openTime: '07:30',
        closeTime: '19:00',
        currentSubjectNote: 'IT-302 Network Routing Lecture in Session',
      ),
      const LabRoom(
        id: 'room-comlab-3',
        code: 'COMLAB-3',
        name: 'ComLab 3 – CAD & Multimedia Studio',
        buildingFloor: '4th Floor, Engineering Wing',
        status: RoomStatus.open,
        totalCapacity: 8,
        openTime: '07:30',
        closeTime: '19:00',
        currentSubjectNote: 'Open Lab for 3D & CAD Rendering',
      ),
      const LabRoom(
        id: 'room-comlab-4',
        code: 'COMLAB-4',
        name: 'ComLab 4 – General Programming Lab',
        buildingFloor: '2nd Floor, Main Academic Hall',
        status: RoomStatus.closed,
        totalCapacity: 8,
        openTime: '07:30',
        closeTime: '19:00',
        currentSubjectNote: 'Closed for Scheduled Switch Maintenance',
      ),
    ];

    final stations = <PcStation>[
      // ComLab 1 (12 stations)
      for (int i = 1; i <= 12; i++)
        PcStation(
          id: 'st-c1-$i',
          roomId: 'room-comlab-1',
          stationNumber: 'PC-${i.toString().padLeft(2, '0')}',
          status: i == 2
              ? PcStatus.occupied
              : i == 5
                  ? PcStatus.reserved
                  : i == 9
                      ? PcStatus.maintenance
                      : PcStatus.available,
          cpu: i <= 6 ? 'Intel Core i7-13700' : 'AMD Ryzen 7 5800X',
          ramGb: i <= 8 ? 32 : 16,
          gpu: i <= 6 ? 'NVIDIA RTX 3060 12GB' : 'NVIDIA GTX 1660 Super',
          installedSoftware: [
            'Flutter',
            'Android Studio',
            'VS Code',
            if (i.isOdd) 'Docker',
            if (i <= 4) 'Cisco Packet Tracer',
          ],
          isDefective: i == 9,
          defectCategory: i == 9 ? 'Broken Mouse / Peripheral' : null,
          defectNotes:
              i == 9 ? 'Left mouse button double-clicking; queued for swap' : null,
        ),
      // ComLab 2 (8 stations)
      for (int i = 1; i <= 8; i++)
        PcStation(
          id: 'st-c2-$i',
          roomId: 'room-comlab-2',
          stationNumber: 'PC-${i.toString().padLeft(2, '0')}',
          status: PcStatus.available,
          cpu: 'Intel Core i5-12400',
          ramGb: 16,
          gpu: 'Integrated UHD 730',
          installedSoftware: const [
            'Cisco Packet Tracer',
            'VS Code',
            'Docker',
          ],
        ),
      // ComLab 3 (8 stations)
      for (int i = 1; i <= 8; i++)
        PcStation(
          id: 'st-c3-$i',
          roomId: 'room-comlab-3',
          stationNumber: 'PC-${i.toString().padLeft(2, '0')}',
          status: i == 4 ? PcStatus.maintenance : PcStatus.available,
          cpu: 'Intel Core i9-13900K',
          ramGb: 32,
          gpu: 'NVIDIA RTX 4070 12GB',
          installedSoftware: const [
            'AutoCAD 2025',
            'Blender 3D',
            'VS Code',
            'Flutter',
          ],
          isDefective: i == 4,
          defectCategory: i == 4 ? 'No Network / Internet' : null,
          defectNotes: i == 4 ? 'LAN port loose at wall jack' : null,
        ),
      // ComLab 4 (8 stations)
      for (int i = 1; i <= 8; i++)
        PcStation(
          id: 'st-c4-$i',
          roomId: 'room-comlab-4',
          stationNumber: 'PC-${i.toString().padLeft(2, '0')}',
          status: PcStatus.available,
          cpu: 'Intel Core i5-12400',
          ramGb: 16,
          gpu: 'Integrated Graphics',
          installedSoftware: const ['VS Code', 'Flutter'],
        ),
    ];

    final bookings = <Booking>[
      Booking(
        id: 'bk-seed-active-1',
        studentId: 'usr-student-2',
        studentName: 'Angela Reyes',
        studentIdNumber: '2024-01889',
        roomId: 'room-comlab-1',
        roomName: 'ComLab 1 – Mobile & Full-Stack Lab',
        stationId: 'st-c1-2',
        stationNumber: 'PC-02',
        courseworkTag: 'Flutter',
        scheduledStart: now.subtract(const Duration(minutes: 25)),
        scheduledEnd: now.add(const Duration(minutes: 35)),
        durationHours: 1,
        gracePeriodDeadline: now.subtract(const Duration(minutes: 15)),
        checkInTime: now.subtract(const Duration(minutes: 22)),
        status: BookingStatus.checkedIn,
        idHeld: true,
        idBinLocation: 'Bin-08',
        qrAuthCode: 'LS-8821-PC02',
      ),
      Booking(
        id: 'bk-seed-pending-1',
        studentId: 'usr-student-3',
        studentName: 'Kevin Lim',
        studentIdNumber: '2023-00412',
        roomId: 'room-comlab-1',
        roomName: 'ComLab 1 – Mobile & Full-Stack Lab',
        stationId: 'st-c1-5',
        stationNumber: 'PC-05',
        courseworkTag: 'Android Studio',
        scheduledStart: now,
        scheduledEnd: now.add(const Duration(hours: 2)),
        durationHours: 2,
        gracePeriodDeadline: now.add(const Duration(minutes: 9)),
        status: BookingStatus.reserved,
        qrAuthCode: 'LS-4092-PC05',
      ),
      // Historical completed bookings for Accreditation Analytics
      Booking(
        id: 'bk-hist-1',
        studentId: 'usr-student-1',
        studentName: 'Marco Santos',
        studentIdNumber: '2024-01042',
        roomId: 'room-comlab-1',
        roomName: 'ComLab 1 – Mobile & Full-Stack Lab',
        stationId: 'st-c1-9',
        stationNumber: 'PC-09',
        courseworkTag: 'Flutter',
        scheduledStart: now.subtract(const Duration(days: 1, hours: 4)),
        scheduledEnd: now.subtract(const Duration(days: 1, hours: 2)),
        durationHours: 2,
        gracePeriodDeadline:
            now.subtract(const Duration(days: 1, hours: 3, minutes: 50)),
        checkInTime:
            now.subtract(const Duration(days: 1, hours: 3, minutes: 55)),
        checkOutTime: now.subtract(const Duration(days: 1, hours: 2)),
        status: BookingStatus.completed,
        idHeld: false,
        idBinLocation: 'Bin-03',
        qrAuthCode: 'LS-1102-PC09',
      ),
      Booking(
        id: 'bk-hist-2',
        studentId: 'usr-student-2',
        studentName: 'Angela Reyes',
        studentIdNumber: '2024-01889',
        roomId: 'room-comlab-3',
        roomName: 'ComLab 3 – CAD & Multimedia Studio',
        stationId: 'st-c3-1',
        stationNumber: 'PC-01',
        courseworkTag: 'AutoCAD 2025',
        scheduledStart: now.subtract(const Duration(days: 2, hours: 5)),
        scheduledEnd: now.subtract(const Duration(days: 2, hours: 3)),
        durationHours: 2,
        gracePeriodDeadline:
            now.subtract(const Duration(days: 2, hours: 4, minutes: 50)),
        checkInTime:
            now.subtract(const Duration(days: 2, hours: 4, minutes: 56)),
        checkOutTime: now.subtract(const Duration(days: 2, hours: 3)),
        status: BookingStatus.completed,
        idHeld: false,
        idBinLocation: 'Bin-12',
        qrAuthCode: 'LS-3319-PC01',
      ),
      Booking(
        id: 'bk-hist-3',
        studentId: 'usr-student-3',
        studentName: 'Kevin Lim',
        studentIdNumber: '2023-00412',
        roomId: 'room-comlab-2',
        roomName: 'ComLab 2 – Cisco Networking Lab',
        stationId: 'st-c2-3',
        stationNumber: 'PC-03',
        courseworkTag: 'Cisco Packet Tracer',
        scheduledStart: now.subtract(const Duration(days: 3, hours: 3)),
        scheduledEnd: now.subtract(const Duration(days: 3, hours: 2)),
        durationHours: 1,
        gracePeriodDeadline:
            now.subtract(const Duration(days: 3, hours: 2, minutes: 50)),
        status: BookingStatus.noShowCancelled,
        qrAuthCode: 'LS-7741-PC03',
      ),
    ];

    final tickets = <MaintenanceTicket>[
      MaintenanceTicket(
        id: 'mt-1',
        roomId: 'room-comlab-1',
        roomName: 'ComLab 1 – Mobile & Full-Stack Lab',
        stationId: 'st-c1-9',
        stationNumber: 'PC-09',
        reportedById: 'usr-student-1',
        reportedByName: 'Marco Santos',
        lastUserId: 'usr-student-1',
        lastUserName: 'Marco Santos (2024-01042)',
        issueCategory: 'Broken Mouse / Peripheral',
        description: 'Left mouse click fails intermittently while coding.',
        isResolved: false,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      MaintenanceTicket(
        id: 'mt-2',
        roomId: 'room-comlab-3',
        roomName: 'ComLab 3 – CAD & Multimedia Studio',
        stationId: 'st-c3-4',
        stationNumber: 'PC-04',
        reportedById: 'usr-custodian-1',
        reportedByName: 'Engr. Ramon Dela Cruz',
        lastUserId: 'usr-student-2',
        lastUserName: 'Angela Reyes (2024-01889)',
        issueCategory: 'No Network / Internet',
        description: 'Ethernet cable clip broken on wall port.',
        isResolved: false,
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      MaintenanceTicket(
        id: 'mt-3',
        roomId: 'room-comlab-1',
        roomName: 'ComLab 1 – Mobile & Full-Stack Lab',
        stationId: 'st-c1-4',
        stationNumber: 'PC-04',
        reportedById: 'usr-student-2',
        reportedByName: 'Angela Reyes',
        lastUserId: 'usr-student-2',
        lastUserName: 'Angela Reyes (2024-01889)',
        issueCategory: 'Missing Required IDE / Software',
        description: 'Android SDK Command-line tools needed update.',
        isResolved: true,
        repairNotes: 'Updated Android SDK Platform 35 and verified emulator.',
        resolvedByName: 'Engr. Ramon Dela Cruz',
        createdAt: now.subtract(const Duration(days: 2, hours: 6)),
        resolvedAt: now.subtract(const Duration(days: 2, hours: 4)),
      ),
    ];

    final chats = <ChatMessage>[
      ChatMessage(
        id: 'msg-1',
        bookingId: 'bk-seed-active-1',
        roomId: 'room-comlab-1',
        roomName: 'ComLab 1 – Mobile & Full-Stack Lab',
        stationNumber: 'PC-02',
        studentId: 'usr-student-2',
        studentName: 'Angela Reyes',
        senderId: 'usr-student-2',
        senderName: 'Angela Reyes',
        senderRole: UserRole.student,
        message:
            'Good day sir! May I request admin permission on PC-02 to start the Android Emulator?',
        createdAt: now.subtract(const Duration(minutes: 14)),
      ),
      ChatMessage(
        id: 'msg-2',
        bookingId: 'bk-seed-active-1',
        roomId: 'room-comlab-1',
        roomName: 'ComLab 1 – Mobile & Full-Stack Lab',
        stationNumber: 'PC-02',
        studentId: 'usr-student-2',
        studentName: 'Angela Reyes',
        senderId: 'usr-custodian-1',
        senderName: 'Engr. Ramon Dela Cruz',
        senderRole: UserRole.custodian,
        message:
            'Copy Angela! Hyper-V permission is now unlocked remotely on PC-02.',
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
    ];

    return LabSlotState(
      currentUser: users.first,
      users: users,
      rooms: rooms,
      stations: stations,
      bookings: bookings,
      maintenanceTickets: tickets,
      chatMessages: chats,
      selectedRoomId: rooms.first.id,
      selectedSoftwareFilters: const {},
    );
  }

  // ===========================================================================
  // AUTH & ROLE SWITCHING
  // ===========================================================================
  void loginAsDemoUser(String userId) {
    final user = state.users.firstWhere(
      (u) => u.id == userId,
      orElse: () => state.users.first,
    );
    state = state.copyWith(currentUser: user);
  }

  Future<ActionResult> signInWithCredentials({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      return const ActionResult.err('Please enter both email and password.');
    }

    if (SupabaseConfig.isLiveConnected) {
      try {
        final client = SupabaseConfig.clientOrNull!;
        final res = await client.auth.signInWithPassword(
          email: trimmedEmail,
          password: password,
        );
        if (res.user != null) {
          final profileMap = await client
              .from('profiles')
              .select()
              .eq('id', res.user!.id)
              .maybeSingle();
          if (profileMap != null) {
            final profile = UserProfile.fromMap(profileMap);
            state = state.copyWith(currentUser: profile);
            return ActionResult.ok('Welcome back, ${profile.fullName}!');
          }
        }
      } catch (e) {
        return ActionResult.err('Supabase login failed: $e');
      }
    }

    final match = state.users.where(
      (u) => u.email.toLowerCase() == trimmedEmail,
    );
    if (match.isNotEmpty) {
      state = state.copyWith(currentUser: match.first);
      return ActionResult.ok('Signed in as ${match.first.fullName}.');
    }

    // Create a local student session for testing new emails
    final newProfile = UserProfile(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      studentIdNumber:
          '2026-${(1000 + state.users.length).toString().padLeft(4, '0')}',
      email: trimmedEmail,
      fullName: trimmedEmail.split('@').first.replaceAll('.', ' ').toUpperCase(),
      role: UserRole.student,
      courseDepartment: 'BS Information Technology',
    );
    state = state.copyWith(
      users: [...state.users, newProfile],
      currentUser: newProfile,
    );
    return ActionResult.ok('Signed in as ${newProfile.fullName}.');
  }

  void signOut() {
    if (SupabaseConfig.isLiveConnected) {
      SupabaseConfig.clientOrNull?.auth.signOut();
    }
    state = state.copyWith(clearCurrentUser: true);
  }

  // ===========================================================================
  // STUDENT USE CASE 1: Retrieve Live Lab and PC Availability (Filters)
  // ===========================================================================
  void selectRoom(String roomId) {
    state = state.copyWith(selectedRoomId: roomId);
  }

  void toggleSoftwareFilter(String tag) {
    final updated = Set<String>.from(state.selectedSoftwareFilters);
    if (updated.contains(tag)) {
      updated.remove(tag);
    } else {
      updated.add(tag);
    }
    state = state.copyWith(selectedSoftwareFilters: updated);
  }

  void setMinimumRamFilter(int ramGb) {
    state = state.copyWith(minimumRamFilterGb: ramGb);
  }

  void toggleOnlyAvailableFilter(bool value) {
    state = state.copyWith(onlyAvailableFilter: value);
  }

  void clearAllFilters() {
    state = state.copyWith(
      selectedSoftwareFilters: const {},
      minimumRamFilterGb: 0,
      onlyAvailableFilter: false,
    );
  }

  // ===========================================================================
  // STUDENT USE CASE 2: Process PC Station Slot Reservation
  // ===========================================================================
  ActionResult reservePcStationSlot({
    required String stationId,
    required int durationHours,
    required String courseworkTag,
  }) {
    final user = state.currentUser;
    if (user == null) {
      return const ActionResult.err('Authentication required.');
    }

    // Validation 1: Fair-use 3-strike check
    if (user.isSuspended || user.strikeCount >= 3) {
      return const ActionResult.err(
        'Reservation could not be processed: Your account has an active 3-strike no-show restriction.',
      );
    }

    // Validation 2: Duration 1–2 hours check
    if (durationHours < 1 || durationHours > 2) {
      return const ActionResult.err(
        'Invalid slot duration: Bookings must be between 1 and 2 hours.',
      );
    }

    // Validation 3: Overlapping active reservation check
    if (state.activeBookingForCurrentUser != null) {
      return const ActionResult.err(
        'Reservation could not be processed: You already have an active booking pass.',
      );
    }

    final stationIndex = state.stations.indexWhere((s) => s.id == stationId);
    if (stationIndex == -1) {
      return const ActionResult.err('Selected PC station does not exist.');
    }
    final station = state.stations[stationIndex];
    final room = state.rooms.firstWhere((r) => r.id == station.roomId);

    // Validation 4: Room open check
    if (room.status != RoomStatus.open) {
      return ActionResult.err(
        'Cannot book in ${room.name}: Room status is currently "${room.status.label}".',
      );
    }

    // Validation 5: PC station availability check
    if (station.status != PcStatus.available || station.isDefective) {
      return ActionResult.err(
        'Reservation could not be processed: ${station.stationNumber} is currently ${station.status.label}.',
      );
    }

    final now = DateTime.now();
    final codeSuffix =
        (1000 + DateTime.now().millisecond % 8999).toString().padLeft(4, '0');
    final qrCode = 'LS-$codeSuffix-${station.stationNumber.replaceAll('-', '')}';

    final newBooking = Booking(
      id: 'bk-${now.millisecondsSinceEpoch}',
      studentId: user.id,
      studentName: user.fullName,
      studentIdNumber: user.studentIdNumber,
      roomId: room.id,
      roomName: room.name,
      stationId: station.id,
      stationNumber: station.stationNumber,
      courseworkTag: courseworkTag,
      scheduledStart: now,
      scheduledEnd: now.add(Duration(hours: durationHours)),
      durationHours: durationHours,
      gracePeriodDeadline: now.add(const Duration(minutes: 10)),
      status: BookingStatus.reserved,
      qrAuthCode: qrCode,
    );

    final updatedStations = List<PcStation>.from(state.stations);
    updatedStations[stationIndex] =
        station.copyWith(status: PcStatus.reserved);

    state = state.copyWith(
      stations: updatedStations,
      bookings: [newBooking, ...state.bookings],
    );

    return ActionResult.ok(
      'Reserved ${station.stationNumber} in ${room.code}! Present QR pass ($qrCode) within 10 minutes.',
    );
  }

  // ===========================================================================
  // STUDENT USE CASE 3: Manage Active Booking Pass and Grace Period
  // ===========================================================================
  ActionResult cancelPendingBooking(String bookingId) {
    final idx = state.bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) {
      return const ActionResult.err('Booking record not found.');
    }
    final booking = state.bookings[idx];
    if (booking.status != BookingStatus.reserved) {
      return const ActionResult.err(
        'Only pending reservations can be cancelled directly by the student.',
      );
    }

    final updatedBookings = List<Booking>.from(state.bookings);
    updatedBookings[idx] = booking.copyWith(status: BookingStatus.cancelled);

    final updatedStations = state.stations.map((s) {
      if (s.id == booking.stationId) {
        return s.copyWith(
          status: s.isDefective ? PcStatus.maintenance : PcStatus.available,
        );
      }
      return s;
    }).toList();

    state = state.copyWith(
      bookings: updatedBookings,
      stations: updatedStations,
    );
    return ActionResult.ok(
      'Reservation for ${booking.stationNumber} has been cancelled and released.',
    );
  }

  ActionResult triggerGhostSlotAutoRelease(String bookingId) {
    final idx = state.bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) {
      return const ActionResult.err('Booking not found.');
    }
    final booking = state.bookings[idx];
    if (booking.status != BookingStatus.reserved) {
      return const ActionResult.err('Booking is already checked in or closed.');
    }

    final updatedBookings = List<Booking>.from(state.bookings);
    updatedBookings[idx] = booking.copyWith(
      status: BookingStatus.noShowCancelled,
      gracePeriodDeadline: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    final updatedStations = state.stations.map((s) {
      if (s.id == booking.stationId) {
        return s.copyWith(
          status: s.isDefective ? PcStatus.maintenance : PcStatus.available,
        );
      }
      return s;
    }).toList();

    final updatedUsers = state.users.map((u) {
      if (u.id == booking.studentId) {
        final newStrikes = u.strikeCount + 1;
        return u.copyWith(
          strikeCount: newStrikes,
          isSuspended: newStrikes >= 3,
        );
      }
      return u;
    }).toList();

    final current = state.currentUser;
    final updatedCurrent = current != null && current.id == booking.studentId
        ? updatedUsers.firstWhere((u) => u.id == current.id)
        : current;

    state = state.copyWith(
      bookings: updatedBookings,
      stations: updatedStations,
      users: updatedUsers,
      currentUser: updatedCurrent,
    );

    return ActionResult.ok(
      '10-minute grace period expired: ${booking.stationNumber} auto-released to Available and +1 no-show strike recorded.',
    );
  }

  // ===========================================================================
  // STUDENT USE CASE 4: Process Defective PC Station Report
  // ===========================================================================
  ActionResult reportDefectivePcStation({
    required String stationId,
    required String issueCategory,
    required String description,
  }) {
    final reporter = state.currentUser;
    if (reporter == null) {
      return const ActionResult.err('Authentication required.');
    }
    if (issueCategory.trim().isEmpty || description.trim().isEmpty) {
      return const ActionResult.err(
        'Report not submitted: Please select a hardware/software defect category and provide details.',
      );
    }

    final stationIdx = state.stations.indexWhere((s) => s.id == stationId);
    if (stationIdx == -1) {
      return const ActionResult.err('Invalid PC station ID.');
    }
    final station = state.stations[stationIdx];
    if (station.isDefective || station.status == PcStatus.maintenance) {
      return ActionResult.err(
        'Report not submitted: ${station.stationNumber} is already quarantined Under Maintenance.',
      );
    }

    final room = state.rooms.firstWhere((r) => r.id == station.roomId);

    // Trace the last student who used this station for hardware accountability
    Booking? lastSession;
    for (final b in state.bookings) {
      if (b.stationId == stationId &&
          (b.status == BookingStatus.completed ||
              b.status == BookingStatus.checkedIn)) {
        lastSession = b;
        break;
      }
    }

    final ticket = MaintenanceTicket(
      id: 'mt-${DateTime.now().millisecondsSinceEpoch}',
      roomId: room.id,
      roomName: room.name,
      stationId: station.id,
      stationNumber: station.stationNumber,
      reportedById: reporter.id,
      reportedByName: reporter.fullName,
      lastUserId: lastSession?.studentId,
      lastUserName: lastSession != null
          ? '${lastSession.studentName} (${lastSession.studentIdNumber})'
          : 'No recent logged user',
      issueCategory: issueCategory.trim(),
      description: description.trim(),
      createdAt: DateTime.now(),
    );

    final updatedStations = List<PcStation>.from(state.stations);
    updatedStations[stationIdx] = station.copyWith(
      status: PcStatus.maintenance,
      isDefective: true,
      defectCategory: issueCategory.trim(),
      defectNotes: description.trim(),
    );

    state = state.copyWith(
      stations: updatedStations,
      maintenanceTickets: [ticket, ...state.maintenanceTickets],
    );

    return ActionResult.ok(
      '${station.stationNumber} quarantined as Under Maintenance and queued for custodian inspection.',
    );
  }

  // ===========================================================================
  // STUDENT UC 5 & CUSTODIAN UC 10: Relay & Manage Help Desk Messages
  // ===========================================================================
  ActionResult sendHelpDeskMessage({
    required String messageText,
    String? targetStudentId,
    String? targetRoomId,
    String? targetStationNumber,
  }) {
    final sender = state.currentUser;
    if (sender == null) {
      return const ActionResult.err('Authentication required.');
    }
    final trimmed = messageText.trim();
    if (trimmed.isEmpty) {
      return const ActionResult.err('Please enter a message before sending.');
    }

    final activeBooking = state.activeBookingForCurrentUser;
    final room = targetRoomId != null
        ? state.rooms.firstWhere(
            (r) => r.id == targetRoomId,
            orElse: () => state.selectedRoom,
          )
        : (activeBooking != null
            ? state.rooms.firstWhere((r) => r.id == activeBooking.roomId)
            : state.selectedRoom);

    final studentProfile = targetStudentId != null
        ? state.users.firstWhere(
            (u) => u.id == targetStudentId,
            orElse: () => sender,
          )
        : sender;

    final stationNum =
        targetStationNumber ?? activeBooking?.stationNumber ?? 'PC-01';

    final msg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: activeBooking?.id,
      roomId: room.id,
      roomName: room.name,
      stationNumber: stationNum,
      studentId: studentProfile.id,
      studentName: studentProfile.fullName,
      senderId: sender.id,
      senderName: sender.fullName,
      senderRole: sender.role,
      message: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(chatMessages: [...state.chatMessages, msg]);
    return const ActionResult.ok('Support message sent.');
  }

  // ===========================================================================
  // CUSTODIAN USE CASE 6: Process Student Check-In and ID Escrow
  // ===========================================================================
  ActionResult processStudentCheckIn({
    required String bookingId,
    required String idBinLocation,
  }) {
    final bin = idBinLocation.trim();
    if (bin.isEmpty) {
      return const ActionResult.err(
        'Validation failed: Please assign a physical school ID tray bin (e.g., Bin-14).',
      );
    }

    final idx = state.bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) {
      return const ActionResult.err('Reservation record not found.');
    }
    final booking = state.bookings[idx];

    if (booking.status != BookingStatus.reserved) {
      return ActionResult.err(
        'Check-in denied: Booking status is currently "${booking.status.label}".',
      );
    }

    // Validate 10-minute grace period
    if (booking.isGracePeriodExpired(DateTime.now())) {
      triggerGhostSlotAutoRelease(bookingId);
      return const ActionResult.err(
        'Check-in denied: Reservation expired past the 10-minute grace period and the station was automatically released.',
      );
    }

    // Verify target PC is not under maintenance
    final stationIdx =
        state.stations.indexWhere((s) => s.id == booking.stationId);
    if (stationIdx != -1 && state.stations[stationIdx].isDefective) {
      return ActionResult.err(
        'Check-in blocked: ${booking.stationNumber} is flagged Under Maintenance. Please assign an alternative working PC.',
      );
    }

    final updatedBookings = List<Booking>.from(state.bookings);
    updatedBookings[idx] = booking.copyWith(
      status: BookingStatus.checkedIn,
      checkInTime: DateTime.now(),
      idHeld: true,
      idBinLocation: bin,
    );

    final updatedStations = List<PcStation>.from(state.stations);
    if (stationIdx != -1) {
      updatedStations[stationIdx] =
          updatedStations[stationIdx].copyWith(status: PcStatus.occupied);
    }

    state = state.copyWith(
      bookings: updatedBookings,
      stations: updatedStations,
    );

    return ActionResult.ok(
      'Checked in ${booking.studentName} at ${booking.stationNumber}. Physical ID stored in $bin.',
    );
  }

  // ===========================================================================
  // CUSTODIAN USE CASE 7: Process Student Check-Out and Station Release
  // ===========================================================================
  ActionResult processStudentCheckOut(String bookingId) {
    final idx = state.bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) {
      return const ActionResult.err('Active session record not found.');
    }
    final booking = state.bookings[idx];
    if (booking.status != BookingStatus.checkedIn) {
      return const ActionResult.err('Only Checked-In sessions can be checked out.');
    }

    final returnedBin = booking.idBinLocation ?? 'Tray Vault';
    final updatedBookings = List<Booking>.from(state.bookings);
    updatedBookings[idx] = booking.copyWith(
      status: BookingStatus.completed,
      checkOutTime: DateTime.now(),
      idHeld: false,
    );

    final updatedStations = state.stations.map((s) {
      if (s.id == booking.stationId) {
        return s.copyWith(
          status: s.isDefective ? PcStatus.maintenance : PcStatus.available,
        );
      }
      return s;
    }).toList();

    state = state.copyWith(
      bookings: updatedBookings,
      stations: updatedStations,
    );

    return ActionResult.ok(
      'Checked out ${booking.studentName}. Returned physical ID from $returnedBin and restored ${booking.stationNumber} to Available.',
    );
  }

  // ===========================================================================
  // CUSTODIAN USE CASE 8: Manage Laboratory Room Availability
  // ===========================================================================
  ActionResult updateRoomAvailability({
    required String roomId,
    required RoomStatus newStatus,
    required String subjectNote,
  }) {
    final idx = state.rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) {
      return const ActionResult.err('Laboratory room not found.');
    }

    final updatedRooms = List<LabRoom>.from(state.rooms);
    updatedRooms[idx] = updatedRooms[idx].copyWith(
      status: newStatus,
      currentSubjectNote: subjectNote.trim().isEmpty
          ? newStatus.label
          : subjectNote.trim(),
    );

    state = state.copyWith(rooms: updatedRooms);
    return ActionResult.ok(
      'Updated ${updatedRooms[idx].code} status to "${newStatus.label}".',
    );
  }

  // ===========================================================================
  // CUSTODIAN USE CASE 9: Manage PC Station Maintenance Queue (Resolve / Flag)
  // ===========================================================================
  ActionResult resolveMaintenanceTicket({
    required String ticketId,
    required String repairNotes,
  }) {
    if (repairNotes.trim().isEmpty) {
      return const ActionResult.err(
        'Please enter repair notes before restoring the PC station to Available.',
      );
    }

    final idx = state.maintenanceTickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) {
      return const ActionResult.err('Maintenance ticket not found.');
    }
    final ticket = state.maintenanceTickets[idx];
    final resolverName =
        state.currentUser?.fullName ?? 'Laboratory Custodian';

    final updatedTickets = List<MaintenanceTicket>.from(
      state.maintenanceTickets,
    );
    updatedTickets[idx] = ticket.copyWith(
      isResolved: true,
      repairNotes: repairNotes.trim(),
      resolvedByName: resolverName,
      resolvedAt: DateTime.now(),
    );

    final updatedStations = state.stations.map((s) {
      if (s.id == ticket.stationId) {
        return PcStation(
          id: s.id,
          roomId: s.roomId,
          stationNumber: s.stationNumber,
          status: PcStatus.available,
          cpu: s.cpu,
          ramGb: s.ramGb,
          gpu: s.gpu,
          installedSoftware: s.installedSoftware,
          isDefective: false,
          defectCategory: null,
          defectNotes: null,
        );
      }
      return s;
    }).toList();

    state = state.copyWith(
      maintenanceTickets: updatedTickets,
      stations: updatedStations,
    );

    return ActionResult.ok(
      'Restored ${ticket.stationNumber} (${ticket.roomName}) to Available.',
    );
  }

  // ===========================================================================
  // ADMIN USE CASE 11: Manage Lab Room and PC Inventory
  // ===========================================================================
  ActionResult addLabRoom({
    required String code,
    required String name,
    required String buildingFloor,
    required int initialStationsCount,
  }) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty || name.trim().isEmpty) {
      return const ActionResult.err(
        'Validation failed: Room code and name are required.',
      );
    }
    if (initialStationsCount < 1 || initialStationsCount > 60) {
      return const ActionResult.err(
        'Validation failed: Room capacity must be between 1 and 60 stations.',
      );
    }
    if (state.rooms.any((r) => r.code.toUpperCase() == cleanCode)) {
      return ActionResult.err('Room code "$cleanCode" already exists.');
    }

    final newRoomId = 'room-${DateTime.now().millisecondsSinceEpoch}';
    final newRoom = LabRoom(
      id: newRoomId,
      code: cleanCode,
      name: name.trim(),
      buildingFloor: buildingFloor.trim().isEmpty
          ? 'IT Building'
          : buildingFloor.trim(),
      status: RoomStatus.open,
      totalCapacity: initialStationsCount,
    );

    final newStations = <PcStation>[
      for (int i = 1; i <= initialStationsCount; i++)
        PcStation(
          id: '$newRoomId-pc-$i',
          roomId: newRoomId,
          stationNumber: 'PC-${i.toString().padLeft(2, '0')}',
          status: PcStatus.available,
          installedSoftware: const ['Flutter', 'VS Code'],
        ),
    ];

    state = state.copyWith(
      rooms: [...state.rooms, newRoom],
      stations: [...state.stations, ...newStations],
    );

    return ActionResult.ok(
      'Created $cleanCode with $initialStationsCount PC stations.',
    );
  }

  ActionResult addOrUpdatePcStation({
    required String roomId,
    required String stationNumber,
    required String cpu,
    required int ramGb,
    required String gpu,
    required List<String> installedSoftware,
  }) {
    final cleanNumber = stationNumber.trim().toUpperCase();
    if (cleanNumber.isEmpty) {
      return const ActionResult.err('PC station identifier is required.');
    }
    if (installedSoftware.isEmpty) {
      return const ActionResult.err(
        'Please assign at least one coursework software tag.',
      );
    }

    final existingIdx = state.stations.indexWhere(
      (s) =>
          s.roomId == roomId &&
          s.stationNumber.toUpperCase() == cleanNumber,
    );

    final updatedStations = List<PcStation>.from(state.stations);
    if (existingIdx != -1) {
      updatedStations[existingIdx] = updatedStations[existingIdx].copyWith(
        cpu: cpu.trim(),
        ramGb: ramGb,
        gpu: gpu.trim(),
        installedSoftware: installedSoftware,
      );
      state = state.copyWith(stations: updatedStations);
      return ActionResult.ok('Updated specs & software for $cleanNumber.');
    } else {
      final newStation = PcStation(
        id: 'st-${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        stationNumber: cleanNumber,
        status: PcStatus.available,
        cpu: cpu.trim(),
        ramGb: ramGb,
        gpu: gpu.trim(),
        installedSoftware: installedSoftware,
      );
      updatedStations.add(newStation);
      state = state.copyWith(stations: updatedStations);
      return ActionResult.ok('Added new workstation $cleanNumber.');
    }
  }

  // ===========================================================================
  // ADMIN USE CASE 12: Manage User Roles and Fair-Use Strikes
  // ===========================================================================
  ActionResult updateUserRole(String userId, UserRole newRole) {
    final idx = state.users.indexWhere((u) => u.id == userId);
    if (idx == -1) return const ActionResult.err('User not found.');

    final updatedUsers = List<UserProfile>.from(state.users);
    updatedUsers[idx] = updatedUsers[idx].copyWith(role: newRole);

    final current = state.currentUser;
    final updatedCurrent =
        current != null && current.id == userId ? updatedUsers[idx] : current;

    state = state.copyWith(
      users: updatedUsers,
      currentUser: updatedCurrent,
    );
    return ActionResult.ok(
      'Assigned role "${newRole.label}" to ${updatedUsers[idx].fullName}.',
    );
  }

  ActionResult resetOrAdjustStudentStrikes(String userId, int newStrikeCount) {
    final idx = state.users.indexWhere((u) => u.id == userId);
    if (idx == -1) return const ActionResult.err('User not found.');

    final clamped = newStrikeCount.clamp(0, 10);
    final suspended = clamped >= 3;
    final updatedUsers = List<UserProfile>.from(state.users);
    updatedUsers[idx] = updatedUsers[idx].copyWith(
      strikeCount: clamped,
      isSuspended: suspended,
    );

    final current = state.currentUser;
    final updatedCurrent =
        current != null && current.id == userId ? updatedUsers[idx] : current;

    state = state.copyWith(
      users: updatedUsers,
      currentUser: updatedCurrent,
    );
    return ActionResult.ok(
      suspended
          ? '${updatedUsers[idx].fullName} now has $clamped strikes (Booking Suspended).'
          : 'Updated ${updatedUsers[idx].fullName} to $clamped strikes (Active).',
    );
  }

  // ===========================================================================
  // ADMIN USE CASE 13: Generate Accreditation Utilization Reports
  // ===========================================================================
  AccreditationReport generateAccreditationReport({
    String? roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError(
        'Cannot generate report: Start date must precede the end date.',
      );
    }

    final targetRooms = roomId == null || roomId == 'ALL'
        ? state.rooms
        : state.rooms.where((r) => r.id == roomId).toList();

    final relevantBookings = state.bookings.where((b) {
      final matchesRoom =
          roomId == null || roomId == 'ALL' || b.roomId == roomId;
      final inRange = !b.scheduledStart.isBefore(
            startDate.subtract(const Duration(days: 1)),
          ) &&
          !b.scheduledStart.isAfter(endDate.add(const Duration(days: 1)));
      return matchesRoom && inRange;
    }).toList();

    final relevantTickets = state.maintenanceTickets.where((t) {
      return roomId == null || roomId == 'ALL' || t.roomId == roomId;
    }).toList();

    int completedSessions = 0;
    int seatedHours = 0;
    int noShows = 0;
    final softwareDemand = <String, int>{};
    final roomBreakdown = <String, int>{
      for (final r in targetRooms) r.code: 0,
    };

    for (final b in relevantBookings) {
      if (b.status == BookingStatus.completed ||
          b.status == BookingStatus.checkedIn) {
        completedSessions++;
        seatedHours += b.durationHours;
        softwareDemand[b.courseworkTag] =
            (softwareDemand[b.courseworkTag] ?? 0) + 1;
        final roomCode = state.rooms
            .firstWhere((r) => r.id == b.roomId, orElse: () => state.rooms.first)
            .code;
        roomBreakdown[roomCode] = (roomBreakdown[roomCode] ?? 0) + b.durationHours;
      } else if (b.status == BookingStatus.noShowCancelled) {
        noShows++;
      }
    }

    final totalStationsCount = targetRooms.fold<int>(
      0,
      (sum, r) =>
          sum + state.stations.where((s) => s.roomId == r.id).length,
    );
    final availableRoomHours =
        (totalStationsCount * 8).clamp(8, 10000); // 8 hrs/day baseline
    final utilizationPercent =
        ((seatedHours / availableRoomHours) * 100).clamp(4.0, 98.0);

    final resolvedTickets =
        relevantTickets.where((t) => t.isResolved).toList();
    double avgRepairHours = 2.0;
    if (resolvedTickets.isNotEmpty) {
      final totalMinutes = resolvedTickets.fold<int>(0, (sum, t) {
        final end = t.resolvedAt ?? DateTime.now();
        return sum + end.difference(t.createdAt).inMinutes.abs();
      });
      avgRepairHours = (totalMinutes / resolvedTickets.length) / 60.0;
    }

    final scopeTitle = roomId == null || roomId == 'ALL'
        ? 'All Campus Computer Laboratories'
        : targetRooms.first.name;

    return AccreditationReport(
      scopeTitle: scopeTitle,
      startDate: startDate,
      endDate: endDate,
      totalSessionsCompleted: completedSessions,
      totalSeatedHours: seatedHours,
      totalAvailableRoomHours: availableRoomHours,
      utilizationRatePercent: utilizationPercent,
      totalNoShowsAutoReleased: noShows,
      totalDefectsReported: relevantTickets.length,
      totalDefectsResolved: resolvedTickets.length,
      averageRepairTurnaroundHours: avgRepairHours,
      softwareDemandCounts: softwareDemand,
      roomSessionBreakdown: roomBreakdown,
    );
  }
}

final labSlotProvider = NotifierProvider<LabSlotController, LabSlotState>(
  LabSlotController.new,
);
