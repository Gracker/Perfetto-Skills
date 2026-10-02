-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 4d6e1ad9bf86293bfb2b3488cd30b3ff6d382e7560b18a6923e32b2150de4e27

SELECT
  '无法执行 SurfaceFlinger 分析' as status,
  'SurfaceFlinger 进程不存在' as missing_data,
  '请确保 trace 采集时包含了 SurfaceFlinger 进程 (通常需要 system_server 和 surfaceflinger category)' as suggestion
