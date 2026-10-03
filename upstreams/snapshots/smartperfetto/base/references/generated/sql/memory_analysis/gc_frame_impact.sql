-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: 51ddff1e843e8e91fa5b9e8f494b2c95beaf700729248e96efd733cbaea21e10

-- One row per main-thread GC, over the frames of the process that ran
-- it; a frame of another process at the same time says nothing about it.
-- A process with no FrameTimeline cannot show a frame impact either way.
WITH gc_frames AS (
  SELECT
    gc.gc_id, gc.ts, gc.upid, gc.gc_name, gc.dur,
    af.id AS frame_id, af.dur AS frame_dur, af.jank_type
  FROM _gc_events gc
  LEFT JOIN actual_frame_timeline_slice af ON (
    af.upid = gc.upid AND af.ts < gc.ts + gc.dur AND af.ts + af.dur > gc.ts
  )
  WHERE gc.is_main_thread = 1
)
SELECT
  gc_name,
  dur / 1e6 AS gc_dur_ms,
  COUNT(frame_id) AS frame_count,
  COALESCE(SUM(jank_type != 'None'), 0) AS janky_frame_count,
  group_concat(DISTINCT CASE WHEN jank_type != 'None' THEN jank_type END) AS jank_type,
  MAX(frame_dur) / 1e6 AS frame_dur_ms,
  CASE
    WHEN NOT EXISTS (SELECT 1 FROM actual_frame_timeline_slice f WHERE f.upid = gc_frames.upid) THEN '无帧时间线数据'
    WHEN COUNT(frame_id) = 0 THEN '无重叠帧'
    WHEN SUM(jank_type != 'None') > 0 THEN 'GC导致掉帧'
    WHEN MAX(frame_dur) > ${vsync_info.data[0].vsync_period_ns|16666667} THEN '帧超时'
    ELSE '正常'
  END AS impact
FROM gc_frames
GROUP BY gc_id
ORDER BY dur DESC, ts, gc_id
LIMIT 30
