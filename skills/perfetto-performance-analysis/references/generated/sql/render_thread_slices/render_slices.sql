-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/render_thread_slices.skill.yaml
-- Source SHA-256: 8ddac0e2dc4a11ec52133865f9c7be4c33cae1f207852349f0757d5049168649
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  name,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  COUNT(*) as count,
  ROUND(MAX(dur) / 1e6, 2) as max_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_ms
FROM thread_slice
WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
  AND thread_name = 'RenderThread'
  AND ts >= ${start_ts}
  AND ts < ${end_ts}
  AND dur >= 500000
GROUP BY name
HAVING total_ms > 0.5
ORDER BY total_ms DESC
LIMIT 10
