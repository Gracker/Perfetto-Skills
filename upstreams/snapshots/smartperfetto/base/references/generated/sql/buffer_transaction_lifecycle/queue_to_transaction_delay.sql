-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
-- Source SHA-256: 9bd45c1ab88d6a908b1cc3212e0851489d75932736c4544a9bec8983237545b2
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
sf_proc AS (
  SELECT upid FROM process WHERE name = 'surfaceflinger' LIMIT 1
),
app_queue_buf AS (
  SELECT s.ts as queue_ts
  FROM slice s
  WHERE s.name GLOB '*queueBuffer*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
sf_apply_tx AS (
  SELECT s.ts as apply_ts
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.upid IN (SELECT upid FROM sf_proc)
    AND s.name GLOB '*applyTransaction*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
delays AS (
  SELECT
    q.queue_ts,
    (SELECT MIN(a.apply_ts) FROM sf_apply_tx a WHERE a.apply_ts >= q.queue_ts) as next_apply_ts
  FROM app_queue_buf q
),
delay_ms AS (
  SELECT
    CAST((next_apply_ts - queue_ts) / 1e6 AS REAL) as ms
  FROM delays
  WHERE next_apply_ts IS NOT NULL
)
SELECT bucket, COUNT(*) as count FROM (
  SELECT
    CASE
      WHEN ms < 1 THEN '< 1ms'
      WHEN ms < 5 THEN '1-5ms'
      WHEN ms < 10 THEN '5-10ms'
      WHEN ms < 16 THEN '10-16ms'
      WHEN ms < 32 THEN '16-32ms'
      ELSE '> 32ms'
    END as bucket
  FROM delay_ms
) GROUP BY bucket ORDER BY
  CASE bucket
    WHEN '< 1ms' THEN 1
    WHEN '1-5ms' THEN 2
    WHEN '5-10ms' THEN 3
    WHEN '10-16ms' THEN 4
    WHEN '16-32ms' THEN 5
    ELSE 6
  END
