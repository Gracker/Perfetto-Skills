-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: fcb998f355d4b59effa774ad1bbdf5e5f786de7a6b686385a57f6cfea779555f
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'heap_graph_bitmaps'
    ) THEN 1
    ELSE 0
  END AS has_heap_graph_bitmaps
