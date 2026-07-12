-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 752e67cdf5dd546d65645a1b6da52ba9ab151e46610423c7390997c6e0d4d7a9
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH analysis_window AS (
  SELECT
    COALESCE(${start_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} - 5000000000 ELSE NULL END,
      (SELECT MIN(ts) FROM thread_state)
    ) as w_start,
    COALESCE(${end_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} + 1000000000 ELSE NULL END,
      (SELECT MAX(ts + dur) FROM thread_state)
    ) as w_end
),
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  LIMIT 1
)
SELECT
  printf('%d', MIN(ts_tbl.ts)) as ts,
  ts_tbl.blocked_function,
  ROUND(MAX(ts_tbl.dur) / 1e6, 2) as dur_ms,
  COUNT(*) as count,
  ROUND(SUM(ts_tbl.dur) / 1e6, 2) as total_dur_ms
FROM thread_state ts_tbl
CROSS JOIN analysis_window aw
CROSS JOIN main_thread mt
WHERE ts_tbl.utid = mt.utid
  AND ts_tbl.state = 'S'
  AND ts_tbl.blocked_function IS NOT NULL
  AND ts_tbl.blocked_function != ''
  AND ts_tbl.ts + ts_tbl.dur > aw.w_start
  AND ts_tbl.ts < aw.w_end
GROUP BY ts_tbl.blocked_function
ORDER BY total_dur_ms DESC
LIMIT 20
