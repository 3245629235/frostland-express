# Day 6 验收记录

项目：Frostland Express Demo
引擎：Godot 4.7.1，GL Compatibility，1280×720
范围：最终数值平衡（时间压缩/生存经济/战斗）、音效音量分级、Android APK 导出、完整发布验收

## 实现内容

### 数值平衡（DEMO_DESIGN §6 校准基准落地）

- `scripts/game_config.gd`
  - 新增 `TIME_COMPRESSION = 3.0`：现实 1 秒 = 游戏内 3 秒，里程按游戏时间折算
  - 食物消耗 1 → 0.2/人/tick；油耗 3 → 1.0/tick（高速 ×1.5）
  - 体温 -1/+2 → -0.25/+0.5；饥饿 -2/-5 → -0.5/-1.2；体力 -2/+1 → -0.5/+0.25
  - 站收集食物 5~15 → 30~60、燃料 3~10 → 20~40
- `scripts/game_state.gd`
  - 初始资源按 DEMO_DESIGN §2.1：food 1000 / fuel 1500 / medicine 200 / parts 100 / ammo_small 100 / ammo_large 50
  - 资源操作支持浮点（add/consume/get_resource）
  - **BUG 修复**：体温低扣血原嵌套在饥饿判断内（体温低而饥饿正常时不扣血），改为独立判断
- `scripts/travel.gd`
  - 里程推进 ×TIME_COMPRESSION（全速 100 m/s → 420km 约 23 分钟；均速 200 km/h → 约 42 分钟/圈，含站点停留后单程 30~50 分钟 ✓）
- `scripts/events_data.gd`：E5 雪地物资 10~20 → 30~60；E8 商人换汇调整为 20 燃料换 15 药 / 15 食物换 30 弹药
- `scripts/battle_data.gd`（战斗平衡）
  - 雪狼 HP 30 → 600（3 发）、劫匪 60 → 800（4 发）、持盾 120 → 1200（6 发+3 破盾）、匪首 200 → 3600（≈16 发）
  - 出怪间隔拉长：关 2 教学 2.0/1.6s；关 3 safe 2.5/3.5/3.0s、aggressive 1.8/2.5/2.2s
- `scripts/systems/battle_system.gd`：射速 2 发/秒 → 1 发/秒（触屏节奏）
- `scripts/battle.gd`：胜利奖励食物+8 → +30、弹药+10 → +30

### 音效音量分级

- `scripts/audio_fx.gd`
  - 新增 `MASTER_VOLUME = 0.8` 统一缩放（AudioStreamPlayer.volume_db = linear_to_db）
  - 各音效幅度：射击 0.18 → 0.10（高频防刺耳）、命中 0.16 → 0.14、波次 0.14/0.11 → 0.12/0.10、警报 0.12 → 0.16（强调）、胜利/失败保持 0.13

### Android / Windows 发布

- `export_presets.cfg`
  - 包名 `com.frostland.express`、versionName 0.1.0、versionCode 1、导出路径 dist/FrostlandExpress.apk
  - keystore 配置写入预设（debug/release 双密钥 + 别名）
- 生成 release 签名密钥库 `C:/Users/Mr Ray/AppData/Roaming/Godot/keystores/release.keystore`（别名 frostland，密码 frostland2026）
- 导出副本工程剔除 `addons/godot_ai` 插件与 `_mcp_game_helper` autoload 后导出
- 产物：`dist/FrostlandExpress.apk`（74MB，release 签名，arm64-v8a）+ `dist/FrostlandExpress.exe`（Windows x86_64）

## 验收结果

- [x] Day 6 专项规则测试：`Day 6 规则测试通过`（时间压缩倍率、生存资源曲线、战斗时长、Boss 限时可击杀、事件数值）
- [x] Day 5 规则回归：`Day 5 规则测试通过`
- [x] Day 4 规则回归：`Day 4 规则测试通过`（敌人数值断言已随平衡更新）
- [x] Day 3 规则回归：`Day 3 规则测试通过`
- [x] `git diff --check` 通过

### 真窗口验收（Godot AI MCP）

- [x] 生存模式 Travel：进入正常，HUD 显示速度/里程/燃料/抛锚/下一站
- [x] 资源浮点消耗生效（食物 1000 → 960 平滑下降，非整数跳变）
- [x] TIME_COMPRESSION 实测：加速段 8 秒 +1.2 km（等效 ~3.6 倍压缩含加速曲线），稳定段符合 ×3 公式
- [x] 随机事件 E4/E2 弹窗正常触发与结算（面板期间世界暂停为设计行为）
- [x] 剧情关卡 2：雪狼战斗，敌人推进扣角色 HP，点击射击命中（全员集火 235 伤害），通关进入分支选择
- [x] 剧情关卡 3 保守分支：劫匪 4 发击杀（击倒 3）、持盾 9 发击杀（3 破盾 + 6 发）、Boss 出场 30 秒限时 HUD 生效
- [x] Boss 4000 HP 实测限时内可击杀但极限（自动化 13 发 ≈ 22s 超时失败一次 → 重试 18 发 ≈ 30s 内胜利），已微调至 3600 保证熟练胜率
- [x] 第一章完整通关：Victory 页「任务完成 / 抵达极光城 / 分支：保守防守 / 幸存者 4/4」
- [x] 失败路径：Defeat 页「剧情失败：Boss 未能在 30 秒内击败」+ 统计正常
- [x] 剧情进度解锁/分支/重试记录正常（story_progress.json 独立存档）

### 发布产物验证

- [x] APK 签名验证：`apksigner verify` 通过（Signer CN=Frostland Express Demo，SHA-256 86c131f3...）
- [x] APK 内容：无 addons/godot_ai、无 tests/tools；包名 `com.frostland.express`，minSdk 24 / targetSdk 36
- [x] APK 大小 74,103,995 字节；exe 156,700,000 字节
- [x] 用户存档恢复：`game_state.json`、`train_save.json` SHA-256 与 Day 6 备份（day6_save_backup_20260822_081958）完全一致

## 已知边界

- APK 未在真机安装运行（本机无 Android 设备/模拟器连接）；已完成签名验证与包内容检查，真机冒烟待用户验证
- 生存模式 30~60 分钟单程时长按公式推演 + 里程实测验证（未整程跑完 420km）
- Android 导出通过"副本工程剔除 godot_ai"流程；正式版可考虑在导出预设配置 exclude_filter 替代副本流程
- release keystore 密码保存在本机 export_presets.cfg（开发机），正式分发需妥善保管

本轮不执行 Git commit，保留工作区差异供审阅。
