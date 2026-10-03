-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/gpu_frequency_by_ugpu.sql
-- Source SHA-256: cff09b8819f58e69cdbd487433b54a77d981e627e48bccf24e39da157d103fac

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: fragments/gpu_frequency_intervals.sql and
-- fragments/gpu_frequency_window.sql, listed before this fragment; the step
-- parameter ugpu (NULL for every GPU). The readable frequency intervals of
-- each GPU keyed by ugpu, for interval joins against GPU activity: running
-- frequencies in MHz and 0 while the GPU is off. gpu_ugpu_fmax is the top
-- running frequency of each GPU in the window.
gpu_ugpu_frequency AS (
  SELECT counter_id AS id, ts, dur, ugpu, freq_mhz
  FROM gpu_frequency_window
  WHERE freq_mhz IS NOT NULL
    AND (${ugpu} IS NULL OR ugpu = ${ugpu})
),
gpu_ugpu_fmax AS (
  SELECT ugpu, MAX(freq_mhz) AS fmax_mhz
  FROM gpu_ugpu_frequency
  WHERE freq_mhz > 0
  GROUP BY ugpu
)
