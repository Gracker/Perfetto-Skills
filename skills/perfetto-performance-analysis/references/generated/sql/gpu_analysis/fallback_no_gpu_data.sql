-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 16d9635bd76e3e596da0e0ef704764a78461c0e4e531aa3e272757d03a8cbba4

SELECT
  '无法执行 GPU 分析' as status,
  'gpufreq 计数器（GPU 频率数据）' as missing_data,
  '请确保 trace 采集时启用了 GPU 频率采集 (需要内核支持 gpu_frequency tracepoint)' as suggestion
UNION ALL
SELECT
  '可用替代方案' as status,
  CASE
    WHEN EXISTS (SELECT 1 FROM sqlite_master WHERE type='table' AND name='gpu_counter_track') THEN 'gpu_counter_track (可用)'
    ELSE 'gpu_counter_track (不可用)'
  END as missing_data,
  '可尝试通过 gpu_counter_track 获取 GPU 频率和利用率数据' as suggestion
