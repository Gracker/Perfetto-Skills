-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_file_io_in_range.skill.yaml
-- Source SHA-256: 339af7b0f12c8f2d22177026b1aaf2cb39f860016191544bf28833db40d9a076

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- No input CTE. Slice names that name file, database or disk I/O. A slice is
-- I/O when one of these words is a whole word of its name and it matches no
-- exclusion. Consumers test the lower-cased stem first, which rejects most
-- names before any GLOB pattern runs (about 9x faster on a full trace):
--   EXISTS (SELECT 1 FROM file_io_slice_name_words w
--           WHERE instr(lower(s.name), w.stem) > 0)
--   AND EXISTS (SELECT 1 FROM file_io_slice_name_patterns n
--               WHERE s.name GLOB n.pattern)
--   AND NOT EXISTS (SELECT 1 FROM file_io_slice_name_exclusions x
--                   WHERE s.name GLOB x.pattern)
-- and filter n.io_type to the kinds they count.
--
-- A word starts the name or follows a non-letter, in either case of its first
-- letter, or starts a camelCase word anywhere (readFile, SQLiteDatabase); it
-- ends the name or comes before a character that is not a lower-case letter.
-- A substring match read "Thread" as "read" and "isReady" as "Read". A glued
-- syscall name (pread64, fopen) and dlopen of a library are not counted.
-- Excluded although they carry an I/O word: Parcel and proto serialization
-- (readFromParcel, writeToProto), read/write locks, OpenGL, ART work named
-- after the code it handles (JIT compiling of a java.io.File method, code
-- cache writes, class definition and dex registration, GC waits, lock
-- contention at a method) and Binder calls named after their interface
-- method (AIDL::...::openSession); a ParcelFileDescriptor is still a file.
-- "flush" is not here: in real traces it is GPU and SurfaceFlinger work
-- (GrOpFlushState, flush commands), not file I/O. GLOB is case-sensitive.
--
-- An all-caps word (READ, OPEN, FILE) is deliberately not a form of a word: in
-- the six canonical traces, the constructed corpus and a dozen local device
-- traces the only all-caps I/O word is the WindowManager transition type OPEN
-- (playTransition: OPEN, Transition-OPEN#409), which is not file I/O.
file_io_slice_name_words(io_type, stem, word, camel) AS (
  VALUES
    ('open', 'open', '[Oo]pen', 'Open'),
    ('open', 'openat', '[Oo]penat', 'Openat'),
    ('read', 'read', '[Rr]ead', 'Read'),
    ('read', 'readahead', '[Rr]eadahead', 'Readahead'),
    ('write', 'write', '[Ww]rite', 'Write'),
    ('sync', 'fsync', '[Ff]sync', 'Fsync'),
    ('sync', 'fdatasync', '[Ff]datasync', 'Fdatasync'),
    ('database', 'sqlite', '[Ss][Qq][Ll]ite', 'SQLite'),
    ('database', 'sqlite', '[Ss][Qq][Ll]ite', 'Sqlite'),
    ('database', 'database', '[Dd]atabase', 'Database'),
    ('shared_prefs', 'sharedpreferences', '[Ss]haredPreferences', 'SharedPreferences'),
    ('file', 'file', '[Ff]ile', 'File'),
    ('file', 'disk', '[Dd]isk', 'Disk')
),
file_io_slice_name_leads(lead, camel_only) AS (
  VALUES ('', 0), ('*[^A-Za-z]', 0), ('*', 1)
),
file_io_slice_name_trails(trail) AS (
  VALUES (''), ('[^a-z]*')
),
file_io_slice_name_patterns(io_type, pattern) AS (
  SELECT w.io_type, l.lead || CASE WHEN l.camel_only THEN w.camel ELSE w.word END || t.trail
  FROM file_io_slice_name_words w, file_io_slice_name_leads l, file_io_slice_name_trails t
),
file_io_slice_name_exclusions(pattern) AS (
  VALUES
    ('*[Ff]romParcel*'), ('*[Tt]oParcel*'), ('*Parcel.*'), ('*Parcel::*'),
    ('*[Pp]roto*'),
    ('*[Rr]ead[Ll]ock*'), ('*[Ww]rite[Ll]ock*'), ('*[Rr]ead[Ww]rite[Ll]ock*'),
    ('*[Oo]pen[Gg][Ll]*'),
    ('JIT compiling *'), ('*ScopedCodeCache*'), ('DefineClass_*'), ('RegisterDexFile*'),
    ('GC:*'), ('*Wait For Completion*'), ('*[Cc]ontention*'),
    ('AIDL::*'), ('HIDL::*'), ('L*;')
)
,
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
    -- File IO by whole slice-name word (fragments/file_io_slice_names.sql);
    -- a SharedPreferences call is not startup file IO by its name alone.
    AND EXISTS (SELECT 1 FROM file_io_slice_name_words w WHERE instr(lower(ts.slice_name), w.stem) > 0)
    AND EXISTS (
      SELECT 1 FROM file_io_slice_name_patterns n
      WHERE n.io_type != 'shared_prefs'
        AND ts.slice_name GLOB n.pattern
    )
    AND NOT EXISTS (SELECT 1 FROM file_io_slice_name_exclusions x WHERE ts.slice_name GLOB x.pattern)
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
