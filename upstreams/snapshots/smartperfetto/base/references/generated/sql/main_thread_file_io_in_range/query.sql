-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_file_io_in_range.skill.yaml
-- Source SHA-256: 1e6721dae814a7a27fab828fb7d59ed2ed7389499b9e16178ec2690ef54d5ff5

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
-- method (AIDL::...::openSession); a ParcelFileDescriptor is still a file. "flush" is not here: in real traces it
-- is GPU and SurfaceFlinger work (GrOpFlushState, flush commands), not file
-- I/O. GLOB is case-sensitive.
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
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
    AND t.tid = p.pid
),
io_slices AS (
  SELECT
    s.name as io_slice,
    MIN(s.ts + s.dur, ${end_ts}) - MAX(s.ts, ${start_ts}) as clipped_dur
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN main_thread mt ON tt.utid = mt.utid
  WHERE s.ts < ${end_ts}
    AND s.ts + s.dur > ${start_ts}
    -- File IO by whole slice-name word (fragments/file_io_slice_names.sql);
    -- a SharedPreferences call is not file IO by its name alone.
    AND EXISTS (SELECT 1 FROM file_io_slice_name_words w WHERE instr(lower(s.name), w.stem) > 0)
    AND EXISTS (
      SELECT 1 FROM file_io_slice_name_patterns n
      WHERE n.io_type != 'shared_prefs'
        AND s.name GLOB n.pattern
    )
    AND NOT EXISTS (SELECT 1 FROM file_io_slice_name_exclusions x WHERE s.name GLOB x.pattern)
)
SELECT
  io_slice,
  COUNT(*) as count,
  ROUND(SUM(clipped_dur) / 1e6, 2) as total_ms,
  ROUND(AVG(clipped_dur) / 1e6, 2) as avg_ms,
  ROUND(MAX(clipped_dur) / 1e6, 2) as max_ms,
  ROUND(100.0 * SUM(clipped_dur) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as percent
FROM io_slices
WHERE clipped_dur >= ${min_dur_ns|500000}
GROUP BY io_slice
ORDER BY total_ms DESC
LIMIT ${top_k|10}
