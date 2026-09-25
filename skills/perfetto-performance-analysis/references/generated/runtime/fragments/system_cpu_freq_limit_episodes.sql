-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/system_cpu_freq_limit_episodes.sql
-- Source SHA-256: 1982e5efbe0a9f772b45bbc48a9a30fa7d79d56eb1270a14af757d8132f4e5a3
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Requires fragments/system_cpu_freq_limit_spans.sql to be injected FIRST and
-- system_windows(window_id, window_start_ts, window_end_ts) to exist.
--
-- A max-limit span counts as capped when it sits below the per-policy observed
-- reference by more than ${episode_drop_pct|10} percent. Consecutive capped
-- spans separated by a gap shorter than ${merge_gap_ms|500} ms become ONE
-- episode: kernel governors re-write the limit every few tens of milliseconds,
-- so the raw event stream would otherwise report hundreds of "episodes" for a
-- single continuous mitigation.
--
-- Both thresholds are inputs. They bound what is reported, not what happened.
-- `starts_at_data_start` marks an episode whose first capped span is the very
-- first observed sample of that track: the onset is outside the recorded data
-- and is unknown, not "the limit began here".
system_cpu_freq_limit_capped_spans AS (
  SELECT s.*
  FROM system_cpu_freq_limit_spans s
  WHERE s.kind = 'max'
    AND s.dur_ns > 0
    AND s.reference_max_limit_khz > 0
    AND s.limit_khz < s.reference_max_limit_khz * (1.0 - (${episode_drop_pct|10}) / 100.0)
),
system_cpu_freq_limit_capped_marked AS (
  SELECT s.*,
    LAG(s.clipped_end_ts) OVER (
      PARTITION BY s.window_id, s.policy_cpu
      ORDER BY s.clipped_start_ts, s.counter_id
    ) AS prev_capped_end_ts
  FROM system_cpu_freq_limit_capped_spans s
),
system_cpu_freq_limit_capped_grouped AS (
  SELECT m.*,
    SUM(CASE WHEN m.prev_capped_end_ts IS NULL
      OR m.clipped_start_ts - m.prev_capped_end_ts >= CAST((${merge_gap_ms|500}) * 1000000 AS INTEGER)
      THEN 1 ELSE 0 END) OVER (
      PARTITION BY m.window_id, m.policy_cpu
      ORDER BY m.clipped_start_ts, m.counter_id
      ROWS UNBOUNDED PRECEDING
    ) AS episode_seq
  FROM system_cpu_freq_limit_capped_marked m
),
system_cpu_freq_limit_episodes AS (
  SELECT
    g.window_id,
    g.policy_cpu,
    g.episode_seq,
    printf('policy%d-ep%d', g.policy_cpu, g.episode_seq) AS episode_id,
    MAX(g.ucpu) AS ucpu,
    MAX(g.machine_id) AS machine_id,
    MAX(g.capacity) AS capacity,
    MAX(g.core_type) AS core_type,
    MAX(g.topology_source) AS topology_source,
    MIN(g.clipped_start_ts) AS episode_start_ts,
    MAX(g.clipped_end_ts) AS episode_end_ts,
    MAX(g.clipped_end_ts) - MIN(g.clipped_start_ts) AS episode_dur_ns,
    MIN(g.limit_khz) AS min_limit_khz,
    MAX(g.limit_khz) AS max_limit_khz_in_episode,
    MAX(g.reference_max_limit_khz) AS reference_max_limit_khz,
    MAX(g.reference_basis) AS reference_basis,
    ROUND(100.0 * (MAX(g.reference_max_limit_khz) - MIN(g.limit_khz))
      / NULLIF(MAX(g.reference_max_limit_khz), 0), 1) AS depth_pct,
    COUNT(*) AS change_count,
    MAX(CASE WHEN g.is_first_max_sample THEN 1 ELSE 0 END) AS starts_at_data_start,
    MAX(CASE WHEN g.is_last_max_sample THEN 1 ELSE 0 END) AS ends_at_data_end,
    MAX(CASE WHEN g.left_censored THEN 1 ELSE 0 END) AS clipped_at_window_start,
    MAX(CASE WHEN g.right_censored THEN 1 ELSE 0 END) AS clipped_at_window_end,
    MAX(g.limit_source) AS limit_source,
    CASE WHEN MAX(CASE WHEN g.is_first_max_sample THEN 1 ELSE 0 END) = 1
        OR MAX(CASE WHEN g.is_last_max_sample THEN 1 ELSE 0 END) = 1
        OR MAX(CASE WHEN g.left_censored THEN 1 ELSE 0 END) = 1
        OR MAX(CASE WHEN g.right_censored THEN 1 ELSE 0 END) = 1
      THEN 'partial' ELSE 'observed' END AS evidence_status,
    'observation_not_causal' AS evidence_scope
  FROM system_cpu_freq_limit_capped_grouped g
  GROUP BY g.window_id, g.policy_cpu, g.episode_seq
)
