-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 0403339f9ba204e964aa7ccab7130157ed7149b13da3cfd63bb807484e4bbb96
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (t.tid = p.pid OR t.name GLOB '[0-9]*.ui')
)
SELECT
  s.name,
  ROUND(SUM(s.dur) / 1e6, 2) as dur_ms,
  COUNT(*) as count,
  ROUND(MAX(s.dur) / 1e6, 2) as max_ms,
  printf('%d', MIN(s.ts)) as ts
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
WHERE tt.utid IN (SELECT utid FROM main_thread)
  AND s.ts >= COALESCE(${main_start_ts}, ${start_ts})
  AND s.ts < COALESCE(${main_end_ts}, ${end_ts})
  AND s.dur >= 1000000
  AND s.name NOT GLOB '*resynced*'
GROUP BY s.name
HAVING dur_ms > 1
ORDER BY dur_ms DESC
LIMIT 10
