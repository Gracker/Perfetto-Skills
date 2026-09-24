-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: 1b5b8388a9a3b0ee3fbe651cab6e8b3ccd6b2258a0c3313e7633833fb896f08c
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'heap_graph_bitmaps'
    ) THEN 1
    ELSE 0
  END AS has_heap_graph_bitmaps
