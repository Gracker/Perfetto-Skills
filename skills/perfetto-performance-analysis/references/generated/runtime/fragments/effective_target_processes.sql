-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/effective_target_processes.sql
-- Source SHA-256: 97c3b0c802ef7557d8fbd34439ec89e077945f2d24bdb32ad007c3c5cf823597
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
