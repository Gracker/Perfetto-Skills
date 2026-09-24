-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_phase_alignment.skill.yaml
-- Source SHA-256: 72caf1238bfbf0f4c1aa7d5644f91719be30535ea54bee340c89bc2827eb11ba
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

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
  ROUND(PERCENTILE(interval_ns, 50) / 1e6, 2) as period_ms,
  ROUND(1e9 / PERCENTILE(interval_ns, 50), 1) as refresh_hz
FROM intervals
WHERE interval_ns BETWEEN 5500000 AND 50000000
