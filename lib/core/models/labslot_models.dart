enum UserRole {
  student('student', 'Student'),
  custodian('custodian', 'Laboratory Custodian'),
  admin('admin', 'System Administrator');

  final String dbValue;
  final String label;
  const UserRole(this.dbValue, this.label);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.dbValue == value.toLowerCase(),
      orElse: () => UserRole.student,
    );
  }
}

enum RoomStatus {
  open('open', 'Open Lab'),
  classInSession('class_in_session', 'Class in Session'),
  closed('closed', 'Closed');

  final String dbValue;
  final String label;
  const RoomStatus(this.dbValue, this.label);

  static RoomStatus fromString(String value) {
    return RoomStatus.values.firstWhere(
      (s) => s.dbValue == value.toLowerCase(),
      orElse: () => RoomStatus.open,
    );
  }
}

enum PcStatus {
  available('available', 'Available'),
  reserved('reserved', 'Reserved'),
  occupied('occupied', 'Occupied'),
  maintenance('maintenance', 'Under Maintenance');

  final String dbValue;
  final String label;
  const PcStatus(this.dbValue, this.label);

  static PcStatus fromString(String value) {
    return PcStatus.values.firstWhere(
      (s) => s.dbValue == value.toLowerCase(),
      orElse: () => PcStatus.available,
    );
  }
}

enum BookingStatus {
  reserved('reserved', 'Reserved (Pending Check-In)'),
  checkedIn('checked_in', 'Checked In (Active)'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShowCancelled('no_show_cancelled', 'Expired (No-Show Auto-Released)');

  final String dbValue;
  final String label;
  const BookingStatus(this.dbValue, this.label);

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (s) => s.dbValue == value.toLowerCase(),
      orElse: () => BookingStatus.reserved,
    );
  }
}

class UserProfile {
  final String id;
  final String studentIdNumber;
  final String email;
  final String fullName;
  final UserRole role;
  final String courseDepartment;
  final int strikeCount;
  final bool isSuspended;

  const UserProfile({
    required this.id,
    required this.studentIdNumber,
    required this.email,
    required this.fullName,
    required this.role,
    required this.courseDepartment,
    this.strikeCount = 0,
    this.isSuspended = false,
  });

