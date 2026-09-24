-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 917a301ba39a39244344d671654334dbea71801fdead788f5de43bd07d2f2865
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
