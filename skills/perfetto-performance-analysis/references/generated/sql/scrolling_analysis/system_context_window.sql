-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 0c491f4640947a77746c9299ed721693f8e5109a88b8371db4e965d2b4c84a94
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
