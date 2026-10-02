-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: 173f88b137c8d74b94c90839398d803aea4e0f655a143d76102fe519e2094f68

DROP VIEW IF EXISTS _gc_events;
CREATE VIEW _gc_events AS
SELECT
  s.ts,
  s.dur,
  s.name as gc_name,
  t.name as thread_name,
  t.tid,
  p.pid,
  p.name as process_name,
  p.upid,
  CASE WHEN t.tid = p.pid THEN 1 ELSE 0 END as is_main_thread,
  CASE
    WHEN s.name GLOB '*ConcurrentCopying*' THEN 'ConcurrentCopying'
    WHEN s.name GLOB '*MarkSweep*' THEN 'MarkSweep'
    WHEN s.name GLOB '*Explicit*' THEN 'Explicit'
    WHEN s.name GLOB '*Alloc*' THEN 'Alloc'
    WHEN s.name GLOB '*Background*' THEN 'Background'
    WHEN s.name GLOB '*young*' OR s.name GLOB '*Young*' THEN 'Young'
    WHEN s.name GLOB '*full*' OR s.name GLOB '*Full*' THEN 'Full'
    ELSE 'Other'
  END as gc_type
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
  AND (s.name GLOB '*GC*' OR s.name GLOB '*gc*' OR s.name GLOB '*ConcurrentCopying*')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
