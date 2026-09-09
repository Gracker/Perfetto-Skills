-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 59c8f596d0111ef62440eb05318e85cfc2368d1d0b62d50ed6b1147b21e58aac
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  '无法执行 SurfaceFlinger 分析' as status,
  'SurfaceFlinger 进程不存在' as missing_data,
  '请确保 trace 采集时包含了 SurfaceFlinger 进程 (通常需要 system_server 和 surfaceflinger category)' as suggestion
