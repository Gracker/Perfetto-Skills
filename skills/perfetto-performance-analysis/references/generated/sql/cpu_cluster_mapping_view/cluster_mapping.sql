-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_cluster_mapping_view.skill.yaml
-- Source SHA-256: c5d603b71661230ea7d4c4b626a8e6e9d6ecb6844f83d8d215feb9429bf19fb1
-- Source commit: 1da78346e61c6ed087c1ac5ed1441d8849eeb810

SELECT cpu, cluster_type
FROM android_cpu_cluster_mapping
ORDER BY cpu ASC
