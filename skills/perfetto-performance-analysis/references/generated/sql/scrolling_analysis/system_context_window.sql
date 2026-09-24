-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 932de9b3d1c489168bad805861e11436f709ab3f63663add77ae3582aab383db
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

SELECT COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS start_ts, COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS end_ts
