# Data-source knowledge

Start with [`perfetto_probe.py`](../../scripts/perfetto_probe.py) and the
generated [data-source guide](../generated/knowledge/knowledge-data-sources.template.md).
Probe results establish availability; they do not guarantee every requested
interval or identity is populated.

FrameTimeline usually requires Android 12+ and suitable `gfx`/`view` capture.
Scheduling needs `sched_switch` and related ftrace events. Binder, lock, block
IO, power rails, thermal sensors, heap graph, heapprofd, and GPU work-period
data each require their own capture support. Vendor tracks and slice names are
optional signals, not portable APIs.

When a source is missing, state the exact unavailable table/track and recommend
the narrowest capture addition. Do not claim that an unrecorded subsystem was
inactive.
