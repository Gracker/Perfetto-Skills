-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 0403339f9ba204e964aa7ccab7130157ed7149b13da3cfd63bb807484e4bbb96
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH
thread_states AS (
  SELECT
    tt.thread_type,
    ts.state,
    ts.cpu,
    ts.dur,
    CASE
      WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN 'Q1_大核运行'
      WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN 'Q2_小核运行'
      WHEN ts.state = 'R' THEN 'Q3_等待调度'
      WHEN ts.state IN ('D', 'DK') THEN 'Q4a_不可中断等待'
      WHEN ts.state IN ('S', 'I') THEN 'Q4b_休眠等待'
      ELSE 'Other'
    END as quadrant_name
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts >= tt.thread_start_ts
    AND ts.ts < tt.thread_end_ts
),
quadrant_sums AS (
  SELECT
    thread_type,
    quadrant_name,
    SUM(dur) as dur_ns
  FROM thread_states
  WHERE quadrant_name != 'Other'
  GROUP BY thread_type, quadrant_name
),
thread_totals AS (
  SELECT
    thread_type,
    SUM(dur_ns) as total_ns
  FROM quadrant_sums
  GROUP BY thread_type
)
SELECT
  qs.thread_type || ' ' || qs.quadrant_name as quadrant,
  qs.thread_type || ' ' || qs.quadrant_name as name,
  ROUND(qs.dur_ns / 1e6, 2) as dur_ms,
  ROUND(100.0 * qs.dur_ns / NULLIF(tt.total_ns, 0), 1) as percentage
FROM quadrant_sums qs
JOIN thread_totals tt ON qs.thread_type = tt.thread_type
WHERE qs.dur_ns > 0
ORDER BY qs.thread_type, qs.quadrant_name
