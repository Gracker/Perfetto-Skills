-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_runqueue_depth_timeline.skill.yaml
-- Source SHA-256: df8e54081665caab0f1d374c13f7ceb343c0f20209e1e1b699da6ee24688ba35
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
  ROUND(PERCENTILE(runnable_thread_count, 95), 2) AS p95_runnable,
  MAX(runnable_thread_count) AS max_runnable,
  SUM(CASE WHEN runnable_thread_count >= (SELECT pressure_threshold FROM input) THEN 1 ELSE 0 END) AS pressure_samples
FROM rq
