-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: ccca4067c8ee136de6c5a431984bc78be6e76efd3e44164776f7513e754a9c90

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
