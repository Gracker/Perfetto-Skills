-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/thread_states_quadrant.sql
-- Source SHA-256: 1f65fbcca966c86979223453dc24fc86479415b3dd6698a494373c93336d2e64
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- Compatibility fragment. Inputs: target_threads(utid,thread_type,
-- thread_start_ts,thread_end_ts). New consumers use system_thread_state_spans.
-- Q1 groups recorded big/medium capacity; Q2 is little only. Uniform/missing
-- capacity remains unknown. D/DK and S/I are observed waits, not root causes.
thread_states AS (
  SELECT thread_type, quadrant, SUM(dur_ns) AS dur_ns
  FROM (
    SELECT tt.thread_type,
      CASE
        WHEN ts.state='Running' AND c.capacity>0
          AND NOT EXISTS (SELECT 1 FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND (c2.capacity IS NULL OR c2.capacity<=0))
          AND c.capacity>(SELECT MIN(c2.capacity) FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND c2.capacity>0) THEN 'Q1'
        WHEN ts.state='Running' AND c.capacity>0
          AND NOT EXISTS (SELECT 1 FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND (c2.capacity IS NULL OR c2.capacity<=0))
          AND c.capacity=(SELECT MIN(c2.capacity) FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND c2.capacity>0)
          AND c.capacity<(SELECT MAX(c2.capacity) FROM cpu c2 WHERE c2.machine_id IS c.machine_id) THEN 'Q2'
        WHEN ts.state='Running' THEN 'UnknownRunning'
        WHEN ts.state IN ('R','R+') THEN 'Q3'
        WHEN ts.state IN ('D','DK') THEN 'Q4a'
        WHEN ts.state IN ('S','I') THEN 'Q4b'
        ELSE 'Other' END AS quadrant,
      MIN(CASE WHEN ts.dur=-1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts.ts+ts.dur END,tt.thread_end_ts)
        -MAX(ts.ts,tt.thread_start_ts) AS dur_ns
    FROM thread_state ts JOIN target_threads tt ON tt.utid=ts.utid
    LEFT JOIN cpu c ON c.id=ts.ucpu
    WHERE ts.dur>=-1 AND ts.dur!=0 AND ts.ts<tt.thread_end_ts
      AND CASE WHEN ts.dur=-1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts.ts+ts.dur END>tt.thread_start_ts
  ) GROUP BY thread_type,quadrant
)
