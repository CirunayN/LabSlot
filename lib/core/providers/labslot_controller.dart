import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final List<AuditLog> auditLogs;
  final String selectedRoomId;
  final Set<String> selectedSoftwareFilters;
  final int minimumRamFilterGb;
  final bool onlyAvailableFilter;
  final bool isSyncing;

  const LabSlotState({
    required this.currentUser,
    required this.users,
    required this.rooms,
    required this.stations,
    required this.bookings,
    required this.maintenanceTickets,
    required this.chatMessages,
    required this.auditLogs,
    required this.selectedRoomId,
    required this.selectedSoftwareFilters,
    this.minimumRamFilterGb = 0,
    this.onlyAvailableFilter = false,
    this.isSyncing = false,
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
    List<AuditLog>? auditLogs,
    String? selectedRoomId,
    Set<String>? selectedSoftwareFilters,
    int? minimumRamFilterGb,
    bool? onlyAvailableFilter,
    bool? isSyncing,
  }) {
    return LabSlotState(
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
      users: users ?? this.users,
      rooms: rooms ?? this.rooms,
      stations: stations ?? this.stations,
      bookings: bookings ?? this.bookings,
      maintenanceTickets: maintenanceTickets ?? this.maintenanceTickets,
      chatMessages: chatMessages ?? this.chatMessages,
      auditLogs: auditLogs ?? this.auditLogs,
      selectedRoomId: selectedRoomId ?? this.selectedRoomId,
      selectedSoftwareFilters:
          selectedSoftwareFilters ?? this.selectedSoftwareFilters,
      minimumRamFilterGb: minimumRamFilterGb ?? this.minimumRamFilterGb,
      onlyAvailableFilter: onlyAvailableFilter ?? this.onlyAvailableFilter,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  LabRoom? get selectedRoom {
    if (rooms.isEmpty) return null;
    for (final r in rooms) {
      if (r.id == selectedRoomId) return r;
    }
    return rooms.first;
  }

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

  static final RegExp _sixDigitStudentIdRegex = RegExp(r'^\d{6}$');

  // Used strictly when running offline unit/widget tests without Supabase
  final Map<String, String> _offlinePasswords = {};
  int _idSeq = 0;
  RealtimeChannel? _realtimeChannel;
  Timer? _syncDebounce;

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_idSeq}';

  @override
  LabSlotState build() {
    ref.onDispose(() {
      _syncDebounce?.cancel();
      final client = SupabaseConfig.clientOrNull;
      if (_realtimeChannel != null && client != null) {
        unawaited(client.removeChannel(_realtimeChannel!));
      }
    });

    if (SupabaseConfig.isLiveConnected) {
      Future.microtask(_bootstrapSupabaseSessionAndRealtime);
    }

    return const LabSlotState(
      currentUser: null,
      users: [],
      rooms: [],
      stations: [],
      bookings: [],
      maintenanceTickets: [],
      chatMessages: [],
      auditLogs: [],
      selectedRoomId: '',
      selectedSoftwareFilters: {},
    );
  }

  Future<void> _bootstrapSupabaseSessionAndRealtime() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null || !SupabaseConfig.isLiveConnected) return;

    _setupRealtimeSubscriptions(client);
    await syncFromSupabase();

    // Restore persisted Supabase Auth session if a user is already logged in
    final authUser = client.auth.currentUser;
    if (authUser != null && state.currentUser == null) {
      try {
        final profileMap = await client
            .from('profiles')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();
        if (profileMap != null) {
          final profile = UserProfile.fromMap(profileMap);
          state = state.copyWith(
            currentUser: profile,
            users: state.users.any((u) => u.id == profile.id)
                ? state.users
                : [profile, ...state.users],
          );
        }
      } catch (_) {
        // Stay on login screen if profile fetch fails
      }
    }
  }

  void _setupRealtimeSubscriptions(SupabaseClient client) {
    if (_realtimeChannel != null) return;
    final channel = client.channel('labslot-realtime');
    const tables = [
      'profiles',
      'lab_rooms',
      'pc_stations',
      'bookings',
      'maintenance_tickets',
      'chat_messages',
      'audit_logs',
    ];
    for (final table in tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _scheduleRealtimeSync(),
      );
    }
    _realtimeChannel = channel.subscribe();
  }

  void _scheduleRealtimeSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(syncFromSupabase());
    });
  }

  void _syncToCloud(Future<void> Function(SupabaseClient client) task) {
    final client = SupabaseConfig.clientOrNull;
    if (client == null || !SupabaseConfig.isLiveConnected) return;
    unawaited(
      task(client).catchError((_) {
        // Optimistic UI remains responsive; realtime/sync will reconcile
      }),
    );
  }

  void _recordAuditLog({
    required String action,
    required String details,
    UserProfile? explicitActor,
  }) {
    final actor = explicitActor ?? state.currentUser;
    final entry = AuditLog(
      id: _nextId('aud'),
      actorId: actor?.id,
      actorName: actor?.fullName ?? 'System',
      actorRole: actor?.role.dbValue ?? 'system',
      action: action,
      details: details,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(auditLogs: [entry, ...state.auditLogs]);
    _syncToCloud((client) async {
      await client.from('audit_logs').upsert(entry.toMap());
    });
  }

  Future<ActionResult> syncFromSupabase() async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null || !SupabaseConfig.isLiveConnected) {
      return const ActionResult.err('Supabase client is not initialized.');
    }

    state = state.copyWith(isSyncing: true);
    try {
      // Trigger server-side 10-minute ghost-slot auto-release RPC if installed
      try {
        await client.rpc('release_expired_ghost_slots');
      } catch (_) {}

      final results = await Future.wait([
        client.from('profiles').select().order('created_at', ascending: true),
        client.from('lab_rooms').select().order('code', ascending: true),
        client
            .from('pc_stations')
            .select()
            .order('station_number', ascending: true),
        client
            .from('bookings')
            .select()
            .order('scheduled_start', ascending: false),
        client
            .from('maintenance_tickets')
            .select()
            .order('created_at', ascending: false),
        client
            .from('chat_messages')
            .select()
            .order('created_at', ascending: true),
        client
            .from('audit_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(100),
      ]);

      final loadedUsers =
          (results[0] as List).map((m) => UserProfile.fromMap(m)).toList();
      final loadedRooms =
          (results[1] as List).map((m) => LabRoom.fromMap(m)).toList();
      final loadedStations =
          (results[2] as List).map((m) => PcStation.fromMap(m)).toList();
      final loadedBookings =
          (results[3] as List).map((m) => Booking.fromMap(m)).toList();
      final loadedTickets = (results[4] as List)
          .map((m) => MaintenanceTicket.fromMap(m))
          .toList();
      final loadedChats =
          (results[5] as List).map((m) => ChatMessage.fromMap(m)).toList();
      final loadedAudits =
          (results[6] as List).map((m) => AuditLog.fromMap(m)).toList();

      final currentId = state.currentUser?.id;
      UserProfile? updatedCurrent = state.currentUser;
      if (currentId != null) {
        final match = loadedUsers.where((u) => u.id == currentId);
        if (match.isNotEmpty) {
          updatedCurrent = match.first;
        }
      }

      String nextSelectedRoomId = state.selectedRoomId;
      if (loadedRooms.isEmpty) {
        nextSelectedRoomId = '';
      } else if (!loadedRooms.any((r) => r.id == nextSelectedRoomId)) {
        nextSelectedRoomId = loadedRooms.first.id;
      }

      state = state.copyWith(
        users: loadedUsers,
        rooms: loadedRooms,
        stations: loadedStations,
        bookings: loadedBookings,
        maintenanceTickets: loadedTickets,
        chatMessages: loadedChats,
        auditLogs: loadedAudits,
        currentUser: updatedCurrent,
        selectedRoomId: nextSelectedRoomId,
        isSyncing: false,
      );

      return const ActionResult.ok('Synced live data from Supabase.');
    } catch (e) {
      state = state.copyWith(isSyncing: false);
      return ActionResult.err('Sync failed: $e');
    }
  }

  // ===========================================================================
  // AUTH AND ROLE SWITCHING (Real Supabase Auth + 6-Digit Student ID Support)
  // ===========================================================================
  void switchActiveAccount(String userId) {
    final match = state.users.where((u) => u.id == userId);
    if (match.isEmpty) return;
    state = state.copyWith(currentUser: match.first);
  }

  Future<ActionResult> signInWithCredentials({
    required String identifier,
    required String password,
  }) async {
    final trimmedInput = identifier.trim();
    if (trimmedInput.isEmpty || password.isEmpty) {
      return const ActionResult.err(
        'Please enter your Email or 6-Digit Student ID and password.',
      );
    }

    String resolvedEmail = trimmedInput.toLowerCase();
    final isSixDigitId = _sixDigitStudentIdRegex.hasMatch(trimmedInput);

    if (SupabaseConfig.isLiveConnected) {
      final client = SupabaseConfig.clientOrNull!;
      try {
        if (isSixDigitId) {
          final profileById = await client
              .from('profiles')
              .select('email')
              .eq('student_id_number', trimmedInput)
              .maybeSingle();
          if (profileById == null ||
              (profileById['email']?.toString().isEmpty ?? true)) {
            return ActionResult.err(
              'No student account found with Student ID "$trimmedInput".',
            );
          }
          resolvedEmail = profileById['email'].toString().trim().toLowerCase();
        }

        final res = await client.auth.signInWithPassword(
          email: resolvedEmail,
          password: password,
        );
        if (res.user == null) {
          return const ActionResult.err('Invalid login credentials.');
        }

        final profileMap = await client
            .from('profiles')
            .select()
            .eq('id', res.user!.id)
            .maybeSingle();

        final UserProfile profile;
        if (profileMap != null) {
          profile = UserProfile.fromMap(profileMap);
        } else {
          final meta = res.user!.userMetadata ?? const <String, dynamic>{};
          final metaRole =
              UserRole.fromString(meta['role']?.toString() ?? 'student');
          profile = UserProfile(
            id: res.user!.id,
            studentIdNumber: metaRole == UserRole.student
                ? meta['student_id_number']?.toString()
                : null,
            email: resolvedEmail,
            fullName: meta['full_name']?.toString() ??
                resolvedEmail.split('@').first,
            role: metaRole,
            courseDepartment:
                meta['course_department']?.toString() ?? 'Campus Department',
          );
          await client.from('profiles').upsert(profile.toMap());
        }

        state = state.copyWith(
          currentUser: profile,
          users: state.users.any((u) => u.id == profile.id)
              ? state.users
              : [profile, ...state.users],
        );
        await syncFromSupabase();
        return ActionResult.ok('Welcome back, ${profile.fullName}!');
      } on AuthException catch (e) {
        return ActionResult.err(e.message);
      } catch (e) {
        return ActionResult.err('Login failed: $e');
      }
    }

    // Offline unit-test mode (verifies real matching password)
    if (isSixDigitId) {
      final byId = state.users.where((u) => u.studentIdNumber == trimmedInput);
      if (byId.isEmpty) {
        return ActionResult.err(
          'No student account found with Student ID "$trimmedInput".',
        );
      }
      resolvedEmail = byId.first.email.toLowerCase();
    }

    final match = state.users.where(
      (u) => u.email.toLowerCase() == resolvedEmail,
    );
    if (match.isEmpty) {
      return const ActionResult.err('Invalid email/Student ID or password.');
    }
    final expectedPassword = _offlinePasswords[resolvedEmail];
    if (expectedPassword == null || expectedPassword != password) {
      return const ActionResult.err('Invalid email/Student ID or password.');
    }

    state = state.copyWith(currentUser: match.first);
    return ActionResult.ok('Welcome back, ${match.first.fullName}!');
  }

  Future<ActionResult> signUpWithCredentials({
    required String email,
    required String password,
    required String fullName,
    String? studentIdNumber,
    required String courseDepartment,
    required UserRole role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanIdNum = studentIdNumber?.trim();

    if (cleanName.isEmpty || cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return const ActionResult.err(
        'Please enter a valid full name and campus email address.',
      );
    }
    if (password.length < 6) {
      return const ActionResult.err(
        'Password must be at least 6 characters long.',
      );
    }

    if (role == UserRole.student) {
      if (cleanIdNum == null || !_sixDigitStudentIdRegex.hasMatch(cleanIdNum)) {
        return const ActionResult.err(
          'Student ID must be exactly 6 numeric digits (e.g., 123456).',
        );
      }
    }

    final effectiveStudentId = role == UserRole.student ? cleanIdNum : null;
    final cleanDept = courseDepartment.trim().isEmpty
        ? (role == UserRole.student
            ? 'BS Information Technology'
            : role == UserRole.custodian
                ? 'Campus Laboratory Services'
                : 'ITS Administration')
        : courseDepartment.trim();

    String newUserId = _nextId('usr');

    if (SupabaseConfig.isLiveConnected) {
      final client = SupabaseConfig.clientOrNull!;
      try {
        if (effectiveStudentId != null) {
          final existingId = await client
              .from('profiles')
              .select('id')
              .eq('student_id_number', effectiveStudentId)
              .maybeSingle();
          if (existingId != null) {
            return ActionResult.err(
              'Student ID "$effectiveStudentId" is already registered.',
            );
          }
        }

        final authRes = await client.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {
            'full_name': cleanName,
            'student_id_number': ?effectiveStudentId,
            'course_department': cleanDept,
            'role': role.dbValue,
          },
        );
        if (authRes.user == null) {
          return const ActionResult.err(
            'Could not complete registration. Please check your details.',
          );
        }
        newUserId = authRes.user!.id;

        final newProfile = UserProfile(
          id: newUserId,
          studentIdNumber: effectiveStudentId,
          email: cleanEmail,
          fullName: cleanName,
          role: role,
          courseDepartment: cleanDept,
        );

        await client.from('profiles').upsert(newProfile.toMap());

        state = state.copyWith(
          users: [
            newProfile,
            ...state.users.where((u) => u.id != newProfile.id),
          ],
          currentUser: newProfile,
        );
        _recordAuditLog(
          action: 'USER_REGISTERED',
          details: 'Registered ${newProfile.fullName} (${newProfile.role.label})',
          explicitActor: newProfile,
        );
        await syncFromSupabase();
        return ActionResult.ok(
          'Account created for ${newProfile.fullName} (${newProfile.role.label}).',
        );
      } on AuthException catch (e) {
        return ActionResult.err(e.message);
      } catch (e) {
        return ActionResult.err('Registration failed: $e');
      }
    }

    // Offline unit-test mode
    if (state.users.any((u) => u.email.toLowerCase() == cleanEmail)) {
      return const ActionResult.err('Email address is already registered.');
    }
    if (effectiveStudentId != null &&
        state.users.any((u) => u.studentIdNumber == effectiveStudentId)) {
      return ActionResult.err(
        'Student ID "$effectiveStudentId" is already registered.',
      );
    }

    final newProfile = UserProfile(
      id: newUserId,
      studentIdNumber: effectiveStudentId,
      email: cleanEmail,
      fullName: cleanName,
      role: role,
      courseDepartment: cleanDept,
    );

    _offlinePasswords[cleanEmail] = password;
    state = state.copyWith(
      users: [newProfile, ...state.users],
      currentUser: newProfile,
    );
    _recordAuditLog(
      action: 'USER_REGISTERED',
      details: 'Registered ${newProfile.fullName} (${newProfile.role.label})',
      explicitActor: newProfile,
    );

    return ActionResult.ok(
      'Account created for ${newProfile.fullName} (${newProfile.role.label}).',
    );
  }

  void signOut() {
    if (SupabaseConfig.isLiveConnected) {
      unawaited(SupabaseConfig.clientOrNull?.auth.signOut());
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

    // Validation 2: Duration 1-2 hours check
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
    final roomMatch = state.rooms.where((r) => r.id == station.roomId);
    if (roomMatch.isEmpty) {
      return const ActionResult.err('Laboratory room not found.');
    }
    final room = roomMatch.first;

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
        (1000 + now.microsecondsSinceEpoch % 8999).toString().padLeft(4, '0');
    final qrCode = 'LS-$codeSuffix-${station.stationNumber.replaceAll('-', '')}';

    final newBooking = Booking(
      id: _nextId('bk'),
      studentId: user.id,
      studentName: user.fullName,
      studentIdNumber: user.displayIdOrRole,
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

    final updatedStation = updatedStations[stationIndex];
    _syncToCloud((client) async {
      await client.from('profiles').upsert(user.toMap());
      await client.from('pc_stations').upsert(updatedStation.toMap());
      await client.from('bookings').upsert(newBooking.toMap());
    });

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

    final updatedBooking = updatedBookings[idx];
    final targetStation =
        updatedStations.where((s) => s.id == booking.stationId);
    _syncToCloud((client) async {
      await client.from('bookings').upsert(updatedBooking.toMap());
      if (targetStation.isNotEmpty) {
        await client.from('pc_stations').upsert(targetStation.first.toMap());
      }
    });

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
        ? updatedUsers.firstWhere(
            (u) => u.id == current.id,
            orElse: () => current,
          )
        : current;

    state = state.copyWith(
      bookings: updatedBookings,
      stations: updatedStations,
      users: updatedUsers,
      currentUser: updatedCurrent,
    );

    final expiredBooking = updatedBookings[idx];
    final releasedStation =
        updatedStations.where((s) => s.id == booking.stationId);
    final penalizedUser = updatedUsers.where((u) => u.id == booking.studentId);
    _syncToCloud((client) async {
      await client.from('bookings').upsert(expiredBooking.toMap());
      if (releasedStation.isNotEmpty) {
        await client.from('pc_stations').upsert(releasedStation.first.toMap());
      }
      if (penalizedUser.isNotEmpty) {
        await client.from('profiles').upsert(penalizedUser.first.toMap());
      }
    });

    return ActionResult.ok(
      '10-minute grace period expired: ${booking.stationNumber} auto-released to Available and +1 no-show strike recorded.',
    );
  }

  // ===========================================================================
  // STUDENT USE CASE 4 AND CUSTODIAN UC 9: Process Defective PC Station Report
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
        'Report not submitted: Please select a defect category and provide details.',
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

    // Protect another student's active Occupied session from unauthorized quarantine
    final activeOccupancy = state.bookings.where(
      (b) => b.stationId == stationId && b.status == BookingStatus.checkedIn,
    );
    if (activeOccupancy.isNotEmpty &&
        reporter.role == UserRole.student &&
        activeOccupancy.first.studentId != reporter.id) {
      return ActionResult.err(
        'Cannot quarantine ${station.stationNumber}: Another student is currently checked into this workstation.',
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
      id: _nextId('mt'),
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

    final quarantinedStation = updatedStations[stationIdx];
    _syncToCloud((client) async {
      await client.from('pc_stations').upsert(quarantinedStation.toMap());
      await client.from('maintenance_tickets').upsert(ticket.toMap());
    });
    _recordAuditLog(
      action: 'PC_QUARANTINED',
      details:
          '${station.stationNumber} in ${room.code} flagged for ${ticket.issueCategory}',
    );

    return ActionResult.ok(
      '${station.stationNumber} quarantined as Under Maintenance and queued for custodian inspection.',
    );
  }

  // ===========================================================================
  // STUDENT UC 5 AND CUSTODIAN UC 10: Relay and Manage Help Desk Messages
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
    if (state.rooms.isEmpty) {
      return const ActionResult.err(
        'No computer laboratories exist yet. Please ask an Admin to create a lab room first.',
      );
    }

    final activeBooking = state.activeBookingForCurrentUser;
    final room = targetRoomId != null
        ? state.rooms.firstWhere(
            (r) => r.id == targetRoomId,
            orElse: () => state.selectedRoom ?? state.rooms.first,
          )
        : (activeBooking != null
            ? state.rooms.firstWhere(
                (r) => r.id == activeBooking.roomId,
                orElse: () => state.rooms.first,
              )
            : (state.selectedRoom ?? state.rooms.first));

    final studentProfile = targetStudentId != null
        ? state.users.firstWhere(
            (u) => u.id == targetStudentId,
            orElse: () => sender,
          )
        : sender;

    final stationNum = targetStationNumber ??
        activeBooking?.stationNumber ??
        'Desk Inquiry';

    final msg = ChatMessage(
      id: _nextId('msg'),
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
      isResolved: false,
      createdAt: DateTime.now(),
    );

    // If student sends a new follow-up message, reopen thread if resolved
    final updatedChats = state.chatMessages.map((m) {
      if (sender.role == UserRole.student && m.studentId == studentProfile.id) {
        return m.copyWith(isResolved: false);
      }
      return m;
    }).toList();

    state = state.copyWith(chatMessages: [...updatedChats, msg]);
    _syncToCloud((client) async {
      await client.from('chat_messages').upsert(msg.toMap());
    });
    return const ActionResult.ok('Support message sent.');
  }

  ActionResult resolveHelpDeskThread(String studentId) {
    final updated = state.chatMessages.map((m) {
      if (m.studentId == studentId) {
        return m.copyWith(isResolved: true);
      }
      return m;
    }).toList();

    state = state.copyWith(chatMessages: updated);
    _syncToCloud((client) async {
      await client
          .from('chat_messages')
          .update({'is_resolved': true})
          .eq('student_id', studentId);
    });
    _recordAuditLog(
      action: 'CHAT_RESOLVED',
      details: 'Marked help desk thread resolved for student $studentId',
    );
    return const ActionResult.ok('Help desk thread marked as resolved.');
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

    final checkedInBooking = updatedBookings[idx];
    _syncToCloud((client) async {
      await client.from('bookings').upsert(checkedInBooking.toMap());
      if (stationIdx != -1) {
        await client
            .from('pc_stations')
            .upsert(updatedStations[stationIdx].toMap());
      }
    });
    _recordAuditLog(
      action: 'STUDENT_CHECK_IN',
      details:
          'Checked in ${booking.studentName} at ${booking.stationNumber} (ID held in $bin)',
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

    final completedBooking = updatedBookings[idx];
    final freedStation =
        updatedStations.where((s) => s.id == booking.stationId);
    _syncToCloud((client) async {
      await client.from('bookings').upsert(completedBooking.toMap());
      if (freedStation.isNotEmpty) {
        await client.from('pc_stations').upsert(freedStation.first.toMap());
      }
    });
    _recordAuditLog(
      action: 'STUDENT_CHECK_OUT',
      details:
          'Checked out ${booking.studentName} from ${booking.stationNumber} (Returned ID from $returnedBin)',
    );

    return ActionResult.ok(
      'Checked out ${booking.studentName}. Returned physical ID from $returnedBin and restored ${booking.stationNumber} to Available.',
    );
  }

  // ===========================================================================
  // CUSTODIAN USE CASE 8: Manage Laboratory Room Availability
  // Automatically cancels pending reservations (no strike) when closing room
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

    final cancelledBookings = <Booking>[];
    final affectedStationIds = <String>{};
    List<Booking> updatedBookings = state.bookings;
    List<PcStation> updatedStations = state.stations;

    if (newStatus != RoomStatus.open) {
      updatedBookings = state.bookings.map((b) {
        if (b.roomId == roomId && b.status == BookingStatus.reserved) {
          final cancelled = b.copyWith(status: BookingStatus.cancelled);
          cancelledBookings.add(cancelled);
          affectedStationIds.add(b.stationId);
          return cancelled;
        }
        return b;
      }).toList();

      if (affectedStationIds.isNotEmpty) {
        updatedStations = state.stations.map((s) {
          if (affectedStationIds.contains(s.id)) {
            return s.copyWith(
              status: s.isDefective ? PcStatus.maintenance : PcStatus.available,
            );
          }
          return s;
        }).toList();
      }
    }

    state = state.copyWith(
      rooms: updatedRooms,
      bookings: updatedBookings,
      stations: updatedStations,
    );

    final updatedRoom = updatedRooms[idx];
    final releasedStations = updatedStations
        .where((s) => affectedStationIds.contains(s.id))
        .toList();
    _syncToCloud((client) async {
      await client.from('lab_rooms').upsert(updatedRoom.toMap());
      if (cancelledBookings.isNotEmpty) {
        await client
            .from('bookings')
            .upsert(cancelledBookings.map((b) => b.toMap()).toList());
      }
      if (releasedStations.isNotEmpty) {
        await client
            .from('pc_stations')
            .upsert(releasedStations.map((s) => s.toMap()).toList());
      }
    });
    _recordAuditLog(
      action: 'ROOM_STATUS_CHANGED',
      details:
          '${updatedRoom.code} set to ${newStatus.label} (${updatedRoom.currentSubjectNote}); ${cancelledBookings.length} pending bookings released without penalty',
    );

    final suffix = cancelledBookings.isEmpty
        ? ''
        : ' Released ${cancelledBookings.length} pending reservation(s) with zero strike penalty.';
    return ActionResult.ok(
      'Updated ${updatedRooms[idx].code} status to "${newStatus.label}".$suffix',
    );
  }

  // ===========================================================================
  // CUSTODIAN USE CASE 9: Manage PC Station Maintenance Queue (Resolve)
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

    final resolvedTicket = updatedTickets[idx];
    final restoredStation =
        updatedStations.where((s) => s.id == ticket.stationId);
    _syncToCloud((client) async {
      await client.from('maintenance_tickets').upsert(resolvedTicket.toMap());
      if (restoredStation.isNotEmpty) {
        await client.from('pc_stations').upsert(restoredStation.first.toMap());
      }
    });
    _recordAuditLog(
      action: 'MAINTENANCE_RESOLVED',
      details:
          'Restored ${ticket.stationNumber} (${ticket.roomName}): ${repairNotes.trim()}',
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

    final newRoomId = _nextId('room');
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
      selectedRoomId:
          state.selectedRoomId.isEmpty ? newRoomId : state.selectedRoomId,
    );

    _syncToCloud((client) async {
      await client.from('lab_rooms').upsert(newRoom.toMap());
      await client
          .from('pc_stations')
          .upsert(newStations.map((s) => s.toMap()).toList());
    });
    _recordAuditLog(
      action: 'ROOM_CREATED',
      details: 'Created $cleanCode (${newRoom.name}) with $initialStationsCount stations',
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
    if (cpu.trim().isEmpty || gpu.trim().isEmpty) {
      return const ActionResult.err(
        'Please specify both CPU and GPU workstation specifications.',
      );
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
      final target = updatedStations[existingIdx];
      _syncToCloud((client) async {
        await client.from('pc_stations').upsert(target.toMap());
      });
      _recordAuditLog(
        action: 'PC_UPDATED',
        details: 'Updated specs for $cleanNumber in room $roomId',
      );
      return ActionResult.ok('Updated workstation specs for $cleanNumber.');
    } else {
      final newStation = PcStation(
        id: _nextId('st'),
        roomId: roomId,
        stationNumber: cleanNumber,
        status: PcStatus.available,
        cpu: cpu.trim(),
        ramGb: ramGb,
        gpu: gpu.trim(),
        installedSoftware: installedSoftware,
      );
      updatedStations.add(newStation);

      // Keep lab_rooms.totalCapacity synced with actual station count
      final roomStationsCount =
          updatedStations.where((s) => s.roomId == roomId).length;
      LabRoom? updatedRoom;
      final updatedRooms = state.rooms.map((r) {
        if (r.id == roomId) {
          updatedRoom = r.copyWith(totalCapacity: roomStationsCount);
          return updatedRoom!;
        }
        return r;
      }).toList();

      state = state.copyWith(rooms: updatedRooms, stations: updatedStations);
      _syncToCloud((client) async {
        await client.from('pc_stations').upsert(newStation.toMap());
        if (updatedRoom != null) {
          await client.from('lab_rooms').upsert(updatedRoom!.toMap());
        }
      });
      _recordAuditLog(
        action: 'PC_ADDED',
        details: 'Added workstation $cleanNumber to room $roomId',
      );
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
    updatedUsers[idx] = updatedUsers[idx].copyWith(
      role: newRole,
      clearStudentId: newRole != UserRole.student,
    );

    final current = state.currentUser;
    final updatedCurrent =
        current != null && current.id == userId ? updatedUsers[idx] : current;

    state = state.copyWith(
      users: updatedUsers,
      currentUser: updatedCurrent,
    );
    final targetUser = updatedUsers[idx];
    _syncToCloud((client) async {
      await client.from('profiles').upsert(targetUser.toMap());
    });
    _recordAuditLog(
      action: 'ROLE_UPDATED',
      details: 'Assigned role "${newRole.label}" to ${targetUser.fullName}',
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
    final targetUser = updatedUsers[idx];
    _syncToCloud((client) async {
      await client.from('profiles').upsert(targetUser.toMap());
    });
    _recordAuditLog(
      action: 'STRIKES_UPDATED',
      details:
          'Set ${targetUser.fullName} strikes to $clamped (${suspended ? "Suspended" : "Active"})',
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
    final normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    if (normalizedStart.isAfter(normalizedEnd)) {
      throw ArgumentError(
        'Cannot generate report: Invalid date range or zero laboratory utilization records found for the selected period.',
      );
    }

    final targetRooms = roomId == null || roomId == 'ALL'
        ? state.rooms
        : state.rooms.where((r) => r.id == roomId).toList();

    final relevantBookings = state.bookings.where((b) {
      final matchesRoom =
          roomId == null || roomId == 'ALL' || b.roomId == roomId;
      final inRange = !b.scheduledStart.isBefore(normalizedStart) &&
          !b.scheduledStart.isAfter(normalizedEnd);
      return matchesRoom && inRange;
    }).toList();

    final relevantTickets = state.maintenanceTickets.where((t) {
      final matchesRoom =
          roomId == null || roomId == 'ALL' || t.roomId == roomId;
      final inRange = !t.createdAt.isBefore(normalizedStart) &&
          !t.createdAt.isAfter(normalizedEnd);
      return matchesRoom && inRange;
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
        final roomMatch = state.rooms.where((r) => r.id == b.roomId);
        if (roomMatch.isNotEmpty) {
          final roomCode = roomMatch.first.code;
          roomBreakdown[roomCode] =
              (roomBreakdown[roomCode] ?? 0) + b.durationHours;
        }
      } else if (b.status == BookingStatus.noShowCancelled) {
        noShows++;
      }
    }

    final daysCount =
        (DateTime(endDate.year, endDate.month, endDate.day)
                .difference(normalizedStart)
                .inDays +
            1)
            .clamp(1, 3650);
    final totalStationsCount = targetRooms.fold<int>(
      0,
      (sum, r) =>
          sum + state.stations.where((s) => s.roomId == r.id).length,
    );
    final availableRoomHours = totalStationsCount * 8 * daysCount;
    final utilizationPercent = availableRoomHours == 0
        ? 0.0
        : ((seatedHours / availableRoomHours) * 100).clamp(0.0, 100.0);

    final resolvedTickets =
        relevantTickets.where((t) => t.isResolved).toList();
    double avgRepairHours = 0.0;
    if (resolvedTickets.isNotEmpty) {
      final totalMinutes = resolvedTickets.fold<int>(0, (sum, t) {
        final end = t.resolvedAt ?? DateTime.now();
        return sum + end.difference(t.createdAt).inMinutes.abs();
      });
      avgRepairHours = (totalMinutes / resolvedTickets.length) / 60.0;
    }

    final scopeTitle = roomId == null || roomId == 'ALL'
        ? 'All Campus Computer Laboratories'
        : (targetRooms.isNotEmpty ? targetRooms.first.name : 'Selected Lab');

    return AccreditationReport(
      scopeTitle: scopeTitle,
      startDate: normalizedStart,
      endDate: normalizedEnd,
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
      totalRecordsEvaluated:
          completedSessions + noShows + relevantTickets.length,
    );
  }

  void logReportExport(String format, AccreditationReport report) {
    _recordAuditLog(
      action: 'REPORT_EXPORTED_$format',
      details:
          'Exported $format compliance report for ${report.scopeTitle} (${report.totalSessionsCompleted} sessions, ${report.totalSeatedHours} hrs)',
    );
  }
}

final labSlotProvider = NotifierProvider<LabSlotController, LabSlotState>(
  LabSlotController.new,
);
