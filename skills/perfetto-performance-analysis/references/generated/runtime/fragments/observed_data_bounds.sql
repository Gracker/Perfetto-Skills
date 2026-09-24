-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/observed_data_bounds.sql
-- Source SHA-256: 05853d32a47512244b61b489b0553a40b8187ab21537ad55ca130499ae922171
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- The recorded data range a window may be clipped to. `trace_bounds` can
-- start well before the first scheduler sample (clock snapshots, early
-- metadata), so "data start" is the first sched_slice when one exists.
-- A lookback window that reaches before this point is reported as clipped,
-- never silently extended into unrecorded time.
observed_data_bounds AS (
  SELECT
    COALESCE((SELECT MIN(ts) FROM sched_slice), (SELECT start_ts FROM trace_bounds)) AS data_start_ts,
    (SELECT end_ts FROM trace_bounds) AS data_end_ts
)
