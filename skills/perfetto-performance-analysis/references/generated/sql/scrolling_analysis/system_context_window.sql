-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: b7ebca89bd8e31ada9de2d388e0e3cd9e257c8ef65e1c0e6862c167bc631da67
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
