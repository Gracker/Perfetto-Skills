-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH anr_window AS (
  SELECT
    ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns} AS start_ts,
    ${anr_ctx.data[0].anr_ts} AS end_ts
),
uninterruptible_states AS (
  SELECT
    p.name as process_name,
    SUM(
      MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
        - MAX(ts.ts, aw.start_ts)
    ) as uninterruptible_wait_ns,
    COUNT(*) as uninterruptible_wait_count
  FROM thread_state ts
  CROSS JOIN anr_window aw
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ts.state = 'D'
    AND ts.ts < aw.end_ts
    AND (CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END) > aw.start_ts
  GROUP BY p.name
)
SELECT
  process_name,
  ROUND(uninterruptible_wait_ns / 1e6, 2) as uninterruptible_wait_ms,
  uninterruptible_wait_count
FROM uninterruptible_states
WHERE uninterruptible_wait_ns > 10000000  -- > 10ms
ORDER BY uninterruptible_wait_ns DESC
LIMIT 10
