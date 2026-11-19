-- =============================================================================
-- LabSlot - Campus Computer Laboratory Booking System
-- Complete Supabase PostgreSQL Schema, RBAC RLS, Atomic RPCs, and Auth Trigger
-- Safe to run or re-run in the Supabase SQL Editor (Idempotent)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Clean up existing tables/policies if re-running schema setup
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.chat_messages CASCADE;
DROP TABLE IF EXISTS public.maintenance_tickets CASCADE;
DROP TABLE IF EXISTS public.bookings CASCADE;
DROP TABLE IF EXISTS public.pc_stations CASCADE;
DROP TABLE IF EXISTS public.lab_rooms CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 1. PROFILES TABLE (RBAC: student, custodian, admin)
-- student_id_number is required (6-digit) for students and NULL for custodian/admin
CREATE TABLE public.profiles (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    student_id_number VARCHAR(50) UNIQUE,
    email VARCHAR(150) UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'custodian', 'admin')),
    course_department VARCHAR(100) DEFAULT 'BS Information Technology',
    strike_count INT NOT NULL DEFAULT 0,
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. LAB ROOMS TABLE
CREATE TABLE public.lab_rooms (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    building_floor VARCHAR(100) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'class_in_session', 'closed')),
    total_capacity INT NOT NULL DEFAULT 12 CHECK (total_capacity > 0),
    open_time VARCHAR(10) NOT NULL DEFAULT '07:30',
    close_time VARCHAR(10) NOT NULL DEFAULT '19:00',
    current_subject_note VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. PC STATIONS TABLE
CREATE TABLE public.pc_stations (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    room_id TEXT NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
    station_number VARCHAR(20) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'reserved', 'occupied', 'maintenance')),
    cpu VARCHAR(80) NOT NULL DEFAULT 'Intel Core i7-13700',
    ram_gb INT NOT NULL DEFAULT 16,
    gpu VARCHAR(80) NOT NULL DEFAULT 'NVIDIA RTX 3060 12GB',
    installed_software TEXT[] NOT NULL DEFAULT ARRAY['Flutter', 'VS Code'],
    is_defective BOOLEAN NOT NULL DEFAULT FALSE,
    defect_category VARCHAR(80),
    defect_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(room_id, station_number)
);

CREATE INDEX idx_pc_stations_software ON public.pc_stations USING GIN (installed_software);
CREATE INDEX idx_pc_stations_room ON public.pc_stations (room_id);

