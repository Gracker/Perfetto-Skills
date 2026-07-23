-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: c99bd1159e7f337b0d5dd490100f66e9134271d55a7bbf0362ebf64d3a1d9602
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  '无法执行 GPU 分析' as status,
  'android_gpu_frequency (GPU 频率数据)' as missing_data,
  '请确保 trace 采集时启用了 GPU 频率采集 (需要内核支持 gpu_frequency tracepoint)' as suggestion
UNION ALL
SELECT
  '可用替代方案' as status,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type='table' AND name='gpu_counter_track') THEN 'gpu_counter_track (可用)'
    ELSE 'gpu_counter_track (不可用)'
  END as missing_data,
  '可尝试通过 gpu_counter_track 获取 GPU 频率和利用率数据' as suggestion
