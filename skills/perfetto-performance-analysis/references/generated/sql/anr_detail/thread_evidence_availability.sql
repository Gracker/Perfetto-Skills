-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 69869c165513d6e975cde75d83230b412b1276132fd888e9d2fbf6a898cc2db3
-- Source commit: 12f4004d5cdc2aeac76d3afce68ef2e3e87d500f

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'thread_state'
  ) THEN 1 ELSE 0 END AS has_thread_state,
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'thread_track'
  ) THEN 1 ELSE 0 END AS has_thread_track,
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'slice'
  ) THEN 1 ELSE 0 END AS has_slice
