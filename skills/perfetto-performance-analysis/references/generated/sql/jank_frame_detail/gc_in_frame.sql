-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 0403339f9ba204e964aa7ccab7130157ed7149b13da3cfd63bb807484e4bbb96
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH gc_events AS (
  SELECT
    gc.tid,
    gc.gc_type,
    gc.gc_ts as gc_ts,
    gc.gc_dur as gc_dur,
    -- Calculate overlap with frame window
    MAX(gc.gc_ts, ${start_ts}) as overlap_start,
    MIN(gc.gc_ts + gc.gc_dur, ${end_ts}) as overlap_end
  FROM android_garbage_collection_events gc
  JOIN thread t ON gc.tid = t.tid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND gc.gc_ts < ${end_ts}
    AND gc.gc_ts + gc.gc_dur > ${start_ts}
)
SELECT
  gc_type,
  COUNT(*) as gc_count,
  ROUND(SUM(gc_dur) / 1e6, 2) as total_dur_ms,
  ROUND(SUM(CASE WHEN overlap_end > overlap_start THEN overlap_end - overlap_start ELSE 0 END) / 1e6, 2) as overlap_ms,
  ROUND(MAX(gc_dur) / 1e6, 2) as max_dur_ms
FROM gc_events
GROUP BY gc_type
HAVING overlap_ms > 0
ORDER BY overlap_ms DESC
