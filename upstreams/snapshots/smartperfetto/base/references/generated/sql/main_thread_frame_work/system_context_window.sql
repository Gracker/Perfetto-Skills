-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/main_thread_frame_work.skill.yaml
-- Source SHA-256: 335e554b31f16b090c6d224e21718bd9e2c194ef268a06f9efdf4a36c9ec79d0
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