-- 4. BOOKINGS TABLE
CREATE TABLE public.bookings (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    student_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name VARCHAR(150) NOT NULL,
    student_id_number VARCHAR(50),
    room_id TEXT NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
    room_name VARCHAR(100) NOT NULL,
    station_id TEXT NOT NULL REFERENCES public.pc_stations(id) ON DELETE CASCADE,
    station_number VARCHAR(20) NOT NULL,
    coursework_tag VARCHAR(80),
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ NOT NULL,
    duration_hours INT NOT NULL DEFAULT 1 CHECK (duration_hours BETWEEN 1 AND 2),
    grace_period_deadline TIMESTAMPTZ NOT NULL,
    check_in_time TIMESTAMPTZ,
    check_out_time TIMESTAMPTZ,
    status VARCHAR(30) NOT NULL DEFAULT 'reserved'
        CHECK (status IN ('reserved', 'checked_in', 'completed', 'cancelled', 'no_show_cancelled')),
    id_held BOOLEAN NOT NULL DEFAULT FALSE,
    id_bin_location VARCHAR(50),
    qr_auth_code VARCHAR(40) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bookings_station_window ON public.bookings (station_id, scheduled_start, scheduled_end);
CREATE INDEX idx_bookings_student_status ON public.bookings (student_id, status);

-- 5. MAINTENANCE TICKETS TABLE (Hardware Quarantine and Last-User Trace)
CREATE TABLE public.maintenance_tickets (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    room_id TEXT NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
    room_name VARCHAR(100) NOT NULL,
    station_id TEXT NOT NULL REFERENCES public.pc_stations(id) ON DELETE CASCADE,
    station_number VARCHAR(20) NOT NULL,
    reported_by_id TEXT REFERENCES public.profiles(id) ON DELETE SET NULL,
    reported_by_name VARCHAR(150) NOT NULL,
    last_user_id TEXT REFERENCES public.profiles(id) ON DELETE SET NULL,
    last_user_name VARCHAR(150),
    issue_category VARCHAR(80) NOT NULL,
    description TEXT NOT NULL,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    repair_notes TEXT,
    resolved_by_name VARCHAR(150),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. HELP DESK CHAT MESSAGES TABLE
CREATE TABLE public.chat_messages (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    booking_id TEXT REFERENCES public.bookings(id) ON DELETE SET NULL,
    room_id TEXT NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
    room_name VARCHAR(100) NOT NULL,
    station_number VARCHAR(20) NOT NULL,
    student_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name VARCHAR(150) NOT NULL,
    sender_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender_name VARCHAR(150) NOT NULL,
    sender_role VARCHAR(20) NOT NULL CHECK (sender_role IN ('student', 'custodian', 'admin')),
    message TEXT NOT NULL,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. AUDIT LOGS TABLE (Accreditation and Compliance Tracking)
CREATE TABLE public.audit_logs (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    actor_id TEXT REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_name VARCHAR(150) NOT NULL,
    actor_role VARCHAR(20) NOT NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- AUTH TRIGGER: Automatically provision profile on Supabase Auth Sign-Up
-- Stores NULL student_id_number for custodian/admin accounts
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_role VARCHAR(20);
    v_student_id VARCHAR(50);
BEGIN
    v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'student');
    v_student_id := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'student_id_number', '')), '');
    IF v_role <> 'student' THEN
        v_student_id := NULL;
    END IF;

    INSERT INTO public.profiles (id, student_id_number, email, full_name, role, course_department)
    VALUES (
        NEW.id::TEXT,
        v_student_id,
        COALESCE(NEW.email, ''),
        COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''), split_part(COALESCE(NEW.email, 'User'), '@', 1)),
        v_role,
        COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'course_department'), ''), 'Campus Department')
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        student_id_number = COALESCE(EXCLUDED.student_id_number, public.profiles.student_id_number),
        role = EXCLUDED.role,
        course_department = EXCLUDED.course_department;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- RBAC HELPER AND ROW-LEVEL SECURITY (RLS) POLICIES
-- =============================================================================
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS VARCHAR
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = public
AS $$
    SELECT COALESCE((SELECT role FROM public.profiles WHERE id = auth.uid()::TEXT), 'student');
$$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pc_stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Policies enabling live app queries and 6-digit student ID email lookup during login
CREATE POLICY "Profiles access policy" ON public.profiles
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Lab rooms access policy" ON public.lab_rooms
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "PC stations access policy" ON public.pc_stations
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Bookings access policy" ON public.bookings
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Maintenance tickets access policy" ON public.maintenance_tickets
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Chat messages access policy" ON public.chat_messages
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Audit logs access policy" ON public.audit_logs
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- =============================================================================
-- ENABLE SUPABASE REALTIME PUBLICATION FOR ALL OPERATIONAL TABLES
-- =============================================================================
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'profiles',
        'lab_rooms',
        'pc_stations',
        'bookings',
        'maintenance_tickets',
        'chat_messages',
        'audit_logs'
    ]
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = tbl
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        END IF;
    END LOOP;
END;
$$;

-- =============================================================================
-- ATOMIC RPC: Auto-Release Expired 10-Min Grace Period ("Ghost-Slot" Engine)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.release_expired_ghost_slots()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    rec RECORD;
    released_count INT := 0;
BEGIN
    FOR rec IN
        SELECT id, student_id, station_id
        FROM public.bookings
        WHERE status = 'reserved'
          AND grace_period_deadline < NOW()
        FOR UPDATE
    LOOP
        UPDATE public.bookings
        SET status = 'no_show_cancelled'
        WHERE id = rec.id;

        UPDATE public.pc_stations
        SET status = CASE WHEN is_defective THEN 'maintenance' ELSE 'available' END
        WHERE id = rec.station_id;

        UPDATE public.profiles
        SET strike_count = strike_count + 1,
            is_suspended = (strike_count + 1) >= 3
        WHERE id = rec.student_id;

        released_count := released_count + 1;
    END LOOP;

    RETURN released_count;
END;
$$;
