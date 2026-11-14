-- =============================================================================
-- LabSlot – Campus Computer Laboratory & PC Station Booking System
-- Complete Supabase PostgreSQL Schema, RBAC RLS, Atomic RPCs & Cron Automation
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. PROFILES TABLE (RBAC: student, custodian, admin)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    student_id_number VARCHAR(50) UNIQUE,
    email VARCHAR(150) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'custodian', 'admin')),
    course_department VARCHAR(100) DEFAULT 'BS Information Technology',
    strike_count INT NOT NULL DEFAULT 0,
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. LAB ROOMS TABLE
CREATE TABLE IF NOT EXISTS public.lab_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    building_floor VARCHAR(100) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'class_in_session', 'closed')),
    total_capacity INT NOT NULL DEFAULT 20 CHECK (total_capacity > 0),
    open_time VARCHAR(10) NOT NULL DEFAULT '07:30',
    close_time VARCHAR(10) NOT NULL DEFAULT '19:00',
    current_subject_note VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. PC STATIONS TABLE
CREATE TABLE IF NOT EXISTS public.pc_stations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_pc_stations_software ON public.pc_stations USING GIN (installed_software);
CREATE INDEX IF NOT EXISTS idx_pc_stations_room ON public.pc_stations (room_id);

-- 4. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name VARCHAR(150) NOT NULL,
    student_id_number VARCHAR(50) NOT NULL,
    room_id UUID NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
    room_name VARCHAR(100) NOT NULL,
    station_id UUID NOT NULL REFERENCES public.pc_stations(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_bookings_station_window ON public.bookings (station_id, scheduled_start, scheduled_end);
CREATE INDEX IF NOT EXISTS idx_bookings_student_status ON public.bookings (student_id, status);

-- 5. MAINTENANCE TICKETS TABLE (Hardware Quarantine & Last-User Trace)
CREATE TABLE IF NOT EXISTS public.maintenance_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
    room_name VARCHAR(100) NOT NULL,
    station_id UUID NOT NULL REFERENCES public.pc_stations(id) ON DELETE CASCADE,
    station_number VARCHAR(20) NOT NULL,
    reported_by_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reported_by_name VARCHAR(150) NOT NULL,
    last_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
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
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    room_id UUID NOT NULL REFERENCES public.lab_rooms(id) ON DELETE CASCADE,
    room_name VARCHAR(100) NOT NULL,
    station_number VARCHAR(20) NOT NULL,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name VARCHAR(150) NOT NULL,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender_name VARCHAR(150) NOT NULL,
    sender_role VARCHAR(20) NOT NULL CHECK (sender_role IN ('student', 'custodian', 'admin')),
    message TEXT NOT NULL,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. AUDIT LOGS TABLE (Accreditation & Compliance Tracking)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_name VARCHAR(150) NOT NULL,
    actor_role VARCHAR(20) NOT NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- AUTH TRIGGER: Automatically provision profile with default 'student' role
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, student_id_number, email, full_name, role, course_department)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'student_id_number', 'STU-' || UPPER(SUBSTRING(NEW.id::TEXT, 1, 6))),
        COALESCE(NEW.email, ''),
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(COALESCE(NEW.email, 'Student'), '@', 1)),
        'student',
        COALESCE(NEW.raw_user_meta_data->>'course_department', 'BS Information Technology')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- RBAC HELPER & ROW-LEVEL SECURITY (RLS) POLICIES
-- =============================================================================
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS VARCHAR
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = public
AS $$
    SELECT COALESCE((SELECT role FROM public.profiles WHERE id = auth.uid()), 'student');
$$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pc_stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Profiles readable by authenticated users" ON public.profiles
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins and custodians can update profiles" ON public.profiles
    FOR UPDATE TO authenticated
    USING (public.current_user_role() IN ('admin', 'custodian') OR id = auth.uid());

-- Lab Rooms policies
CREATE POLICY "Lab rooms readable by all" ON public.lab_rooms
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Custodians and admins can update lab rooms" ON public.lab_rooms
    FOR ALL TO authenticated
    USING (public.current_user_role() IN ('custodian', 'admin'));

-- PC Stations policies
CREATE POLICY "PC stations readable by all" ON public.pc_stations
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can update PC status on booking/defect" ON public.pc_stations
    FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Admins manage PC stations inventory" ON public.pc_stations
    FOR INSERT TO authenticated WITH CHECK (public.current_user_role() = 'admin');

-- Bookings policies
CREATE POLICY "Bookings readable by authenticated users" ON public.bookings
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Students create own bookings" ON public.bookings
    FOR INSERT TO authenticated WITH CHECK (student_id = auth.uid() OR public.current_user_role() IN ('custodian', 'admin'));
CREATE POLICY "Students cancel own or staff update bookings" ON public.bookings
    FOR UPDATE TO authenticated
    USING (student_id = auth.uid() OR public.current_user_role() IN ('custodian', 'admin'));

-- Maintenance Tickets policies
CREATE POLICY "Maintenance tickets readable by all" ON public.maintenance_tickets
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can create defect reports" ON public.maintenance_tickets
    FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can resolve maintenance tickets" ON public.maintenance_tickets
    FOR UPDATE TO authenticated USING (public.current_user_role() IN ('custodian', 'admin'));

-- Chat Messages policies
CREATE POLICY "Students see own chat or staff see all" ON public.chat_messages
    FOR SELECT TO authenticated
    USING (student_id = auth.uid() OR public.current_user_role() IN ('custodian', 'admin'));
CREATE POLICY "Users insert chat messages" ON public.chat_messages
    FOR INSERT TO authenticated WITH CHECK (sender_id = auth.uid());

-- Audit Logs policies
CREATE POLICY "Audit logs readable by staff" ON public.audit_logs
    FOR SELECT TO authenticated USING (public.current_user_role() IN ('custodian', 'admin'));
CREATE POLICY "Authenticated users insert audit logs" ON public.audit_logs
    FOR INSERT TO authenticated WITH CHECK (true);

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
