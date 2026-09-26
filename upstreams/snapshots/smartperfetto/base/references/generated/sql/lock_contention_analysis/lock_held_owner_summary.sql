-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH holds AS (
  SELECT
    COALESCE(p.name, 'unknown') AS process_name,
    h.lock_name,
    COALESCE(t.name, 'tid:' || t.tid) AS holder_thread,
    h.is_incomplete,
    h.blocking_method,
    MIN(h.ts + h.dur, COALESCE(${end_ts}, h.ts + h.dur))
      - MAX(h.ts, COALESCE(${start_ts}, h.ts)) AS held_dur
  FROM android_lock_held AS h
  JOIN thread AS t USING (utid)
  LEFT JOIN process AS p USING (upid)
  WHERE
    CASE WHEN '${process_name}' != ''
         THEN (p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
         ELSE 1 END
    AND (${start_ts} IS NULL OR h.ts + h.dur > ${start_ts})
    AND (${end_ts} IS NULL OR h.ts < ${end_ts})
),
holders AS (
  SELECT
    process_name,
    lock_name,
    holder_thread,
    SUM(held_dur) AS holder_dur,
    ROW_NUMBER() OVER (
      PARTITION BY process_name, lock_name ORDER BY SUM(held_dur) DESC, holder_thread
    ) AS holder_rank
  FROM holds
  GROUP BY process_name, lock_name, holder_thread
),
methods AS (
  SELECT
    process_name,
    lock_name,
    blocking_method,
    ROW_NUMBER() OVER (
      PARTITION BY process_name, lock_name ORDER BY COUNT(*) DESC, blocking_method
    ) AS method_rank
  FROM holds
  WHERE blocking_method IS NOT NULL
  GROUP BY process_name, lock_name, blocking_method
)
SELECT
  h.process_name,
  h.lock_name,
  COUNT(*) AS hold_count,
  ROUND(SUM(h.held_dur) / 1e6, 2) AS total_held_ms,
  ROUND(MAX(h.held_dur) / 1e6, 2) AS max_held_ms,
  SUM(h.blocking_method IS NOT NULL) AS contended_hold_count,
  SUM(h.is_incomplete) AS incomplete_hold_count,
  top.holder_thread AS top_holder_thread,
  ROUND(top.holder_dur / 1e6, 2) AS top_holder_held_ms,
  m.blocking_method AS top_blocking_method
FROM holds AS h
JOIN holders AS top
  ON top.process_name = h.process_name
  AND top.lock_name = h.lock_name
  AND top.holder_rank = 1
LEFT JOIN methods AS m
  ON m.process_name = h.process_name
  AND m.lock_name = h.lock_name
  AND m.method_rank = 1
GROUP BY h.process_name, h.lock_name
ORDER BY SUM(h.held_dur) DESC
LIMIT 50
