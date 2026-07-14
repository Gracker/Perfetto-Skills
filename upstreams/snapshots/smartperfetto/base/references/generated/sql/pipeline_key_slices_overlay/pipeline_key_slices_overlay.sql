-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/pipeline_key_slices_overlay.skill.yaml
-- Source SHA-256: 34b2abe52c508a34d1fb3f9794fbac79210dc3ee9fb9e3d4305b68a4c3699b97
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  s.ts,
  s.dur,
  s.name AS slice_name,
  ROUND(CAST(s.dur AS REAL) / 1000000.0, 2) AS dur_ms,
  t.name AS thread_name,
  p.name AS process_name,
  s.track_id,
  t.utid,
  CASE
    WHEN lower(s.name) LIKE '%choreographer%doframe%' OR lower(s.name) LIKE '%traversal%' THEN 'app_frame'
    WHEN t.name = 'RenderThread' OR lower(s.name) LIKE '%drawframe%' OR lower(s.name) LIKE '%syncframestate%' THEN 'render_thread'
    WHEN lower(s.name) LIKE '%queuebuffer%' OR lower(s.name) LIKE '%dequeuebuffer%' OR lower(s.name) LIKE '%blast%' OR lower(s.name) LIKE '%transaction%' THEN 'buffer_queue_transaction'
    WHEN p.name LIKE '%surfaceflinger%' OR lower(s.name) LIKE '%latchbuffer%' THEN 'surfaceflinger_composition'
    WHEN t.name LIKE '%HWC%' OR lower(s.name) LIKE '%present%' THEN 'present'
    ELSE 'other'
  END AS pipeline_stage,
  '' AS description
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE s.name IN (${slice_names})
  AND s.dur > 0
  AND (${start_ts|NULL} IS NULL OR s.ts >= ${start_ts|NULL})
  AND (${end_ts|NULL} IS NULL OR s.ts < ${end_ts|NULL})
  AND (
    '${package}' = ''
    OR p.name GLOB '${package}*'
    OR p.name LIKE '%surfaceflinger%'
    OR p.name = 'system_server'
  )
ORDER BY s.ts
LIMIT 200
