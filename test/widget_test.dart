import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labslot/core/models/labslot_models.dart';
import 'package:labslot/core/providers/labslot_controller.dart';
import 'package:labslot/main.dart';

void main() {
  group('LabSlot Clean Database & RBAC System Use Case Tests', () {
    late ProviderContainer container;
    late LabSlotController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(labSlotProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('Auth: Starts empty, enforces 6-digit student ID, rejects wrong password, allows ID login', () async {
      // Zero hardcoded seed data at startup
      final startState = container.read(labSlotProvider);
      expect(startState.currentUser, isNull);
      expect(startState.users, isEmpty);
      expect(startState.rooms, isEmpty);

      // Student registration rejects non-6-digit ID
      final badIdRes = await controller.signUpWithCredentials(
        email: 'marco@campus.edu.ph',
        password: 'password123',
        fullName: 'Marco Santos',
        studentIdNumber: '12345',
        courseDepartment: 'BSIT',
        role: UserRole.student,
      );
      expect(badIdRes.success, isFalse);

      // Student registration succeeds with valid 6-digit ID
      final studentSignUp = await controller.signUpWithCredentials(
        email: 'marco@campus.edu.ph',
        password: 'password123',
        fullName: 'Marco Santos',
        studentIdNumber: '543210',
        courseDepartment: 'BSIT',
        role: UserRole.student,
      );
      expect(studentSignUp.success, isTrue);
      expect(container.read(labSlotProvider).currentUser?.studentIdNumber, '543210');

      // Custodian & Admin register without needing any ID
      final custodianSignUp = await controller.signUpWithCredentials(
        email: 'custodian@campus.edu.ph',
        password: 'password123',
        fullName: 'Engr. Ramon',
        studentIdNumber: null,
        courseDepartment: 'Lab Services',
        role: UserRole.custodian,
      );
      expect(custodianSignUp.success, isTrue);
      expect(container.read(labSlotProvider).currentUser?.studentIdNumber, isNull);

      final adminSignUp = await controller.signUpWithCredentials(
        email: 'admin@campus.edu.ph',
        password: 'password123',
        fullName: 'Dr. Elena',
        studentIdNumber: null,
        courseDepartment: 'ITS Office',
        role: UserRole.admin,
      );
      expect(adminSignUp.success, isTrue);
      expect(container.read(labSlotProvider).currentUser?.studentIdNumber, isNull);

      // Sign out and verify wrong password is REJECTED (no bypass!)
      controller.signOut();
      expect(container.read(labSlotProvider).currentUser, isNull);

      final wrongPass = await controller.signInWithCredentials(
        identifier: '543210',
        password: 'wrongpassword',
      );
      expect(wrongPass.success, isFalse);
      expect(container.read(labSlotProvider).currentUser, isNull);

      // Login using 6-digit Student ID + matching password succeeds
      final idLogin = await controller.signInWithCredentials(
        identifier: '543210',
        password: 'password123',
      );
      expect(idLogin.success, isTrue);
      expect(container.read(labSlotProvider).currentUser?.fullName, 'Marco Santos');

      // Admin logs in using email without any student ID
      controller.signOut();
      final adminLogin = await controller.signInWithCredentials(
        identifier: 'admin@campus.edu.ph',
        password: 'password123',
      );
      expect(adminLogin.success, isTrue);
      expect(container.read(labSlotProvider).currentUser?.role, UserRole.admin);
    });

    test('Full End-to-End Flow: Admin Inventory -> Student Booking -> Custodian Escrow -> Maintenance -> Chat -> Reports', () async {
      // Register Admin, Custodian, and 2 Students
      await controller.signUpWithCredentials(
        email: 'admin@campus.edu.ph',
        password: 'password123',
        fullName: 'Dr. Elena',
        courseDepartment: 'ITS',
        role: UserRole.admin,
      );
      final adminId = container.read(labSlotProvider).currentUser!.id;

      await controller.signUpWithCredentials(
        email: 'custodian@campus.edu.ph',
        password: 'password123',
        fullName: 'Engr. Ramon',
        courseDepartment: 'Labs',
        role: UserRole.custodian,
      );
      final custodianId = container.read(labSlotProvider).currentUser!.id;

      await controller.signUpWithCredentials(
        email: 's1@campus.edu.ph',
        password: 'password123',
        fullName: 'Student One',
        studentIdNumber: '111111',
        courseDepartment: 'BSIT',
        role: UserRole.student,
      );
      final student1Id = container.read(labSlotProvider).currentUser!.id;

      await controller.signUpWithCredentials(
        email: 's2@campus.edu.ph',
        password: 'password123',
        fullName: 'Student Two',
        studentIdNumber: '222222',
        courseDepartment: 'BSCS',
        role: UserRole.student,
      );
      final student2Id = container.read(labSlotProvider).currentUser!.id;

      // 1. Admin creates COMLAB-1 with 3 PCs and adds PC-04 -> totalCapacity syncs to 4
      controller.switchActiveAccount(adminId);
      final roomRes = controller.addLabRoom(
        code: 'COMLAB-1',
        name: 'ComLab 1 - Programming Lab',
        buildingFloor: '3rd Floor, IT Building',
        initialStationsCount: 3,
      );
      expect(roomRes.success, isTrue);
      final roomId = container.read(labSlotProvider).rooms.first.id;

      final addPcRes = controller.addOrUpdatePcStation(
        roomId: roomId,
        stationNumber: 'PC-04',
        cpu: 'Intel Core i7-13700',
        ramGb: 32,
        gpu: 'NVIDIA RTX 3060',
        installedSoftware: const ['Flutter', 'Docker'],
      );
      expect(addPcRes.success, isTrue);
      expect(container.read(labSlotProvider).rooms.first.totalCapacity, 4);

      // 2. Empty report returns 0.0% utilization and hasRecords == false
      final emptyReport = controller.generateAccreditationReport(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      );
      expect(emptyReport.hasRecords, isFalse);
      expect(emptyReport.utilizationRatePercent, 0.0);
      expect(emptyReport.averageRepairTurnaroundHours, 0.0);

      // Invalid date range throws ArgumentError
      expect(
        () => controller.generateAccreditationReport(
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // 3. Student 1 books PC-01, Custodian checks in with Bin-07
      controller.switchActiveAccount(student1Id);
      final pc1 = container
          .read(labSlotProvider)
          .stations
          .firstWhere((s) => s.stationNumber == 'PC-01');
      final bookRes = controller.reservePcStationSlot(
        stationId: pc1.id,
        durationHours: 2,
        courseworkTag: 'Flutter',
      );
      expect(bookRes.success, isTrue);
      final booking1 =
          container.read(labSlotProvider).activeBookingForCurrentUser!;

      controller.switchActiveAccount(custodianId);
      final checkInRes = controller.processStudentCheckIn(
        bookingId: booking1.id,
        idBinLocation: 'Bin-07',
      );
      expect(checkInRes.success, isTrue);

      // Student 2 cannot sabotage/quarantine Student 1's currently occupied PC-01
      controller.switchActiveAccount(student2Id);
      final sabotageRes = controller.reportDefectivePcStation(
        stationId: pc1.id,
        issueCategory: 'Broken Mouse / Peripheral',
        description: 'Testing unauthorized quarantine',
      );
      expect(sabotageRes.success, isFalse);

      // Student 2 reserves PC-02, then Custodian closes room -> auto-cancels PC-02 with 0 strikes!
      final pc2 = container
          .read(labSlotProvider)
          .stations
          .firstWhere((s) => s.stationNumber == 'PC-02');
      controller.reservePcStationSlot(
        stationId: pc2.id,
        durationHours: 1,
        courseworkTag: 'VS Code',
      );
      controller.switchActiveAccount(custodianId);
      final closeRoomRes = controller.updateRoomAvailability(
        roomId: roomId,
        newStatus: RoomStatus.classInSession,
        subjectNote: 'IT-302 Make-up Class',
      );
      expect(closeRoomRes.success, isTrue);
      final s2AfterClose = container
          .read(labSlotProvider)
          .users
          .firstWhere((u) => u.id == student2Id);
      expect(s2AfterClose.strikeCount, 0);

      // Custodian checks out Student 1, flags PC-03 defective, resolves ticket
      final checkOutRes = controller.processStudentCheckOut(booking1.id);
      expect(checkOutRes.success, isTrue);

      final pc3 = container
          .read(labSlotProvider)
          .stations
          .firstWhere((s) => s.stationNumber == 'PC-03');
      final flagRes = controller.reportDefectivePcStation(
        stationId: pc3.id,
        issueCategory: 'No Network / Internet',
        description: 'Loose ethernet jack',
      );
      expect(flagRes.success, isTrue);
      final ticketId = container.read(labSlotProvider).maintenanceTickets.first.id;
      final resolveRes = controller.resolveMaintenanceTicket(
        ticketId: ticketId,
        repairNotes: 'Replaced RJ45 connector',
      );
      expect(resolveRes.success, isTrue);

      // Multi-student Help Desk Chat + Resolve Thread
      controller.switchActiveAccount(student1Id);
      controller.sendHelpDeskMessage(messageText: 'Question from Student 1');
      controller.switchActiveAccount(student2Id);
      controller.sendHelpDeskMessage(messageText: 'Question from Student 2');
      // No active booking -> defaults to Desk Inquiry (not PC-01!)
      expect(
        container.read(labSlotProvider).chatMessages.last.stationNumber,
        'Desk Inquiry',
      );

      controller.switchActiveAccount(custodianId);
      controller.resolveHelpDeskThread(student1Id);
      final s1Msgs = container
          .read(labSlotProvider)
          .chatMessages
          .where((m) => m.studentId == student1Id);
      final s2Msgs = container
          .read(labSlotProvider)
          .chatMessages
          .where((m) => m.studentId == student2Id);
      expect(s1Msgs.every((m) => m.isResolved), isTrue);
      expect(s2Msgs.every((m) => !m.isResolved), isTrue);

      // Report now has real records + audit logging
      controller.switchActiveAccount(adminId);
      final report = controller.generateAccreditationReport(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      );
      expect(report.hasRecords, isTrue);
      expect(report.totalSessionsCompleted, 1);
      expect(report.totalSeatedHours, 2);
      controller.logReportExport('PDF', report);
      expect(
        container
            .read(labSlotProvider)
            .auditLogs
            .any((a) => a.action == 'REPORT_EXPORTED_PDF'),
        isTrue,
      );
    });
  });

  testWidgets(
    'Starts on LoginScreen, handles 6-digit student ID visibility, and renders all tabs without overflow on 360x780 phone',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: LabSlotApp()));
      await tester.pumpAndSettle();

      // App starts on LoginScreen (no auto-logged-in hardcoded user)
      expect(find.byKey(const Key('login-email-field')), findsOneWidget);
      expect(find.byKey(const Key('login-password-field')), findsOneWidget);

      // Switch to Create Account: Student ID field is shown for Student
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-id-field')), findsOneWidget);

      // Switch Role to System Administrator -> Student ID field hides!
      await tester.tap(find.byKey(const Key('signup-role-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('System Administrator').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-id-field')), findsNothing);

      // Register System Administrator without needing an ID
      await tester.enterText(
        find.byKey(const Key('signup-fullname-field')),
        'Dr. Elena',
      );
      await tester.enterText(
        find.byKey(const Key('signup-email-field')),
        'admin@campus.edu.ph',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('sign-in-button')));
      await tester.pumpAndSettle();

      // Inside Admin LabSlotShell with Option A names (no '&')
      expect(find.text('LabSlot'), findsOneWidget);
      expect(find.text('Dr. Elena'), findsOneWidget);
      expect(find.text('Lab Inventory'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('CHED Reports'), findsOneWidget);

      // Create COMLAB-1 as Admin
      await tester.enterText(
        find.byKey(const Key('admin-room-code-field')),
        'COMLAB-1',
      );
      await tester.enterText(
        find.byKey(const Key('admin-room-capacity-field')),
        '4',
      );
      await tester.enterText(
        find.byKey(const Key('admin-room-name-field')),
        'ComLab 1 - Coding Lab',
      );
      await tester.ensureVisible(
        find.byKey(const Key('admin-create-room-button')),
      );
      await tester.tap(find.byKey(const Key('admin-create-room-button')));
      await tester.pumpAndSettle();

      // Check Users & CHED Reports tabs on 360px phone
      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHED Reports'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-validation-banner')), findsOneWidget);

      // Sign out and register Student with 6-digit ID
      await tester.tap(find.byKey(const Key('sign-out-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('signup-fullname-field')),
        'Marco Santos',
      );
      await tester.enterText(
        find.byKey(const Key('signup-id-field')),
        '543210',
      );
      await tester.enterText(
        find.byKey(const Key('signup-email-field')),
        'marco@campus.edu.ph',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('sign-in-button')));
      await tester.pumpAndSettle();

      // Inside Student view with Option A tabs: Labs, Booking Pass, Help Chat
      expect(find.text('Labs'), findsOneWidget);
      expect(find.text('Booking Pass'), findsOneWidget);
      expect(find.text('Help Chat'), findsOneWidget);

      // Book PC-01 and verify live ticking countdown timer on Booking Pass
      final pc1Card = find.text('PC-01');
      await tester.ensureVisible(pc1Card);
      await tester.tap(pc1Card);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grace-countdown-text')), findsOneWidget);

      // Send Help Chat message
      await tester.tap(find.text('Help Chat'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('student-chat-input')),
        'Need help with Flutter SDK',
      );
      await tester.tap(find.byKey(const Key('student-chat-send-button')));
      await tester.pumpAndSettle();

      // Sign out and register Custodian (without ID), check all 3 Custodian tabs
      await tester.tap(find.byKey(const Key('sign-out-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signup-role-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laboratory Custodian').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-id-field')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('signup-fullname-field')),
        'Engr. Ramon',
      );
      await tester.enterText(
        find.byKey(const Key('signup-email-field')),
        'custodian@campus.edu.ph',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('sign-in-button')));
      await tester.pumpAndSettle();

      // Inside Custodian view with Option A tabs: Check-In, Maintenance, Help Inbox
      expect(find.text('Check-In'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Help Inbox'), findsOneWidget);

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('custodian-flag-defect-button')),
      );
      await tester.tap(find.byKey(const Key('custodian-flag-defect-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Help Inbox'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resolve-chat-thread-button')), findsOneWidget);
    },
  );
}
