-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: 3c84f44d6c902b27eaae06e9700024c9d6954005525a587cdbf9f2863e52423b
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'heap_graph_bitmaps'
    ) THEN 1
    ELSE 0
  END AS has_heap_graph_bitmaps
