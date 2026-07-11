-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_thread_utilization_period.skill.yaml
-- Source SHA-256: ce8310da44dc38f1cb55bd3e6768d15e6959ac0130ef320d511f5ba7d4a9deb6
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  process_name,
  thread_name,
  ROUND(utilization, 4) AS utilization
FROM cpu_thread_utilization_per_period
WHERE (process_name GLOB '${process_name}*' OR '${process_name}' = '')
ORDER BY utilization DESC
LIMIT ${top_n|30}
