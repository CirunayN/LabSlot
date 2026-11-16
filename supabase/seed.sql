-- =============================================================================
-- LabSlot Complete Seed Data (Profiles, 4 Lab Rooms, 36 PCs, Bookings, Tickets, Chat)
-- Safe to run multiple times (ON CONFLICT DO UPDATE / DO NOTHING)
-- =============================================================================

-- 1. SEED RBAC PROFILES
INSERT INTO public.profiles (id, student_id_number, email, full_name, role, course_department, strike_count, is_suspended)
VALUES
    ('usr-student-1', '2024-01042', 'marco.santos@campus.edu.ph', 'Marco Santos', 'student', 'BS Information Technology (3rd Year)', 0, FALSE),
    ('usr-student-2', '2024-01889', 'angela.reyes@campus.edu.ph', 'Angela Reyes', 'student', 'BS Computer Science (2nd Year)', 1, FALSE),
    ('usr-student-3', '2023-00412', 'kevin.lim@campus.edu.ph', 'Kevin Lim', 'student', 'BS Multimedia Arts (4th Year)', 3, TRUE),
    ('usr-custodian-1', 'STAFF-201', 'custodian.lab@campus.edu.ph', 'Engr. Ramon Dela Cruz', 'custodian', 'Campus Laboratory Services', 0, FALSE),
    ('usr-admin-1', 'ADMIN-001', 'admin.its@campus.edu.ph', 'Dr. Elena Villanueva', 'admin', 'College of Computing & ITS Office', 0, FALSE)
ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    full_name = EXCLUDED.full_name,
    strike_count = EXCLUDED.strike_count,
    is_suspended = EXCLUDED.is_suspended;

-- 2. SEED 4 CAMPUS COMPUTER LABORATORIES
INSERT INTO public.lab_rooms (id, code, name, building_floor, status, total_capacity, open_time, close_time, current_subject_note)
VALUES
    ('room-comlab-1', 'COMLAB-1', 'ComLab 1 – Mobile & Full-Stack Lab', '3rd Floor, IT Building', 'open', 12, '07:30', '19:00', 'Open Lab for Vacant Period Coursework'),
    ('room-comlab-2', 'COMLAB-2', 'ComLab 2 – Cisco Networking Lab', '3rd Floor, IT Building', 'class_in_session', 8, '07:30', '19:00', 'IT-302 Network Routing Lecture in Session'),
    ('room-comlab-3', 'COMLAB-3', 'ComLab 3 – CAD & Multimedia Studio', '4th Floor, Engineering Wing', 'open', 8, '07:30', '19:00', 'Open Lab for 3D & CAD Rendering'),
    ('room-comlab-4', 'COMLAB-4', 'ComLab 4 – General Programming Lab', '2nd Floor, Main Academic Hall', 'closed', 8, '07:30', '19:00', 'Closed for Scheduled Switch Maintenance')
ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    current_subject_note = EXCLUDED.current_subject_note;

