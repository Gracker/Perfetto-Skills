-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/render_thread_slices.skill.yaml
-- Source SHA-256: cc1e3d5e7156fb21c9208867164cb287e368f620dae68b1f3e289076316b4435
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  name,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  COUNT(*) as count,
  ROUND(MAX(dur) / 1e6, 2) as max_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_ms
FROM thread_slice
WHERE (process_name GLOB '${package}*' OR '${package}' = '')
  AND thread_name = 'RenderThread'
  AND ts >= ${start_ts}
  AND ts < ${end_ts}
  AND dur >= 500000
GROUP BY name
HAVING total_ms > 0.5
ORDER BY total_ms DESC
LIMIT 10
