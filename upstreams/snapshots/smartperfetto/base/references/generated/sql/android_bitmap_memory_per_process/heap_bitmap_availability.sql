-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: c60050ad32c18950da78069dabe941919f7dd55aa3df9ac7ad86d51254da582d
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'heap_graph_bitmaps'
    ) THEN 1
    ELSE 0
  END AS has_heap_graph_bitmaps
