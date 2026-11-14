-- =============================================================================
-- LabSlot Seed Data (Davao Campus Computer Laboratories & PC Stations)
-- =============================================================================

INSERT INTO public.lab_rooms (id, code, name, building_floor, status, total_capacity, open_time, close_time, current_subject_note)
VALUES
    ('11111111-1111-1111-1111-111111111101', 'COMLAB-1', 'ComLab 1 – Mobile & Full-Stack Lab', '3rd Floor, IT Building', 'open', 12, '07:30', '19:00', 'Open Lab for Vacant Period Coding'),
    ('11111111-1111-1111-1111-111111111102', 'COMLAB-2', 'ComLab 2 – Cisco Networking Lab', '3rd Floor, IT Building', 'class_in_session', 12, '07:30', '19:00', 'IT-302 Routing & Switching (10:00 AM - 12:00 PM)'),
    ('11111111-1111-1111-1111-111111111103', 'COMLAB-3', 'ComLab 3 – CAD & Multimedia Studio', '4th Floor, Engineering Wing', 'open', 12, '07:30', '19:00', 'Open Lab for Rendering & Design'),
    ('11111111-1111-1111-1111-111111111104', 'COMLAB-4', 'ComLab 4 – General Programming Lab', '2nd Floor, Main Academic Hall', 'closed', 12, '07:30', '19:00', 'Scheduled UPS & Network Switch Upgrade')
ON CONFLICT (code) DO NOTHING;
