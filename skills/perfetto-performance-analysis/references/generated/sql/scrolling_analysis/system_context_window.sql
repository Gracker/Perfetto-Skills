-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 48777e583cbb4e8676c824e1eca1b0473ff21ee250b4f74cf0afbce1ace62e94
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