  UserProfile copyWith({
    String? id,
    String? studentIdNumber,
    String? email,
    String? fullName,
    UserRole? role,
    String? courseDepartment,
    int? strikeCount,
    bool? isSuspended,
  }) {
    return UserProfile(
      id: id ?? this.id,
      studentIdNumber: studentIdNumber ?? this.studentIdNumber,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      courseDepartment: courseDepartment ?? this.courseDepartment,
      strikeCount: strikeCount ?? this.strikeCount,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final strikes = (map['strike_count'] as num?)?.toInt() ?? 0;
    return UserProfile(
      id: map['id']?.toString() ?? '',
      studentIdNumber: map['student_id_number']?.toString() ?? 'STU-0000',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'LabSlot User',
      role: UserRole.fromString(map['role']?.toString() ?? 'student'),
      courseDepartment:
          map['course_department']?.toString() ?? 'BS Information Technology',
      strikeCount: strikes,
      isSuspended: (map['is_suspended'] as bool?) ?? (strikes >= 3),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id_number': studentIdNumber,
        'email': email,
        'full_name': fullName,
        'role': role.dbValue,
        'course_department': courseDepartment,
        'strike_count': strikeCount,
        'is_suspended': isSuspended,
      };
}

class LabRoom {
  final String id;
  final String code;
  final String name;
  final String buildingFloor;
  final RoomStatus status;
  final int totalCapacity;
  final String openTime;
  final String closeTime;
  final String currentSubjectNote;

  const LabRoom({
    required this.id,
    required this.code,
    required this.name,
    required this.buildingFloor,
    required this.status,
    required this.totalCapacity,
    this.openTime = '07:30',
    this.closeTime = '19:00',
    this.currentSubjectNote = 'Open for student reservations',
  });

  LabRoom copyWith({
    String? id,
    String? code,
    String? name,
    String? buildingFloor,
    RoomStatus? status,
    int? totalCapacity,
    String? openTime,
    String? closeTime,
    String? currentSubjectNote,
  }) {
    return LabRoom(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      buildingFloor: buildingFloor ?? this.buildingFloor,
      status: status ?? this.status,
      totalCapacity: totalCapacity ?? this.totalCapacity,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      currentSubjectNote: currentSubjectNote ?? this.currentSubjectNote,
    );
  }

  factory LabRoom.fromMap(Map<String, dynamic> map) {
    return LabRoom(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? 'COMLAB',
      name: map['name']?.toString() ?? 'Computer Lab',
      buildingFloor: map['building_floor']?.toString() ?? 'IT Building',
      status: RoomStatus.fromString(map['status']?.toString() ?? 'open'),
      totalCapacity: (map['total_capacity'] as num?)?.toInt() ?? 12,
      openTime: map['open_time']?.toString() ?? '07:30',
      closeTime: map['close_time']?.toString() ?? '19:00',
      currentSubjectNote:
          map['current_subject_note']?.toString() ?? 'Open Lab Session',
    );
  }
}

class PcStation {
  final String id;
  final String roomId;
  final String stationNumber;
  final PcStatus status;
  final String cpu;
  final int ramGb;
  final String gpu;
  final List<String> installedSoftware;
  final bool isDefective;
  final String? defectCategory;
  final String? defectNotes;

  const PcStation({
    required this.id,
    required this.roomId,
    required this.stationNumber,
    required this.status,
    this.cpu = 'Intel Core i7-13700',
    this.ramGb = 16,
    this.gpu = 'NVIDIA RTX 3060 12GB',
    required this.installedSoftware,
    this.isDefective = false,
    this.defectCategory,
    this.defectNotes,
  });

  PcStation copyWith({
    String? id,
    String? roomId,
    String? stationNumber,
    PcStatus? status,
    String? cpu,
    int? ramGb,
    String? gpu,
    List<String>? installedSoftware,
    bool? isDefective,
    String? defectCategory,
    String? defectNotes,
  }) {
    return PcStation(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      stationNumber: stationNumber ?? this.stationNumber,
      status: status ?? this.status,
      cpu: cpu ?? this.cpu,
      ramGb: ramGb ?? this.ramGb,
      gpu: gpu ?? this.gpu,
      installedSoftware: installedSoftware ?? this.installedSoftware,
      isDefective: isDefective ?? this.isDefective,
      defectCategory: defectCategory,
      defectNotes: defectNotes,
    );
  }

  factory PcStation.fromMap(Map<String, dynamic> map) {
    final rawSoftware = map['installed_software'];
    final softwareList = rawSoftware is List
        ? rawSoftware.map((e) => e.toString()).toList()
        : <String>['Flutter', 'VS Code'];
    return PcStation(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      stationNumber: map['station_number']?.toString() ?? 'PC-01',
      status: PcStatus.fromString(map['status']?.toString() ?? 'available'),
      cpu: map['cpu']?.toString() ?? 'Intel Core i7-13700',
      ramGb: (map['ram_gb'] as num?)?.toInt() ?? 16,
      gpu: map['gpu']?.toString() ?? 'NVIDIA RTX 3060',
      installedSoftware: softwareList,
      isDefective: (map['is_defective'] as bool?) ?? false,
      defectCategory: map['defect_category']?.toString(),
      defectNotes: map['defect_notes']?.toString(),
    );
  }
}

class Booking {
  final String id;
  final String studentId;
  final String studentName;
  final String studentIdNumber;
  final String roomId;
  final String roomName;
  final String stationId;
  final String stationNumber;
  final String courseworkTag;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int durationHours;
  final DateTime gracePeriodDeadline;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final BookingStatus status;
  final bool idHeld;
  final String? idBinLocation;
  final String qrAuthCode;

  const Booking({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentIdNumber,
    required this.roomId,
    required this.roomName,
    required this.stationId,
    required this.stationNumber,
    required this.courseworkTag,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.durationHours,
    required this.gracePeriodDeadline,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.idHeld = false,
    this.idBinLocation,
    required this.qrAuthCode,
  });

  bool get isActive =>
      status == BookingStatus.reserved || status == BookingStatus.checkedIn;

  bool isGracePeriodExpired(DateTime now) =>
      status == BookingStatus.reserved && now.isAfter(gracePeriodDeadline);

  Booking copyWith({
    DateTime? gracePeriodDeadline,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    BookingStatus? status,
    bool? idHeld,
    String? idBinLocation,
  }) {
    return Booking(
      id: id,
      studentId: studentId,
      studentName: studentName,
      studentIdNumber: studentIdNumber,
      roomId: roomId,
      roomName: roomName,
      stationId: stationId,
      stationNumber: stationNumber,
      courseworkTag: courseworkTag,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      durationHours: durationHours,
      gracePeriodDeadline: gracePeriodDeadline ?? this.gracePeriodDeadline,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      status: status ?? this.status,
      idHeld: idHeld ?? this.idHeld,
      idBinLocation: idBinLocation ?? this.idBinLocation,
      qrAuthCode: qrAuthCode,
    );
  }
}

class MaintenanceTicket {
  final String id;
  final String roomId;
  final String roomName;
  final String stationId;
  final String stationNumber;
  final String reportedById;
  final String reportedByName;
  final String? lastUserId;
  final String? lastUserName;
  final String issueCategory;
  final String description;
  final bool isResolved;
  final String? repairNotes;
  final String? resolvedByName;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const MaintenanceTicket({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.stationId,
    required this.stationNumber,
    required this.reportedById,
    required this.reportedByName,
    this.lastUserId,
    this.lastUserName,
    required this.issueCategory,
    required this.description,
    this.isResolved = false,
    this.repairNotes,
    this.resolvedByName,
    required this.createdAt,
    this.resolvedAt,
  });

  MaintenanceTicket copyWith({
    bool? isResolved,
    String? repairNotes,
    String? resolvedByName,
    DateTime? resolvedAt,
  }) {
    return MaintenanceTicket(
      id: id,
      roomId: roomId,
      roomName: roomName,
      stationId: stationId,
      stationNumber: stationNumber,
      reportedById: reportedById,
      reportedByName: reportedByName,
      lastUserId: lastUserId,
      lastUserName: lastUserName,
      issueCategory: issueCategory,
      description: description,
      isResolved: isResolved ?? this.isResolved,
      repairNotes: repairNotes ?? this.repairNotes,
      resolvedByName: resolvedByName ?? this.resolvedByName,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class ChatMessage {
  final String id;
  final String? bookingId;
  final String roomId;
  final String roomName;
  final String stationNumber;
  final String studentId;
  final String studentName;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final String message;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    this.bookingId,
    required this.roomId,
    required this.roomName,
    required this.stationNumber,
    required this.studentId,
    required this.studentName,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });
}

class AccreditationReport {
  final String scopeTitle;
  final DateTime startDate;
  final DateTime endDate;
  final int totalSessionsCompleted;
  final int totalSeatedHours;
  final int totalAvailableRoomHours;
  final double utilizationRatePercent;
  final int totalNoShowsAutoReleased;
  final int totalDefectsReported;
  final int totalDefectsResolved;
  final double averageRepairTurnaroundHours;
  final Map<String, int> softwareDemandCounts;
  final Map<String, int> roomSessionBreakdown;

  const AccreditationReport({
    required this.scopeTitle,
    required this.startDate,
    required this.endDate,
    required this.totalSessionsCompleted,
    required this.totalSeatedHours,
    required this.totalAvailableRoomHours,
    required this.utilizationRatePercent,
    required this.totalNoShowsAutoReleased,
    required this.totalDefectsReported,
    required this.totalDefectsResolved,
    required this.averageRepairTurnaroundHours,
    required this.softwareDemandCounts,
    required this.roomSessionBreakdown,
  });
}
