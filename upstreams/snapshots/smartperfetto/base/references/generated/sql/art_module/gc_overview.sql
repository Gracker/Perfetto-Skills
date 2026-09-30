-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: e7d524de05ca91174a9bf283192a02d3dfab1324753b0b8ebfaaa259379d9e8a

SELECT
  slice.name AS gc_type,
  COUNT(*) AS gc_count,
  CAST(SUM(slice.dur) / 1e6 AS INTEGER) AS total_gc_ms,
  CAST(AVG(slice.dur) / 1e6 AS REAL) AS avg_gc_ms,
  CAST(MAX(slice.dur) / 1e6 AS REAL) AS max_gc_ms
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread ON thread_track.utid = thread.utid
WHERE slice.name LIKE '%GC%'
  OR slice.name LIKE '%garbage%'
  OR slice.name LIKE '%collection%'
GROUP BY slice.name
ORDER BY total_gc_ms DESC
