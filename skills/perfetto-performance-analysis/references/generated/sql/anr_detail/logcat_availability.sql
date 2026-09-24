-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 69869c165513d6e975cde75d83230b412b1276132fd888e9d2fbf6a898cc2db3
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type IN ('table', 'view') AND name = 'android_logs'
  ) THEN 1 ELSE 0 END AS has_android_logs
