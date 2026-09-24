GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/scene-presentation.registry.yaml
Source SHA-256: fb3a53c4d0824edec666f7555b5b25fd2228be50a439713d2719f9f9d467e28a
Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

# Scene Presentation Registry Yaml

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

```yaml
version: 1
scenes:
  scene_observation: {zh-CN: 场景观测, en: Scene observation}
  cold_start: {zh-CN: 冷启动, en: Cold start}
  warm_start: {zh-CN: 温启动, en: Warm start}
  hot_start: {zh-CN: 热启动, en: Hot start}
  scroll: {zh-CN: 滑动, en: Scroll}
  scroll_start: {zh-CN: 滑动开始, en: Scroll start}
  scroll_processing: {zh-CN: 滚动处理, en: Scroll processing}
  inertial_scroll: {zh-CN: 惯性滑动, en: Inertial scroll}
  tap: {zh-CN: 点击, en: Tap}
  long_press: {zh-CN: 长按, en: Long press}
  touch_move: {zh-CN: 连续触摸移动, en: Touch movement}
  touch_hold: {zh-CN: 持续触摸, en: Touch held}
  cancelled: {zh-CN: 输入取消, en: Input cancelled}
  input_unknown: {zh-CN: 输入状态未知, en: Input state unknown}
  key: {zh-CN: 按键输入, en: Key input}
  wheel: {zh-CN: 滚轮输入, en: Wheel input}
  scroll_input: {zh-CN: 滚动轴输入（ACTION_SCROLL）, en: Scroll axis input (ACTION_SCROLL)}
  screen_unlock: {zh-CN: 解锁, en: Screen unlock}
  back_key: {zh-CN: 返回键, en: Back}
  home_key: {zh-CN: Home 键, en: Home}
  recents_key: {zh-CN: 最近任务键, en: Recents}
  navigation: {zh-CN: 导航, en: Navigation}
  window_transition: {zh-CN: 窗口切换, en: Window transition}
  app_switch: {zh-CN: 应用切换, en: App switch}
  app_foreground: {zh-CN: 应用前台, en: App foreground}
  home_screen: {zh-CN: 桌面, en: Home screen}
  anr: {zh-CN: ANR, en: ANR}
  jank_region: {zh-CN: 严重卡顿, en: Severe jank}
  screen_on: {zh-CN: 亮屏, en: Screen on}
  screen_off: {zh-CN: 熄屏, en: Screen off}
  screen_sleep: {zh-CN: 息屏, en: Screen sleep}
  screen_unknown: {zh-CN: 屏幕状态未知, en: Screen state unknown}
  idle: {zh-CN: 空闲, en: Idle}
  notification: {zh-CN: 通知操作, en: Notification}
  split_screen: {zh-CN: 分屏操作, en: Split screen}
  pip: {zh-CN: 画中画, en: Picture in picture}
  ime_show: {zh-CN: 键盘弹出, en: Keyboard shown}
  ime_hide: {zh-CN: 键盘收起, en: Keyboard hidden}
```
