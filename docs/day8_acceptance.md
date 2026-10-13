# Day 8 验收记录 —— 全游戏音乐与音效

项目：Frostland Express Demo
引擎：Godot 4.7.1，GL Compatibility，1280×720
范围：全部场景背景音乐（程序合成循环 BGM）+ 全部功能音效（交互/收集/到站/战斗等）

## 实现内容

### 新增 `scripts/audio_manager.gd`（全局 Autoload：AudioManager）

- **BGM 系统**：7 首程序合成循环音乐（AudioStreamWAV LOOP_FORWARD，22050Hz 16-bit），运行时生成、不依赖外部音频文件：
  | 曲目 | 场景 | 风格 | 时长 |
  |------|------|------|------|
  | title | 标题页 | A 小调慢速琶音（雪原空旷感） | 20s |
  | main | 主界面/编组/人员编成 | C 大调温暖中速 | 14s |
  | travel | 登车行驶 | E 小调八分低音推进（五度动机） | 12s |
  | battle | 实时战斗 | D 小调 138bpm 紧张低音 | 12s |
  | story | 剧情目录/开场/分支 | G 大调叙事 | 16s |
  | victory | 胜利结算 | C 大调 120bpm 上行欢快 | 10s |
  | defeat | 失败结算 | A 小调慢速下行低沉 | 20s |
  - 多声部叠加合成（低音 + 旋律），正弦/方波/三角波 + ADSR 包络，归一化防削波
  - `play_bgm(id)` 切换（同曲不重启）、`stop_bgm()`、主音量 -10dB
- **SFX 统一入口**：转发 AudioFx + `switch_scene()` 便捷方法

### 扩展 `scripts/audio_fx.gd`（新增 12 个通用音效）

- 点击 play_click / 返回 play_back / 收集完成 play_collect / 维修 play_repair / 补给 play_supply
- 到站钟声 play_arrive / 事件弹窗 play_event / 汽笛 play_whistle / 刹车 play_brake / 失败操作 play_error
- 角色选中 play_select / 出发 play_depart
- 原有战斗音效（射击/命中/波次/警报/胜利/失败）保留

### 场景接入（13 个文件）

| 场景 | BGM | 音效 |
|------|-----|------|
| title_screen | title | 开始/剧情按钮 click |
| main | main | 编组/登车/人员编成 click |
| team | main | 返回 back |
| team_select | main | 返回 back、确认 click |
| travel | travel | 加速汽笛、刹车、返回、事件弹窗、到站钟声、锅炉/物资箱 click、维修台 repair、收集完成×2、离站 depart、选中角色 select |
| battle | battle | 原有战斗音效保留 |
| story_hub / story_intro / story_transition | story | click / back / 分支 click |
| victory | victory | 返回 click |
| defeat | defeat | 重试 click、回标题 back |
| event_dialog | —（弹窗） | 选项 click |
| station_panel | —（弹窗） | 四个动作 click |

### 测试

- `tests/day8_audio_test.gd`：7 首 BGM 合成完整性（数据非空、时长 5~20s、loop 有效）+ 18 个 SFX 方法存在性

## 验收结果

- [x] Day 8 音频测试：`Day 8 音频测试通过`
- [x] Day 3~7 全量回归：全部通过（`git diff --check` 干净）
- [x] 真窗口（Godot MCP）：
  - 标题页自动播放 title BGM（playing=true，20s 循环）
  - 点开始 → Main 自动切换 main BGM
  - 登车 → Travel 自动切换 travel BGM
  - 剧情关卡 2 → Battle 自动切换 battle BGM
  - 手动触发 play_bgm 验证合成/播放链路正常
- [x] 用户存档恢复：game_state.json / train_save.json SHA-256 与备份一致；剧情进度复原

## 已知边界

- BGM 为程序合成（无真实乐器采样），风格偏"8-bit/合成器"，追求氛围而非写实；若需真人感音乐需外部音频资产
- 音量固定（BGM -10dB / SFX -4dB），暂无游戏内音量设置界面（后续可加）
- headless 测试不实际出声（节点不在场景树），真窗口已验证播放链路

本轮不执行 Git commit，保留工作区差异供审阅。
