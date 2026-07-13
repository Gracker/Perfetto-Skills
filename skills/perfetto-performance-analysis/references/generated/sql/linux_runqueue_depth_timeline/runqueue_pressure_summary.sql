-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_runqueue_depth_timeline.skill.yaml
-- Source SHA-256: 97534c690220e660274868201d0a31f13496a46e688ce0b95a08558ad75197af
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH
input AS (
  SELECT
    COALESCE(${pressure_threshold}, 4) AS pressure_threshold,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM thread_state)) AS end_ts
),
rq AS (
  SELECT
    ts,
    runnable_thread_count
  FROM sched_runnable_thread_count, input
  WHERE ts >= input.start_ts
    AND ts < input.end_ts
)
SELECT
  COUNT(*) AS samples,
  ROUND(AVG(runnable_thread_count), 2) AS avg_runnable,
  ROUND(PERCENTILE(runnable_thread_count, 0.95), 2) AS p95_runnable,
  MAX(runnable_thread_count) AS max_runnable,
  SUM(CASE WHEN runnable_thread_count >= (SELECT pressure_threshold FROM input) THEN 1 ELSE 0 END) AS pressure_samples
FROM rq
