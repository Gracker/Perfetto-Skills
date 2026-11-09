-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 163b0bfbab7564b735a5ceffe7d26e5eb48238a44ba9247b121603efb1463762

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
