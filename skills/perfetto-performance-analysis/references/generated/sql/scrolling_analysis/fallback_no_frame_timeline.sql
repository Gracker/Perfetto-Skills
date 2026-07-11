-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  '⚠️ 无法执行帧分析' as status,
  'actual_frame_timeline_slice' as missing_table,
  '请确保 trace 采集时启用了 Frame Timeline (需要 Android 12+ 且开启 Choreographer tracing)' as suggestion
UNION ALL
SELECT
  'ℹ️ 可用替代方案' as status,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type='table' AND name='frame_slice') THEN 'frame_slice (可用)'
    ELSE 'frame_slice (不可用)'
  END as missing_table,
  '可尝试使用 frame_slice 进行基础帧耗时分析' as suggestion
