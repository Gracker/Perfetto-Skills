---
name: perfetto-performance-analysis
description: Analyze Android, Linux, and Chromium Perfetto traces with local trace_processor_shell evidence. Use for startup, scrolling or jank, input latency, ANR, CPU scheduling, memory or GC, Binder or IO, GPU or SurfaceFlinger, power or thermal, rendering-pipeline identification, trace capture guidance, scene reconstruction, and single- or multi-trace performance comparison.
license: AGPL-3.0-or-later
metadata:
  version: "0.1.0"
  source: "https://github.com/Gracker/Perfetto-Skills"
---

# Perfetto Performance Analysis

Analyze traces from evidence instead of guessing from symptom names. Use the
bundled scripts for deterministic queries and load only the references needed
for the selected workflow.

## Operating contract

1. Resolve the Skill root as the directory containing this `SKILL.md`. Convert
   script and reference paths to absolute paths before executing them; do not
   assume a client-specific environment variable exists.
2. Record every input trace path, SHA-256, requested process/thread, time range,
   and trace side before analysis.
3. Run `scripts/perfetto_probe.py` before domain queries. Treat unavailable
   tables, modules, tracks, or trace signals as limitations, not negative
   evidence.
4. Select one primary workflow below. Load its Markdown file directly, then
   follow its availability gate and evidence sequence.
5. Execute SQL through `scripts/perfetto_query.py`. Keep query source,
   parameters, trace identity, timestamps, durations, units, and returned row
   bounds with every saved result.
6. Separate observations, correlations, mechanisms, and verified root causes.
   Do not promote a hypothesis without evidence that supports the claimed
   process, thread, time window, and trace.
7. For comparisons, analyze each trace independently before computing deltas.
   Never use a missing metric on one side as proof that the other side regressed.
8. Emit the structure in `assets/report-schema.json`. List missing evidence and
   unresolved alternatives under `limitations`.

Read [the evidence contract](references/evidence/evidence-contract.md), then use
[identity rules](references/evidence/identity.md),
[missing-data rules](references/evidence/missing-data.md), and
[claim verification](references/evidence/claim-verification.md) before writing
conclusions.

## Workflow routing

- Trace health, bounds, identity, and broad triage: [trace overview](references/workflows/trace-overview.md)
- Cold, warm, hot, and first-frame startup: [startup](references/workflows/startup.md)
- Frame production, presentation, scrolling, and jank: [scrolling](references/workflows/scrolling.md)
- Touch, click, input dispatch, response, and navigation: [interaction](references/workflows/interaction.md)
- ANR, Binder, locks, futex, and blocking chains: [ANR and blocking](references/workflows/anr-blocking.md)
- CPU load, topology, frequency, idle, IRQ, and scheduler latency: [CPU scheduling](references/workflows/cpu-scheduling.md)
- RSS, heap, GC, LMK, DMA-BUF, and allocation: [memory](references/workflows/memory.md)
- GPU, SurfaceFlinger, fences, VRR, and frame composition: [GPU rendering](references/workflows/gpu-rendering.md)
- Rails, wakelocks, battery, thermal, and throttling: [power and thermal](references/workflows/power-thermal.md)
- Filesystem, block IO, network, modem, media, and WebView: [IO, network, and media](references/workflows/io-network-media.md)
- Compose, Flutter, React Native, games, and vendor signals: [frameworks and games](references/workflows/frameworks-games.md)
- Rendering architecture detection and teaching: [rendering pipeline](references/workflows/rendering-pipeline.md)
- Cross-domain event sequence reconstruction: [scene reconstruction](references/workflows/scene-reconstruction.md)
- Two or more traces or saved result sets: [trace comparison](references/workflows/trace-comparison.md)

Use [the machine-readable workflow index](references/workflow-index.json) when
selecting or validating workflow IDs.

## Runtime commands

Probe a trace:

```bash
python3 <skill-root>/scripts/perfetto_probe.py /absolute/path/to/trace.pftrace \
  --output /absolute/path/to/output/probe.json
```

Run a referenced SQL asset:

```bash
python3 <skill-root>/scripts/perfetto_query.py /absolute/path/to/trace.pftrace \
  --sql-file <skill-root>/references/generated/sql/<query>.sql \
  --format json --output /absolute/path/to/output/query.json
```

Bind SmartPerfetto DSL placeholders through the public wrapper instead of
editing SQL text. `--param NAME=JSON` safely binds scalar inputs and JSON
arrays (rendered as SQL literal lists for `IN (...)`),
`--module android.example.module` loads declared prerequisites, and
`--result NAME=/path/prior.json` exposes a non-empty saved row array as a
relation for a dependent step. Pipeline expressions such as
`${prior_step.data[0].upid}` select a scalar field from those rows:

```bash
python3 <skill-root>/scripts/perfetto_query.py /absolute/trace.pftrace \
  --sql-file <skill-root>/references/generated/sql/<skill>/<step>.sql \
  --module android.frames.timeline \
  --param 'package="com.example"' --param start_ts=123 \
  --result prior_step=/absolute/output/prior-step.json \
  --output /absolute/output/current-step.json
```

The runtime rejects unresolved placeholders and caps trace-processor stdout and
stderr at 16 MiB by default. Lower the bound with `--max-output-bytes`; increase
it only for a reviewed, explicitly bounded query.

For comparison, first write one side-summary file per independently analyzed
trace using `assets/comparison-input-schema.json`, then run
`scripts/perfetto_compare.py --side baseline=a.json --side candidate=b.json
--baseline baseline`.

If `trace_processor_shell` is unavailable, run
`scripts/bootstrap_trace_processor.py` or provide a verified executable through
`--trace-processor` or `PERFETTO_TRACE_PROCESSOR`.

## Reference discovery

Generated references are numerous. Find a SmartPerfetto Skill, SQL step, table,
or signal without loading the whole catalog:

```bash
rg -n "<skill-id|table|signal>" <skill-root>/references/generated
```

Load the directly linked result and its source provenance. Do not infer step
semantics from a filename alone.

## Compatibility

Require Python 3.11+, filesystem access, terminal execution, and a compatible
Perfetto `trace_processor_shell`. The portable instructions work in Codex,
Claude Code, OpenCode, and other clients that implement Agent Skills and expose
those capabilities. Cloud-only agents without local file or terminal access can
use the methodology references but cannot execute trace queries.
