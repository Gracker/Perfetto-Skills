-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: cc19de68a5c179e17af405bf32f9ca75f56af0c5a4ccf970ede72790c558942b
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH render_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster')
)
SELECT
  s.name,
  ROUND(SUM(s.dur) / 1e6, 2) as dur_ms,
  COUNT(*) as count,
  ROUND(MAX(s.dur) / 1e6, 2) as max_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_ms,
  printf('%d', MIN(s.ts)) as ts
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
WHERE tt.utid IN (SELECT utid FROM render_thread)
  AND s.ts >= COALESCE(${render_start_ts}, ${start_ts})
  AND s.ts < COALESCE(${render_end_ts}, ${end_ts})
  AND s.dur >= 500000
GROUP BY s.name
HAVING dur_ms > 0.5
ORDER BY dur_ms DESC
LIMIT 10
