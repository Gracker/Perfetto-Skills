# Startup root-cause knowledge

Use the generated [startup root-cause guide](../generated/knowledge/knowledge-startup-root-causes.template.md)
after locating a real startup event. Preserve the source startup classification
and report TTID and TTFD separately when available.

Attribute phase contribution with exclusive/self time so nested slices are not
double-counted. Cross-check main-thread running, runnable, interruptible and
uninterruptible intervals. Binder, class loading/JIT, file or page IO, locks,
GC, layout/inflation, scheduling, frequency ramp, memory pressure, and first
frame are branches to verify, not a checklist of assumed causes.

Frequency below a nominal maximum can reflect workload demand, CPU placement,
idle gaps, policy, or thermal caps. Require a linked time interval and mechanism
before recommending boost, affinity, or thermal changes.