-- 3. SEED 36 PC STATIONS ACROSS COMLAB 1–4
INSERT INTO public.pc_stations (id, room_id, station_number, status, cpu, ram_gb, gpu, installed_software, is_defective, defect_category, defect_notes)
VALUES
    -- ComLab 1 (12 Stations)
    ('st-c1-1', 'room-comlab-1', 'PC-01', 'available', 'Intel Core i7-13700', 32, 'NVIDIA RTX 3060 12GB', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Docker', 'Cisco Packet Tracer'], FALSE, NULL, NULL),
    ('st-c1-2', 'room-comlab-1', 'PC-02', 'occupied', 'Intel Core i7-13700', 32, 'NVIDIA RTX 3060 12GB', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Cisco Packet Tracer'], FALSE, NULL, NULL),
    ('st-c1-3', 'room-comlab-1', 'PC-03', 'available', 'Intel Core i7-13700', 32, 'NVIDIA RTX 3060 12GB', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Docker', 'Cisco Packet Tracer'], FALSE, NULL, NULL),
    ('st-c1-4', 'room-comlab-1', 'PC-04', 'available', 'Intel Core i7-13700', 32, 'NVIDIA RTX 3060 12GB', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Cisco Packet Tracer'], FALSE, NULL, NULL),
    ('st-c1-5', 'room-comlab-1', 'PC-05', 'reserved', 'Intel Core i7-13700', 32, 'NVIDIA RTX 3060 12GB', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c1-6', 'room-comlab-1', 'PC-06', 'available', 'Intel Core i7-13700', 32, 'NVIDIA RTX 3060 12GB', ARRAY['Flutter', 'Android Studio', 'VS Code'], FALSE, NULL, NULL),
    ('st-c1-7', 'room-comlab-1', 'PC-07', 'available', 'AMD Ryzen 7 5800X', 32, 'NVIDIA GTX 1660 Super', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c1-8', 'room-comlab-1', 'PC-08', 'available', 'AMD Ryzen 7 5800X', 32, 'NVIDIA GTX 1660 Super', ARRAY['Flutter', 'Android Studio', 'VS Code'], FALSE, NULL, NULL),
    ('st-c1-9', 'room-comlab-1', 'PC-09', 'maintenance', 'AMD Ryzen 7 5800X', 16, 'NVIDIA GTX 1660 Super', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Docker'], TRUE, 'Broken Mouse / Peripheral', 'Left mouse button double-clicking; queued for swap'),
    ('st-c1-10', 'room-comlab-1', 'PC-10', 'available', 'AMD Ryzen 7 5800X', 16, 'NVIDIA GTX 1660 Super', ARRAY['Flutter', 'Android Studio', 'VS Code'], FALSE, NULL, NULL),
    ('st-c1-11', 'room-comlab-1', 'PC-11', 'available', 'AMD Ryzen 7 5800X', 16, 'NVIDIA GTX 1660 Super', ARRAY['Flutter', 'Android Studio', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c1-12', 'room-comlab-1', 'PC-12', 'available', 'AMD Ryzen 7 5800X', 16, 'NVIDIA GTX 1660 Super', ARRAY['Flutter', 'Android Studio', 'VS Code'], FALSE, NULL, NULL),

    -- ComLab 2 (8 Stations)
    ('st-c2-1', 'room-comlab-2', 'PC-01', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c2-2', 'room-comlab-2', 'PC-02', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c2-3', 'room-comlab-2', 'PC-03', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c2-4', 'room-comlab-2', 'PC-04', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c2-5', 'room-comlab-2', 'PC-05', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c2-6', 'room-comlab-2', 'PC-06', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c2-7', 'room-comlab-2', 'PC-07', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),
    ('st-c2-8', 'room-comlab-2', 'PC-08', 'available', 'Intel Core i5-12400', 16, 'Integrated UHD 730', ARRAY['Cisco Packet Tracer', 'VS Code', 'Docker'], FALSE, NULL, NULL),

    -- ComLab 3 (8 Stations)
    ('st-c3-1', 'room-comlab-3', 'PC-01', 'available', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c3-2', 'room-comlab-3', 'PC-02', 'available', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c3-3', 'room-comlab-3', 'PC-03', 'available', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c3-4', 'room-comlab-3', 'PC-04', 'maintenance', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], TRUE, 'No Network / Internet', 'LAN port loose at wall jack'),
    ('st-c3-5', 'room-comlab-3', 'PC-05', 'available', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c3-6', 'room-comlab-3', 'PC-06', 'available', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c3-7', 'room-comlab-3', 'PC-07', 'available', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c3-8', 'room-comlab-3', 'PC-08', 'available', 'Intel Core i9-13900K', 32, 'NVIDIA RTX 4070 12GB', ARRAY['AutoCAD 2025', 'Blender 3D', 'VS Code', 'Flutter'], FALSE, NULL, NULL),

    -- ComLab 4 (8 Stations)
    ('st-c4-1', 'room-comlab-4', 'PC-01', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c4-2', 'room-comlab-4', 'PC-02', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c4-3', 'room-comlab-4', 'PC-03', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c4-4', 'room-comlab-4', 'PC-04', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c4-5', 'room-comlab-4', 'PC-05', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c4-6', 'room-comlab-4', 'PC-06', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c4-7', 'room-comlab-4', 'PC-07', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL),
    ('st-c4-8', 'room-comlab-4', 'PC-08', 'available', 'Intel Core i5-12400', 16, 'Integrated Graphics', ARRAY['VS Code', 'Flutter'], FALSE, NULL, NULL)
ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    is_defective = EXCLUDED.is_defective,
    defect_category = EXCLUDED.defect_category,
    defect_notes = EXCLUDED.defect_notes;

-- 4. SEED INITIAL BOOKINGS (Active, Pending, and Historical for CHED Reports)
INSERT INTO public.bookings (id, student_id, student_name, student_id_number, room_id, room_name, station_id, station_number, coursework_tag, scheduled_start, scheduled_end, duration_hours, grace_period_deadline, check_in_time, check_out_time, status, id_held, id_bin_location, qr_auth_code)
VALUES
    ('bk-seed-active-1', 'usr-student-2', 'Angela Reyes', '2024-01889', 'room-comlab-1', 'ComLab 1 – Mobile & Full-Stack Lab', 'st-c1-2', 'PC-02', 'Flutter', NOW() - INTERVAL '25 minutes', NOW() + INTERVAL '35 minutes', 1, NOW() - INTERVAL '15 minutes', NOW() - INTERVAL '22 minutes', NULL, 'checked_in', TRUE, 'Bin-08', 'LS-8821-PC02'),
    ('bk-seed-pending-1', 'usr-student-3', 'Kevin Lim', '2023-00412', 'room-comlab-1', 'ComLab 1 – Mobile & Full-Stack Lab', 'st-c1-5', 'PC-05', 'Android Studio', NOW(), NOW() + INTERVAL '2 hours', 2, NOW() + INTERVAL '10 minutes', NULL, NULL, 'reserved', FALSE, NULL, 'LS-4092-PC05'),
    ('bk-hist-1', 'usr-student-1', 'Marco Santos', '2024-01042', 'room-comlab-1', 'ComLab 1 – Mobile & Full-Stack Lab', 'st-c1-9', 'PC-09', 'Flutter', NOW() - INTERVAL '28 hours', NOW() - INTERVAL '26 hours', 2, NOW() - INTERVAL '27 hours 50 minutes', NOW() - INTERVAL '27 hours 55 minutes', NOW() - INTERVAL '26 hours', 'completed', FALSE, 'Bin-03', 'LS-1102-PC09'),
    ('bk-hist-2', 'usr-student-2', 'Angela Reyes', '2024-01889', 'room-comlab-3', 'ComLab 3 – CAD & Multimedia Studio', 'st-c3-1', 'PC-01', 'AutoCAD 2025', NOW() - INTERVAL '53 hours', NOW() - INTERVAL '51 hours', 2, NOW() - INTERVAL '52 hours 50 minutes', NOW() - INTERVAL '52 hours 56 minutes', NOW() - INTERVAL '51 hours', 'completed', FALSE, 'Bin-12', 'LS-3319-PC01'),
    ('bk-hist-3', 'usr-student-3', 'Kevin Lim', '2023-00412', 'room-comlab-2', 'ComLab 2 – Cisco Networking Lab', 'st-c2-3', 'PC-03', 'Cisco Packet Tracer', NOW() - INTERVAL '75 hours', NOW() - INTERVAL '74 hours', 1, NOW() - INTERVAL '74 hours 50 minutes', NULL, NULL, 'no_show_cancelled', FALSE, NULL, 'LS-7741-PC03')
ON CONFLICT (id) DO NOTHING;

-- 5. SEED MAINTENANCE TICKETS
INSERT INTO public.maintenance_tickets (id, room_id, room_name, station_id, station_number, reported_by_id, reported_by_name, last_user_id, last_user_name, issue_category, description, is_resolved, repair_notes, resolved_by_name, created_at, resolved_at)
VALUES
    ('mt-1', 'room-comlab-1', 'ComLab 1 – Mobile & Full-Stack Lab', 'st-c1-9', 'PC-09', 'usr-student-1', 'Marco Santos', 'usr-student-1', 'Marco Santos (2024-01042)', 'Broken Mouse / Peripheral', 'Left mouse click fails intermittently while coding.', FALSE, NULL, NULL, NOW() - INTERVAL '5 hours', NULL),
    ('mt-2', 'room-comlab-3', 'ComLab 3 – CAD & Multimedia Studio', 'st-c3-4', 'PC-04', 'usr-custodian-1', 'Engr. Ramon Dela Cruz', 'usr-student-2', 'Angela Reyes (2024-01889)', 'No Network / Internet', 'Ethernet cable clip broken on wall port.', FALSE, NULL, NULL, NOW() - INTERVAL '8 hours', NULL),
    ('mt-3', 'room-comlab-1', 'ComLab 1 – Mobile & Full-Stack Lab', 'st-c1-4', 'PC-04', 'usr-student-2', 'Angela Reyes', 'usr-student-2', 'Angela Reyes (2024-01889)', 'Missing Required IDE / Software', 'Android SDK Command-line tools needed update.', TRUE, 'Updated Android SDK Platform 35 and verified emulator.', 'Engr. Ramon Dela Cruz', NOW() - INTERVAL '54 hours', NOW() - INTERVAL '52 hours')
ON CONFLICT (id) DO NOTHING;

-- 6. SEED HELP DESK CHAT MESSAGES
INSERT INTO public.chat_messages (id, booking_id, room_id, room_name, station_number, student_id, student_name, sender_id, sender_name, sender_role, message, is_resolved, created_at)
VALUES
    ('msg-1', 'bk-seed-active-1', 'room-comlab-1', 'ComLab 1 – Mobile & Full-Stack Lab', 'PC-02', 'usr-student-2', 'Angela Reyes', 'usr-student-2', 'Angela Reyes', 'student', 'Good day sir! May I request admin permission on PC-02 to start the Android Emulator?', FALSE, NOW() - INTERVAL '14 minutes'),
    ('msg-2', 'bk-seed-active-1', 'room-comlab-1', 'ComLab 1 – Mobile & Full-Stack Lab', 'PC-02', 'usr-student-2', 'Angela Reyes', 'usr-custodian-1', 'Engr. Ramon Dela Cruz', 'custodian', 'Copy Angela! Hyper-V permission is now unlocked remotely on PC-02.', FALSE, NOW() - INTERVAL '12 minutes')
ON CONFLICT (id) DO NOTHING;
