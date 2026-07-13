-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
-- Source SHA-256: 9bd45c1ab88d6a908b1cc3212e0851489d75932736c4544a9bec8983237545b2
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
sf_proc AS (
  SELECT upid FROM process WHERE name = 'surfaceflinger' LIMIT 1
),
sf_apply_tx AS (
  SELECT s.ts, s.dur
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.upid IN (SELECT upid FROM sf_proc)
    AND s.name GLOB '*applyTransaction*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
sf_set_tx_state AS (
  SELECT s.ts
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.upid IN (SELECT upid FROM sf_proc)
    AND s.name GLOB '*setTransactionState*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
sf_latch AS (
  SELECT s.ts
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.upid IN (SELECT upid FROM sf_proc)
    AND (s.name GLOB '*latchBuffer*' OR s.name GLOB '*acquireBuffer*')
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
app_blast AS (
  SELECT s.ts
  FROM slice s
  WHERE s.name GLOB '*BLASTBufferQueue*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
app_queue_buf AS (
  SELECT s.ts
  FROM slice s
  WHERE s.name GLOB '*queueBuffer*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
apply_to_latch_pairs AS (
  -- 对每个 applyTransaction 找下一个 latch（粗略代理 Transaction→Latch 间隔）
  SELECT
    a.ts as apply_ts,
    (SELECT MIN(l.ts) FROM sf_latch l WHERE l.ts >= a.ts) as next_latch_ts
  FROM sf_apply_tx a
)
SELECT
  (SELECT COUNT(*) FROM sf_apply_tx) as total_apply_transactions,
  (SELECT COUNT(*) FROM sf_set_tx_state) as total_set_transaction_state,
  (SELECT COUNT(*) FROM app_blast) as total_blast_bq,
  (SELECT COUNT(*) FROM app_queue_buf) as total_queue_buffer,
  COALESCE((
    SELECT ROUND(AVG(next_latch_ts - apply_ts) / 1e6, 2)
    FROM apply_to_latch_pairs
    WHERE next_latch_ts IS NOT NULL
  ), 0) as avg_apply_to_latch_ms
