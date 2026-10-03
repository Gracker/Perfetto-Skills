-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 22cd4dfce1fd88d4610a41825267b0c17ab31811b871551db13a6719c8466f52

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
SELECT
  printf('%d', s.ts) as block_ts,
  printf('%d', s.dur) as dur_ns,
  s.name as blocking_op,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  CASE
    WHEN s.name GLOB '*inflate*' OR s.name GLOB '*LayoutInflater*' OR s.name GLOB '*setContentView*' THEN 'layout_inflate'
    WHEN s.name GLOB '*database*' OR s.name GLOB '*SQL*' OR s.name GLOB '*sqlite*' THEN 'database'
    WHEN s.name GLOB '*Binder*' OR s.name GLOB '*binder*' THEN 'binder'
    WHEN s.name GLOB '*SharedPreferences*' THEN 'shared_prefs'
    WHEN s.name GLOB '*GC*' OR s.name GLOB '*collector*' THEN 'gc'
    -- File IO by whole slice-name word (fragments/file_io_slice_names.sql).
    WHEN EXISTS (SELECT 1 FROM file_io_slice_name_words w WHERE instr(lower(s.name), w.stem) > 0)
      AND EXISTS (SELECT 1 FROM file_io_slice_name_patterns n WHERE s.name GLOB n.pattern)
      AND NOT EXISTS (SELECT 1 FROM file_io_slice_name_exclusions x WHERE s.name GLOB x.pattern) THEN 'file_io'
    WHEN s.name GLOB '*network*' OR s.name GLOB '*http*' OR s.name GLOB '*okhttp*' THEN 'network'
    ELSE 'other'
  END as block_type,
  CASE
    WHEN s.dur / 1e6 > 50 THEN 'critical'
    WHEN s.dur / 1e6 > ${binder_blocking_ms|16} THEN 'warning'
    WHEN s.dur / 1e6 > ${blocking_op_min_dur_ms|5} THEN 'notice'
    ELSE 'normal'
  END as severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.tid = p.pid
  AND p.name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND s.dur > ${blocking_op_min_dur_ms|5} * 1000000
  AND s.name NOT GLOB '*performCreate*'
  AND s.name NOT GLOB '*performStart*'
  AND s.name NOT GLOB '*performResume*'
  AND s.name NOT GLOB '*performPause*'
  AND s.name NOT GLOB '*performStop*'
  AND s.name NOT GLOB '*performDestroy*'
  AND s.name NOT GLOB '*activityStart*'
  AND s.name NOT GLOB '*activityResume*'
ORDER BY s.dur DESC
LIMIT 30
