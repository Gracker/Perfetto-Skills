-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_cluster_mapping_view.skill.yaml
-- Source SHA-256: c5d603b71661230ea7d4c4b626a8e6e9d6ecb6844f83d8d215feb9429bf19fb1
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT cpu, cluster_type
FROM android_cpu_cluster_mapping
ORDER BY cpu ASC
