GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/investigation-profiles.yaml
Source SHA-256: a6bd593f1a512a72d61da7c61cf80e9f7aee0b927d6aed49e940f11acbaf41b9
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

# Investigation Profiles Yaml

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## system_execution (version 1)

### cpu_frequency (cpu_frequency)

Explain per-CPU frequency and measured coverage in the relevant window. Distinguish whole-window time weighting from target-running weighting; intersect frequency, execution and requested intervals. Missing samples are unknown; observed peak is not hardware maximum or throttling proof.

Apply when: Relevant to execution latency, capacity or energy in the requested scope.

### cpu_capacity (cpu_capacity)

Relate target execution to per-CPU system busy time in the same window. Preserve CPU/ucpu, machine and topology provenance. Whole-system load is context: it alone neither proves competition nor excludes a local delay.

Apply when: Relevant to CPU service or contention in the requested scope.

### thread_state (thread_state)

Explain critical-task Running, R/R+ Runnable, S/I sleeping/idle and D/DK uninterruptible durations with a conserving window denominator and unknown coverage. Four-quadrant summaries retain medium/unknown placement. S/I is not proof of an empty message queue; D/DK requires blocker or IO evidence.

Apply when: Relevant to why identified tasks execute, wait or miss a deadline.

### cpu_placement (cpu_placement)

Explain critical-task residency on actual CPUs and little/medium/big/unknown clusters, migrations and provenance. Keep per-task, process and system denominators distinct. Do not map absent topology to little, infer cache misses from migrations, or equate quadrant proportions with a cause.

Apply when: Relevant to target CPU execution, heterogeneous capacity or energy.

### preemption (preemption)

Examine relevant scheduling delay and R+ switch-out boundaries, preserving victim/next-task UTID/UPID, CPU/ucpu, sched IDs and timestamps. Establish the event population from covered scheduler intervals: zero is observed only with sufficient coverage; when count is positive inspect exact handoffs. An exact same-ucpu next task is an observed handoff, not proof of preemption motive or attributable delay. Ordinary R queueing is separate. Retain peer identity.

Apply when: Relevant to Runnable delay or an execution interruption on the critical path.

### scheduling_policy (scheduling_policy)

Report observed kernel priority separately from actual FIFO/RR/OTHER/DEADLINE policy, nice, affinity, cgroup and uclamp. State which fields lack direct evidence; priority alone proves none of those policies. Do not recommend enabling RT or fixed uclamp from latency, priority or residency alone.

Apply when: Relevant to a scheduling or placement explanation about identified tasks.

## causal_reasoning (version 1)

### finding_coverage (causal_reasoning)

In the visible answer, explain every distinct material application phase/task, related system effect and anomaly supported by returned evidence within the requested scope. Each finding has adjacent readable evidence (interval, identity, measurement/unit/denominator and operation/state), mechanism or explicit uncertainty, and performance impact. Include actual source-based explanations when available; hidden declarations or aggregate tables alone do not fulfill this obligation. Preserve unresolved findings and explain rejected/superseded ones. Do not inflate alerts into causes or require an arbitrary finding count, fixed format or unrelated scene-wide investigation.

### dependency_chain (dependency_chain)

Connect observed work and waits to the selected performance goal using task intervals and available slice/flow/wakeup/Binder/lock/IO/render evidence. Preserve alternatives, unresolved links and missing capabilities; overlapping activity is not causation. Investigate a dependency only when it can explain the relevant path. Read evidence rows, not just artifact names or counts.

### supported_recommendations (causal_reasoning)

Put supported root-cause detail, quantitative evidence and relevant App/system remedies in the current body. State unavailable dimensions and causal limits. A short overview may precede detail but cannot replace it or defer required reasoning. No prescribed headings, prose length or fixed tool sequence.

## result_comparison (version 1)

### comparable_system_evidence (comparison)

Compare only compatible evidence across explicitly identified trace sides, windows, process instances, sampling coverage, units and denominators. Keep absent saved dimensions not_checked; a missing metric is not zero or absence of a problem. Saved-result comparison uses stored provenance and does not silently fetch either raw trace to fill gaps. Separate observed deltas from causes.

## scene_reconstruction (version 1)

### scene_input_observations (scene_input)

Reconstruct observed input actions with exact intervals and available device, channel, display and target identities. Preserve partial dispatch, missing action, cancellation and open gesture boundaries. Distinguish physical events from delivery recipients. Missing input is unknown, not evidence of inactivity or a completed gesture.

### scene_device_observations (scene_device)

Explain observed device state and changes separately from user action, including screen, charging and committed device state plus other relevant sources when captured. Preserve raw values and source coverage. Screen state is not lock state; vendor device state numbers do not establish posture without configuration evidence. Initial state before its first observation remains unknown unless a prior observation supports carry-in.

### scene_application_response (scene_response)

Relate user input to observed window, application lifecycle and rendering responses only with compatible time and object evidence. Preserve alternatives, process instances, multiple windows/displays and unresolved ownership. ACK completion is not display completion; simultaneous activity does not prove attribution or causation.

### scene_scan_coverage (scene_coverage)

Account for the whole requested trace range, including observed, unscanned and unknown intervals. Read complete available artifact pages; distinguish transport pagination from producer SQL truncation. Window further acquisition when needed, carry preceding states and unfinished gestures, and deduplicate stable event identities across boundaries. Preserve failures, truncation and exhausted budgets.

### scene_finding_coverage (scene_findings)

In the visible account, retain every distinct material user-operation phase, device transition and application response supported within the requested scope. Include adjacent readable intervals, identities and observed values or source limitations. A short overview or hidden structured timeline cannot replace the explanation of material findings; preserve late-trace observations and unresolved alternatives without turning reconstruction into an unrelated performance-remediation task.

### scene_candidate_revision (scene_revision)

Maintain the structured timeline through current-run candidate deltas. Explain every segment's user action, device state and application response, including explicit unknowns, using exact boundaries and original evidence locators. Investigate competing explanations and correct segment identity, boundaries or dependencies when evidence changes. Proposal acceptance and finite checks do not establish semantic verification or full coverage.
