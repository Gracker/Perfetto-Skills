-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 94563f8717669e993b92723f09bb10688c8a9ac9d9c9caf91391ddf4ecf14639
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH gc_periods AS (
  SELECT
    gc_ts AS ts,
    gc_dur AS dur,
    process_name,
    upid
  FROM android_garbage_collection_events
  WHERE CASE WHEN '${package}' != ''
             THEN process_name GLOB '*${package}*'
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
