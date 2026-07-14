-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/thread_states_quadrant.sql
-- Source SHA-256: ed6b54485655100dd9d525ec671ecc5c2a060f131457c501e09b26715dbe1766
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

-- Fragment: thread_states_quadrant
-- Depends on: target_threads (CTE), _cpu_topology (VIEW)
-- Maps thread states to Q1-Q4 quadrant classification
-- Q1: Running on big/prime cores (compute-capable)
-- Q2: Running on medium/little cores (power-efficient)
-- Q3: Runnable but not scheduled (scheduling contention)
-- Q4a: Uninterruptible wait (D/DK). Treat as IO only when io_wait=1
--       or blocked_function matches an IO/page-cache family.
-- Q4b: Voluntary sleep (S=interruptible sleep, I=idle) — waiting on lock/futex/binder
thread_states AS (
  SELECT
    tt.thread_type,
    CASE
      WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'little') IN ('prime', 'big') THEN 'Q1'
      WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'little') IN ('medium', 'little') THEN 'Q2'
      WHEN ts.state IN ('R', 'R+') THEN 'Q3'
      WHEN ts.state IN ('D', 'DK') THEN 'Q4a'
      WHEN ts.state IN ('S', 'I') THEN 'Q4b'
      ELSE 'Other'
    END as quadrant,
    SUM(ts.dur) as dur_ns
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts >= tt.thread_start_ts AND ts.ts < tt.thread_end_ts
  GROUP BY tt.thread_type, quadrant
)
