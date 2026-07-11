-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: 8fb31a101cc4a8eb2f27ee6912d7f2050586b4cdc0b8722a544391b9c26cd7e0
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH janky AS (
  SELECT
    CAST(a.name AS INTEGER) AS frame_id,
    a.ts,
    a.dur / 1e6 AS dur_ms,
    a.jank_type,
    CASE
      WHEN android_is_sf_jank_type(a.jank_type) THEN 'SurfaceFlinger'
      WHEN android_is_app_jank_type(a.jank_type) THEN 'App'
      WHEN a.jank_type GLOB '*Buffer Stuffing*' THEN 'Buffer'
      ELSE 'Other'
    END AS jank_cause,
    a.upid
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE
    a.surface_frame_token IS NOT NULL
    AND (p.name GLOB '${package}*' OR '${package}' = '')
    AND a.jank_type != 'None'
),
main_ms AS (
  SELECT
    frame_id,
    upid,
    MIN(s.dur) / 1e6 AS main_ms
  FROM android_frames_choreographer_do_frame f
  JOIN slice s ON f.id = s.id
  GROUP BY frame_id, upid
),
render_ms AS (
  SELECT
    frame_id,
    upid,
    MIN(s.dur) / 1e6 AS render_ms
  FROM android_frames_draw_frame f
  JOIN slice s ON f.id = s.id
  GROUP BY frame_id, upid
)
SELECT
  j.frame_id,
  j.ts,
  j.jank_type,
  j.jank_cause,
  ROUND(j.dur_ms, 1) AS dur_ms,
  ROUND(COALESCE(m.main_ms, 0), 1) AS main_ms,
  ROUND(COALESCE(r.render_ms, 0), 1) AS render_ms
FROM janky j
LEFT JOIN main_ms m ON m.frame_id = j.frame_id AND m.upid = j.upid
LEFT JOIN render_ms r ON r.frame_id = j.frame_id AND r.upid = j.upid
ORDER BY j.dur_ms DESC
LIMIT 20
