-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  '无法执行 SurfaceFlinger 分析' as status,
  'SurfaceFlinger 进程不存在' as missing_data,
  '请确保 trace 采集时包含了 SurfaceFlinger 进程 (通常需要 system_server 和 surfaceflinger category)' as suggestion
