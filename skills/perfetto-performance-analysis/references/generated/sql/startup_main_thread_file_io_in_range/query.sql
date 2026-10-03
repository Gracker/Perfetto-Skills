-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_file_io_in_range.skill.yaml
-- Source SHA-256: d0b865bcdf6a32b3aef63b49a77e990e8082645efaec7abdb610a4ce1dfea983

WITH io_words(word, camel) AS (
  VALUES ('open', 'Open'), ('read', 'Read'), ('write', 'Write'), ('fsync', 'Fsync'),
    ('fdatasync', 'Fdatasync'), ('sqlite', 'SQLite'), ('sqlite', 'Sqlite'), ('database', 'Database'),
    ('file', 'File'), ('disk', 'Disk')
),
io AS (
  SELECT
    ts.slice_id,
    ts.slice_name,
    ts.thread_name,
    ts.slice_dur,
    s.startup_id,
    s.dur AS startup_dur
  FROM android_thread_slices_for_all_startups ts
  JOIN android_startups s ON ts.startup_id = s.startup_id
  WHERE ts.is_main_thread = 1
    AND (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
    AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
    AND ts.slice_dur > ${min_dur_ns|500000}
    -- An IO word must start a word of the name: at its start, after a
    -- non-letter, or capitalized inside it (loadFile, APKFile). A substring
    -- match read "Thread" as "read", counting thread and process lifecycle
    -- as file IO. A glued syscall name (pread64, fopen) and dlopen of a
    -- library are not counted: so loading has its own startup reason.
    AND EXISTS (
      SELECT 1 FROM io_words w
      WHERE lower(ts.slice_name) GLOB w.word || '*'
        OR lower(ts.slice_name) GLOB '*[^a-z]' || w.word || '*'
        OR ts.slice_name GLOB '*' || w.camel || '*'
    )
),
-- An IO slice inside another IO slice (database > sqlite > read) is part of
-- the outer one; only outermost IO slices add up to the startup total.
io_nesting AS (
  SELECT
    io.*,
    NOT EXISTS (
      SELECT 1
      FROM ancestor_slice(io.slice_id) a
      JOIN io outer_io ON outer_io.slice_id = a.id AND outer_io.startup_id = io.startup_id
    ) AS is_outermost
  FROM io
)
SELECT
  slice_name as io_slice,
  thread_name,
  COUNT(*) as count,
  SUM(slice_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(slice_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(slice_dur) / 1e6, 2) as max_dur_ms,
  '${startup_type}' as startup_type,
  ROUND(100.0 * SUM(slice_dur) / startup_dur, 1) as percent_of_startup,
  -- Window aggregates see every group before LIMIT: totals over the whole startup.
  ROUND(100.0 * SUM(SUM(CASE WHEN is_outermost THEN slice_dur ELSE 0 END)) OVER (PARTITION BY startup_id)
    / startup_dur, 1) as all_percent_of_startup,
  ROUND(SUM(SUM(CASE WHEN is_outermost THEN slice_dur ELSE 0 END)) OVER (PARTITION BY startup_id) / 1e6, 2)
    as all_total_dur_ms
FROM io_nesting
GROUP BY slice_name, startup_id
ORDER BY total_dur_ms DESC
LIMIT ${top_k|15}
