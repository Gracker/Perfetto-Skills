-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_runqueue_depth_timeline.skill.yaml
-- Source SHA-256: 97534c690220e660274868201d0a31f13496a46e688ce0b95a08558ad75197af
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH
input AS (
  SELECT
    COALESCE(${pressure_threshold}, 4) AS pressure_threshold,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM thread_state)) AS end_ts
)
SELECT
  printf('%d', ts) AS ts,
  runnable_thread_count
FROM sched_runnable_thread_count, input
WHERE ts >= input.start_ts
  AND ts < input.end_ts
  AND runnable_thread_count >= input.pressure_threshold
ORDER BY runnable_thread_count DESC, ts ASC
LIMIT 100
