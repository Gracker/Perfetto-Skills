-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_phase_alignment.skill.yaml
-- Source SHA-256: f1629db2e1ddf7711964f2b32f51d60012885ff3c966af974128cb5ed150e700
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH vsync_events AS (
  SELECT c.ts as vsync_ts
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
  ORDER BY c.ts
),
intervals AS (
  SELECT vsync_ts - LAG(vsync_ts) OVER (ORDER BY vsync_ts) as interval_ns
  FROM vsync_events
)
SELECT
  (SELECT COUNT(*) FROM vsync_events) as vsync_count,
  ROUND(PERCENTILE(interval_ns, 0.5) / 1e6, 2) as period_ms,
  ROUND(1e9 / PERCENTILE(interval_ns, 0.5), 1) as refresh_hz
FROM intervals
WHERE interval_ns BETWEEN 5500000 AND 50000000
