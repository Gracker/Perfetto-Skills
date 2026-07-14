-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/power_module.skill.yaml
-- Source SHA-256: c78783057846e5a5481c15de86a5cfb018687fc79c03c89f11364a34bf005634
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  s.name AS wakelock_event,
  COUNT(*) AS event_count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS INTEGER) AS max_ms
FROM slice s
WHERE s.name GLOB '*wakelock*'
  OR s.name GLOB '*Wakelock*'
  OR s.name GLOB '*WAKE_LOCK*'
  OR s.name GLOB '*PowerManager*'
  OR s.name GLOB '*acquire*wake*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 20
