-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 4007035c487eb410a43fdb6bf3aae3bc1b3bad006e40395f80a69f43bd269da5
-- Source commit: 12f4004d5cdc2aeac76d3afce68ef2e3e87d500f

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
