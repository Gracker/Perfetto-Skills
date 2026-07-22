-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  printf('%d', ts) as event_ts,
  power_state,
  ROUND(dur / 1e9, 2) as duration_sec
FROM android_suspend_state
WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY dur DESC
LIMIT 20
