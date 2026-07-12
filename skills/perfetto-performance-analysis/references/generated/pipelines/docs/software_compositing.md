GENERATED FILE - DO NOT EDIT.
Source: docs/rendering_pipelines/software_compositing.md
Source SHA-256: e383bf12af8e0d400cd0c319b643041678621027ec07bdcad09aad6b901eb200
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

# Software Compositing Pipeline

软件合成是 SurfaceFlinger 在 HWC/GPU 合成不可用或不适合时的降级路径。它通常意味着更多 CPU 像素处理、SurfaceFlinger 主线程耗时增加，以及更高的显示延迟风险。

## 典型触发场景

- Layer 数量超过硬件叠加层能力。
- 像素格式、混合模式或安全内容限制导致 HWC 不能直接合成。
- GPU 合成不可用、过载或被调试配置禁用。
- 特定 OEM 降级路径或显示策略触发 client composition。

## 典型链路

```mermaid
sequenceDiagram
  participant App as App
  participant BQ as BufferQueue
  participant SF as SurfaceFlinger
  participant HWC as HWC validate
  participant CPU as CPU compositor
  participant Display as Display

  App->>BQ: queueBuffer
  SF->>SF: handleMessageRefresh
  SF->>SF: latchBuffer
  SF->>HWC: validateDisplay
  HWC-->>SF: client composition required
  SF->>CPU: software composite layers
  CPU-->>SF: composed target
  SF->>Display: presentDisplay
```

## 线程角色

| 线程 | 职责 | 常见 trace 线索 |
|---|---|---|
| `SurfaceFlinger` | 合成调度、HWC validate、client composition | `handleMessageRefresh`, `validateDisplay`, `composite`, `presentDisplay` |
| App producer | 提交图层 buffer | `queueBuffer`, `dequeueBuffer` |
| HWC / display service | 决定 Layer composition type | `validateDisplay`, `presentDisplay` |

## 性能关注点

- SurfaceFlinger 主线程是否超过一个 VSync 周期。
- client composition layer 数量是否异常增加。
- 是否伴随 refresh rate、分辨率、secure layer 或 overlay 限制变化。
- App 侧是否频繁创建/销毁 Surface 或提交过多小 Layer。

## SmartPerfetto 检测信号

`pipeline_software_compositing` 主要依赖：

- `SurfaceFlinger` 线程存在。
- `handleMessageRefresh`
- `commit`
- `composite`
- `validateDisplay`
- `presentDisplay`

检测会排除明显 GPU completion 或 `eglSwapBuffers` 主导的普通 GPU 合成路径。
