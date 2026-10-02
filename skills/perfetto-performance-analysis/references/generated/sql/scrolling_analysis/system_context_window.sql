-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 8016df273414d989f2aaa25e0e34647bbb695e925fcdcb07a400e74b9a806728

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
