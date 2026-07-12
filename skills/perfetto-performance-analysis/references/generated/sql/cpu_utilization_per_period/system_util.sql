-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_utilization_per_period.skill.yaml
-- Source SHA-256: 0df1c92c4e548e72bb7d5e6ddb73270df2ea13c89ff46b4726d0877431b0852a
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  ts,
  ROUND(dur / 1e6, 1) AS dur_ms,
  ROUND(utilization, 4) AS utilization
FROM cpu_utilization_per_period
ORDER BY ts ASC
