GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/scene-presentation.registry.yaml
Source SHA-256: c8d1dcd7dc7c8d0ff40f0e005942a8a3313071f0306352c79305dc958f996f13
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
  cold_start: {zh-CN: 冷启动, en: Cold start}
  warm_start: {zh-CN: 温启动, en: Warm start}
  hot_start: {zh-CN: 热启动, en: Hot start}
  scroll: {zh-CN: 滑动, en: Scroll}
  scroll_start: {zh-CN: 滑动开始, en: Scroll start}
  inertial_scroll: {zh-CN: 惯性滑动, en: Inertial scroll}
  tap: {zh-CN: 点击, en: Tap}
  long_press: {zh-CN: 长按, en: Long press}
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
  idle: {zh-CN: 空闲, en: Idle}
  notification: {zh-CN: 通知操作, en: Notification}
  split_screen: {zh-CN: 分屏操作, en: Split screen}
  pip: {zh-CN: 画中画, en: Picture in picture}
  ime_show: {zh-CN: 键盘弹出, en: Keyboard shown}
  ime_hide: {zh-CN: 键盘收起, en: Keyboard hidden}
```
