-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_compute_kernel_analysis.skill.yaml
-- Source SHA-256: 04ce0fdb105d89c591b8d24656540615492754eb847da9f8bec211de2a39e9df
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  'compute_kernels_without_launch_args' AS status,
  'Compute kernels are present, but their producer did not emit grid, workgroup, or typed launch arguments.' AS limitation
