import 'package:flutter/material.dart';
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
      final initialState = container.read(labSlotProvider);
      expect(initialState.currentUser?.id, 'usr-student-1');

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

      final duplicateAttempt = controller.reservePcStationSlot(
        stationId: 'st-c3-2',
        durationHours: 1,
        courseworkTag: 'Flutter',
      );
      expect(duplicateAttempt.success, isFalse);
    });

    test('UC2 Include Validation: 3-strike student is restricted from advance booking', () {
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
      controller.loginAsDemoUser('usr-student-1');
      controller.reservePcStationSlot(
        stationId: 'st-c3-1',
        durationHours: 1,
        courseworkTag: 'Flutter',
      );
      final booking =
          container.read(labSlotProvider).activeBookingForCurrentUser!;

      controller.loginAsDemoUser('usr-custodian-1');

      final emptyBinAttempt = controller.processStudentCheckIn(
        bookingId: booking.id,
        idBinLocation: '   ',
      );
      expect(emptyBinAttempt.success, isFalse);

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

      final duplicateTicket = controller.reportDefectivePcStation(
        stationId: 'st-c3-2',
        issueCategory: 'Broken Mouse / Peripheral',
        description: 'Left click stuck',
      );
      expect(duplicateTicket.success, isFalse);
    });

    test('UC11, UC12 & UC13: Administrator manages inventory, resets strikes, and generates report', () {
      controller.loginAsDemoUser('usr-admin-1');

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

      final report = controller.generateAccreditationReport(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      expect(report.totalSeatedHours, greaterThanOrEqualTo(0));
      expect(report.roomSessionBreakdown.isNotEmpty, isTrue);
    });
  });

  testWidgets('LabSlotApp boots with clean header, no Supabase Live text, and quick actor menu',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LabSlotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LabSlot'), findsOneWidget);
    expect(find.text('Marco Santos'), findsOneWidget);
    expect(find.text('Supabase Live'), findsNothing);
    expect(find.text('Realtime Store'), findsNothing);
    expect(find.byKey(const Key('actor-switcher-menu')), findsOneWidget);
    expect(find.text('Live Labs & PCs'), findsOneWidget);

    // Sign out to verify Login & Register screens
    await tester.tap(find.byKey(const Key('sign-out-button')));
    await tester.pumpAndSettle();

    // Quick Actor Switcher card and Supabase Cloud text are removed on login
    expect(find.text('Quick Actor Switcher (RBAC Testing)'), findsNothing);
    expect(find.text('Connected to Live Supabase Cloud'), findsNothing);

    // Email & Password fields start empty
    final emailField = tester.widget<TextField>(
      find.byKey(const Key('login-email-field')),
    );
    final passField = tester.widget<TextField>(
      find.byKey(const Key('login-password-field')),
    );
    expect(emailField.controller?.text, isEmpty);
    expect(passField.controller?.text, isEmpty);

    // Switch to Create Account (Register) mode and verify zero overflow + empty fields
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(
      find.byKey(const Key('signup-fullname-field')),
    );
    final idField = tester.widget<TextField>(
      find.byKey(const Key('signup-id-field')),
    );
    final deptField = tester.widget<TextField>(
      find.byKey(const Key('signup-department-field')),
    );
    expect(nameField.controller?.text, isEmpty);
    expect(idField.controller?.text, isEmpty);
    expect(deptField.controller?.text, isEmpty);
    expect(find.byKey(const Key('signup-role-dropdown')), findsOneWidget);
  });
}
