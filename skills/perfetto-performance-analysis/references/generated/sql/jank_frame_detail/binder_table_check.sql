-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 0403339f9ba204e964aa7ccab7130157ed7149b13da3cfd63bb807484e4bbb96
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_binder_txns'
    ) THEN 1
    ELSE 0
  END as has_binder_table
