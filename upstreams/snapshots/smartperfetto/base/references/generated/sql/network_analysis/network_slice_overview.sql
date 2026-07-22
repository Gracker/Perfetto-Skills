-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  s.name as slice_name,
  COUNT(*) as count,
  ROUND(SUM(s.dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(s.dur) / 1e6, 2) as max_dur_ms
FROM slice s
WHERE (
    s.name GLOB '*network*'
    OR s.name GLOB '*Network*'
    OR s.name GLOB '*socket*'
    OR s.name GLOB '*Socket*'
    OR s.name GLOB '*DNS*'
    OR s.name GLOB '*dns*'
    OR s.name GLOB '*http*'
    OR s.name GLOB '*Http*'
    OR s.name GLOB '*connect*'
    OR s.name GLOB '*Connect*'
  )
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
GROUP BY s.name
ORDER BY total_dur_ms DESC
LIMIT 20
