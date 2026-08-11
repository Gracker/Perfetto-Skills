-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_cluster_mapping_view.skill.yaml
-- Source SHA-256: c5d603b71661230ea7d4c4b626a8e6e9d6ecb6844f83d8d215feb9429bf19fb1
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

SELECT cpu, cluster_type
FROM android_cpu_cluster_mapping
ORDER BY cpu ASC
