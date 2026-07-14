-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scroll_session_analysis.skill.yaml
-- Source SHA-256: fd8dbf2ef3390842217b4b5877ff5a8dd65c44f0edbaaa4d59ba036370f53517
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH frames AS (
  SELECT
    ts,
    dur,
    dur / 1e6 AS dur_ms,
    CASE
      WHEN ts < ${touch_end_ts} THEN 'touch'
      ELSE 'fling'
    END AS phase,
    ROW_NUMBER() OVER (ORDER BY ts) AS frame_number
  FROM slice
  WHERE (name GLOB '*doFrame*' OR name GLOB '*Choreographer#doFrame*' OR name GLOB '*DrawFrame*')
    AND ts >= ${start_ts}
    AND ts <= ${end_ts}
)
SELECT
  frame_number,
  phase,
  printf('%d', ts) as ts_str,
  printf('%d', ts + dur) as end_ts_str,
  printf('%d', dur) as dur_str,
  ROUND(dur_ms, 2) AS dur_ms,
  CASE
    WHEN dur > ${vsync_period_ns} * 3 THEN 'severe'
    WHEN dur > ${vsync_period_ns} * 2 THEN 'bad'
    WHEN dur > ${vsync_period_ns} * 1.5 THEN 'jank'
    ELSE 'normal'
  END AS jank_level,
  ROUND(dur_ms / (${vsync_period_ns} / 1e6), 1) AS frames_dropped
FROM frames
WHERE dur > ${vsync_period_ns} * 1.5  -- 超过 1.5 倍 VSync 周期为掉帧
ORDER BY dur_ms DESC
LIMIT 20
