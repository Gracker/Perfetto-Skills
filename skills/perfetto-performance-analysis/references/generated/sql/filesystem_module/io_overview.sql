-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: 18dec147f2bfaecf6ae89f2942cc87828fb95e48502a1ff7633dd43fe54fa3d3

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
candidates AS (
  SELECT s.id, s.name, s.dur
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND s.dur > 100000  -- > 0.1ms
    AND EXISTS (SELECT 1 FROM file_io_slice_name_words w WHERE instr(lower(s.name), w.stem) > 0)
    AND EXISTS (SELECT 1 FROM file_io_slice_name_patterns n WHERE s.name GLOB n.pattern)
    AND NOT EXISTS (SELECT 1 FROM file_io_slice_name_exclusions x WHERE s.name GLOB x.pattern)
),
-- One type per slice, in this order, when its name names several.
io_slices AS (
  SELECT
    c.dur,
    CASE MIN(CASE n.io_type
      WHEN 'read' THEN 1 WHEN 'write' THEN 2 WHEN 'database' THEN 3
      WHEN 'shared_prefs' THEN 4 WHEN 'open' THEN 5 WHEN 'sync' THEN 6 ELSE 7
    END)
      WHEN 1 THEN 'read' WHEN 2 THEN 'write' WHEN 3 THEN 'database'
      WHEN 4 THEN 'shared_prefs' WHEN 5 THEN 'open' WHEN 6 THEN 'sync' ELSE 'other'
    END AS io_type
  FROM candidates c
  JOIN file_io_slice_name_patterns n ON c.name GLOB n.pattern
  GROUP BY c.id
)
SELECT
  io_type,
  COUNT(*) AS operation_count,
  CAST(SUM(dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(dur) / 1e6 AS REAL) AS max_ms
FROM io_slices
GROUP BY io_type
ORDER BY total_ms DESC
