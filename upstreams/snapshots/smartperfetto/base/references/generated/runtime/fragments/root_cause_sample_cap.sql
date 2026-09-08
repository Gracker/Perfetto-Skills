-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/root_cause_sample_cap.sql
-- Source SHA-256: bc4dc74673c18b1c9eb9d993c81cc82bf02119db6c6715a7244d976a1f5a0146
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

-- Fragment: root_cause_sample_cap
-- Single source of truth for the per-session root-cause frame sample cap.
-- Both get_app_jank_frames (which truncates the frame list) and
-- batch_frame_root_cause (which reports eligible/analyzed coverage) must use
-- the same effective cap, otherwise reported coverage would not describe the
-- rows that were actually analyzed.
-- Unset, zero, and negative caps all normalize to the 200-frame default.
-- Params: ${max_frames_per_session}
root_cause_sample_config AS (
  SELECT CASE
    WHEN ${max_frames_per_session} IS NULL THEN 200
    WHEN CAST(${max_frames_per_session} AS INTEGER) <= 0 THEN 200
    ELSE CAST(${max_frames_per_session} AS INTEGER)
  END as root_cause_sample_limit_per_session
)
