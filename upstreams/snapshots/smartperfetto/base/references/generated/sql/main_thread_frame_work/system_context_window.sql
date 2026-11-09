-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/main_thread_frame_work.skill.yaml
-- Source SHA-256: afd9012024e1d46194fffd127e3507c4594bc3eb0990c1d19ced0b57f795a490

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
