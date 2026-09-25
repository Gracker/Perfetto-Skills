-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 7fe3eb2595b5f8920c8da24ca631b91a13f1e04ac0fe3dda1f3efae096b3319b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH gc_periods AS (
  SELECT
    gc_ts AS ts,
    gc_dur AS dur,
    process_name,
    upid
  FROM android_garbage_collection_events
  WHERE CASE WHEN '${package}' != ''
             THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
             ELSE 1 END
    AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
    AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
),
overlapping_frames AS (
  SELECT
    gp.process_name,
    f.jank_type,
    COUNT(*) AS frame_count
  FROM gc_periods gp
  JOIN actual_frame_timeline_slice f
    ON f.upid = gp.upid
    AND f.ts < gp.ts + gp.dur
    AND f.ts + f.dur > gp.ts
  GROUP BY gp.process_name, f.jank_type
)
SELECT
  process_name,
  jank_type,
  frame_count
FROM overlapping_frames
ORDER BY frame_count DESC
