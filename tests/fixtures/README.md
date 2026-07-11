# Integration trace fixtures

Large trace files are not committed to this repository. Set
`SMARTPERFETTO_TEST_TRACES` to a directory containing the six SmartPerfetto test
traces and set `PERFETTO_TRACE_PROCESSOR` to the matching checksum-pinned
`trace_processor_shell`.

Required fixtures:

- `launch_light.pftrace`
- `lacunh_heavy.pftrace`
- `scroll_Standard-AOSP-App-Without-PreAnimation.pftrace`
- `Scroll-Flutter-327-TextureView.pftrace`
- `Scroll-Flutter-SurfaceView-Wechat-Wenyiwen.pftrace`
- `scroll-demo-customer-scroll.pftrace`

Tests skip honestly when the directory is not configured. When configured,
missing named fixtures are failures.
