import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labslot/core/models/labslot_models.dart';
import 'package:labslot/core/providers/labslot_controller.dart';
import 'package:labslot/main.dart';

void main() {
  group('LabSlot System Use Cases & RBAC Controller Tests', () {
    late ProviderContainer container;
    late LabSlotController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(labSlotProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('UC1 & UC2: Student filters PC stations and reserves an available slot', () {
      // Logged in by default as Marco Santos (usr-student-1, 0 strikes)
      final initialState = container.read(labSlotProvider);
      expect(initialState.currentUser?.id, 'usr-student-1');

      // Filter by AutoCAD 2025 in ComLab 3 (room-comlab-3)
      controller.selectRoom('room-comlab-3');
      controller.toggleSoftwareFilter('AutoCAD 2025');
      final filteredStations = container
          .read(labSlotProvider)
          .stationsForRoom('room-comlab-3');
      expect(filteredStations.isNotEmpty, isTrue);
      expect(
        filteredStations.every(
          (pc) => pc.installedSoftware.contains('AutoCAD 2025'),
        ),
        isTrue,
      );

      // Reserve PC-01 in ComLab 3
      final result = controller.reservePcStationSlot(
        stationId: 'st-c3-1',
        durationHours: 2,
        courseworkTag: 'AutoCAD 2025',
      );
      expect(result.success, isTrue);

      final activeBooking = container
          .read(labSlotProvider)
          .activeBookingForCurrentUser;
      expect(activeBooking, isNotNull);
      expect(activeBooking?.qrAuthCode, startsWith('LS-'));

      // Attempting a second active reservation is blocked (One-Active-Booking validation)
      final duplicateAttempt = controller.reservePcStationSlot(
        stationId: 'st-c3-2',
        durationHours: 1,
        courseworkTag: 'Flutter',
      );
      expect(duplicateAttempt.success, isFalse);
    });

    test('UC2 Include Validation: 3-strike student is restricted from advance booking', () {
      // Switch to Kevin Lim (usr-student-3) who has 3/3 strikes
      controller.loginAsDemoUser('usr-student-3');
      expect(container.read(labSlotProvider).currentUser?.strikeCount, 3);

      final result = controller.reservePcStationSlot(
        stationId: 'st-c3-1',
        durationHours: 1,
        courseworkTag: 'Flutter',
      );
      expect(result.success, isFalse);
      expect(result.message, contains('3-strike'));
    });

    test('UC3: 10-minute grace period expiry releases ghost reservation and adds 1 strike', () {
      controller.loginAsDemoUser('usr-student-1');
      final initialStrikes =
          container.read(labSlotProvider).currentUser!.strikeCount;

      final res = controller.reservePcStationSlot(
        stationId: 'st-c3-1',
        durationHours: 1,
        courseworkTag: 'Flutter',
      );
      expect(res.success, isTrue);
      final bookingId =
          container.read(labSlotProvider).activeBookingForCurrentUser!.id;

      // Simulate 10-minute grace period expiration
      final expiryRes = controller.triggerGhostSlotAutoRelease(bookingId);
      expect(expiryRes.success, isTrue);
      expect(
        container.read(labSlotProvider).activeBookingForCurrentUser,
        isNull,
      );
      expect(
        container.read(labSlotProvider).currentUser!.strikeCount,
        initialStrikes + 1,
      );
    });

    test('UC6 & UC7: Custodian checks in student with ID escrow bin and checks out', () {
      // Student Marco books PC-01
      controller.loginAsDemoUser('usr-student-1');
      controller.reservePcStationSlot(
        stationId: 'st-c3-1',
        durationHours: 1,
        courseworkTag: 'Flutter',
      );
      final booking =
          container.read(labSlotProvider).activeBookingForCurrentUser!;

      // Switch to Custodian Ramon (usr-custodian-1)
      controller.loginAsDemoUser('usr-custodian-1');

      // Validation error when ID slot bin is empty
      final emptyBinAttempt = controller.processStudentCheckIn(
        bookingId: booking.id,
        idBinLocation: '   ',
      );
      expect(emptyBinAttempt.success, isFalse);

      // Valid check-in with Tray Bin-09
      final checkInRes = controller.processStudentCheckIn(
        bookingId: booking.id,
        idBinLocation: 'Bin-09',
      );
      expect(checkInRes.success, isTrue);

      final updatedBooking = container
          .read(labSlotProvider)
          .bookings
          .firstWhere((b) => b.id == booking.id);
      expect(updatedBooking.status, BookingStatus.checkedIn);
      expect(updatedBooking.idHeld, isTrue);
      expect(updatedBooking.idBinLocation, 'Bin-09');

      // Check Out & Return ID
      final checkOutRes = controller.processStudentCheckOut(booking.id);
      expect(checkOutRes.success, isTrue);

      final completedBooking = container
          .read(labSlotProvider)
          .bookings
          .firstWhere((b) => b.id == booking.id);
      expect(completedBooking.status, BookingStatus.completed);
      expect(completedBooking.idHeld, isFalse);
    });

    test('UC4 & UC9: Defective PC report quarantines station and traces last user', () {
      controller.loginAsDemoUser('usr-student-1');
      final reportRes = controller.reportDefectivePcStation(
        stationId: 'st-c3-2',
        issueCategory: 'No Network / Internet',
        description: 'Ethernet cable unplugged or port dead',
      );
      expect(reportRes.success, isTrue);

      final station = container
          .read(labSlotProvider)
          .stations
          .firstWhere((s) => s.id == 'st-c3-2');
      expect(station.status, PcStatus.maintenance);

      // Duplicate open ticket on same station is blocked
      final duplicateTicket = controller.reportDefectivePcStation(
        stationId: 'st-c3-2',
        issueCategory: 'Broken Mouse / Peripheral',
        description: 'Left click stuck',
      );
      expect(duplicateTicket.success, isFalse);
    });

    test('UC11, UC12 & UC13: Administrator manages inventory, resets strikes, and generates report', () {
      controller.loginAsDemoUser('usr-admin-1');

      // Reset Kevin Lim's 3 strikes
      final resetRes = controller.resetOrAdjustStudentStrikes(
        'usr-student-3',
        0,
      );
      expect(resetRes.success, isTrue);
      final kevin = container
          .read(labSlotProvider)
          .users
          .firstWhere((u) => u.id == 'usr-student-3');
      expect(kevin.strikeCount, 0);
      expect(kevin.isSuspended, isFalse);

      // Generate Accreditation Report
      final report = controller.generateAccreditationReport(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      expect(report.totalSeatedHours, greaterThanOrEqualTo(0));
      expect(report.roomSessionBreakdown.isNotEmpty, isTrue);
    });
  });

  testWidgets('LabSlotApp boots and displays RBAC shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LabSlotApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Default logged in user is Student Marco Santos in LabSlotShell
    expect(find.text('LabSlot'), findsOneWidget);
    expect(find.text('Live Labs & PCs'), findsOneWidget);
  });
}
