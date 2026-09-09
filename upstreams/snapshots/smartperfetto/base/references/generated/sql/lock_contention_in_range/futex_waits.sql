-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/lock_contention_in_range.skill.yaml
-- Source SHA-256: 660f675d614aec2af8885125bcb62d2a5410b5318a01e545990ff3642f53a566
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  t.name as thread_name,
  ts.blocked_function,
  ROUND(ts.dur / 1e6, 2) as wait_ms,
  p.name as process_name,
  CASE
    WHEN ts.blocked_function GLOB '*futex*' THEN 'futex'
    WHEN ts.blocked_function GLOB '*mutex*' THEN 'pthread_mutex'
    WHEN ts.blocked_function GLOB '*rwlock*' THEN 'rwlock'
    WHEN ts.blocked_function GLOB '*sem*' THEN 'semaphore'
    WHEN ts.blocked_function GLOB '*cond*' THEN 'condition_var'
    ELSE 'other'
  END as lock_type,
  t.tid = p.pid as is_main_thread
FROM thread_state ts
JOIN thread t ON ts.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ts.ts >= ${start_ts}
  AND ts.ts < ${end_ts}
  AND (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
  AND ts.state IN ('S', 'D')
  AND ts.dur >= 1000000
  AND (ts.blocked_function GLOB '*futex*'
       OR ts.blocked_function GLOB '*mutex*'
       OR ts.blocked_function GLOB '*rwlock*'
       OR ts.blocked_function GLOB '*sem_*'
       OR ts.blocked_function GLOB '*cond_*')
ORDER BY ts.dur DESC
