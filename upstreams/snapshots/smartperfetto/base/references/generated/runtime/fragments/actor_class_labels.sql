-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/actor_class_labels.sql
-- Source SHA-256: 9a412392d24ee1ebffa9ab8bbc1dc253cc38de25a683a63cc824aa1072d62bab
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- process-identity: label-only
-- (identityGate: its name comparisons label actors, they select no target
-- process, so they do not make a consuming Skill verify process identity.)

-- Inputs: ${package}, ${process_name} (string parameters; empty when no
-- target process was selected). Requires the android.process_metadata
-- stdlib module.
--
-- One process-level actor label shared by every workload / anomaly Skill so
-- the App-vs-system split is defined once. Threads with no process (no upid)
-- get no row here; consumers COALESCE the missing label to 'kernel'.
actor_class_basis AS (
  SELECT 'target=param_name_match;kernel=android_process_metadata.is_kernel_task;app=process.uid>=10000' AS actor_class_basis
),
actor_class_by_upid AS (
  SELECT p.upid,
    CASE
      WHEN ('${package}' != '' AND (p.name = '${package}' OR p.name GLOB '${package}:*'))
        OR ('${process_name}' != '' AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
        THEN 'target_app'
      WHEN COALESCE(pm.is_kernel_task, 0) = 1 AND COALESCE(p.pid, 0) > 1 THEN 'kernel'
      WHEN COALESCE(p.uid, -1) >= 10000 THEN 'other_app'
      WHEN p.name IS NOT NULL THEN 'system_service'
      ELSE 'unknown'
    END AS actor_class
  FROM process p
  LEFT JOIN android_process_metadata pm ON pm.upid = p.upid
)
