# Day 7 验收记录

项目：Frostland Express Demo
引擎：Godot 4.7.1，GL Compatibility，1280×720
范围：生存整圈闭环实测、Android 导出一键化、发布打磨（图标/启动画面/README）、模拟器冒烟、全量回归

## 实现内容

### 平衡修正（整圈推演发现）

- `scripts/game_config.gd`：站收集燃料 20~40 → 30~60（均速 200 km/h 整圈燃料需求 1890，原补给上限不足）
- `scripts/game_state.gd`：初始燃料 1500 → 2000（均速 200 km/h 整圈高速油耗 1890 + 站点停留油耗，1500 会中途抛锚）
- **BUG-012 修复**：`scripts/systems/station_system.gd::collect_reward` 原硬编码 5~15/3~10（Day 6 改漏），改为按 GameConfig 区间映射（真窗口实测 +38/+51）

### 测试

- `tests/day7_logic_test.gd`：生存整圈模拟（三档速度 120/200/360 km/h × 420km 逐 tick 推进，含站点停留/补给/体温曲线）+ 站点收集区间断言
  - 均速 200 km/h：单程 43.5 分钟（30~60 目标 ✓）、4 站全到、食物剩 90、燃料剩 221
  - 全速 360 km/h：24.8 分钟、燃料充足
  - 慢速 120 km/h：71.5 分钟（超目标属设计内——慢速长程低效，资源耗尽可失败）

### 发布工具链

- `tools/export_release.py`：一键发布脚本（复制项目 → 剔除 addons/godot_ai + 调试 autoload/插件 → Godot headless 导出 → 复制回 dist/），支持 `--apk` / `--exe`
- `tools/generate_app_icon.py`：程序生成应用图标（蒸汽火车头剪影 + 雪原暮色背景）
- `assets/icon_app_192.png`（主图标）、`assets/icon_adaptive_fg_432.png`、`assets/icon_adaptive_bg_432.png`
- `export_presets.cfg`：填入图标、禁用 Godot boot splash（`splash_screen/disable_godot_boot_splash=true`）
- `README.md` 重写：玩法说明、安装指南、开发/发布流程、文档索引

## 验收结果

- [x] Day 7 专项测试：`Day 7 规则测试通过`
- [x] Day 6 回归：`Day 6 规则测试通过`（燃料断言已随 2000 初始更新）
- [x] Day 5 / Day 4 / Day 3 回归全部通过
- [x] `git diff --check` 通过

### 真窗口验收（Godot AI MCP）

- [x] 生存模式到站闭环：注入里程 79.5km → 行驶至白桦林站（80km），站点面板弹出「第 1 站 / 本站必须停留」
- [x] 停留收集：5 秒进度后「食物 +38，燃料 +51」（30~60 区间，BUG-012 修复生效）
- [x] 维修：HP 满时正确提示「列车 HP 已经满了」，不扣零件
- [x] 补给：药品 +5、食物 -20
- [x] 继续行驶：离站后「下一站: 冻湖站 (余 100 km)」、里程保留 80km（BUG-010 无回归）
- [x] 随机事件与站点面板同帧竞争：事件先弹（面板期间世界暂停），关闭后站点正常触发——无丢失

### 发布产物

- [x] 一键脚本产出：`dist/FrostlandExpress.apk`（70.7MB，release 签名，arm64-v8a）+ `dist/FrostlandExpress.exe`（149.4MB）
- [x] APK 签名验证：apksigner verify 通过
- [x] APK 内容：无 addons/godot_ai、无测试/工具文件
- [x] 图标已配置（aapt 检查 launcher 图标生效）；Godot boot splash 已禁用
- [x] 用户存档恢复：`game_state.json`、`train_save.json` SHA-256 与 Day 7 备份一致

## 已知边界

- 模拟器冒烟：系统镜像（android-35 google_apis x86_64）下载完整后（3.5GB，system.img 校验完整）重试 AVD（frostland_smoke）两次：`-accel off` 软件模拟 qemu 均卡在启动早期（内存 3~6MB、CPU 近 0，20 分钟无推进）；本机无 AEHD/WHPX 硬件加速（驱动静默安装卡死、无 UAC 弹窗）→ 判定本机模拟器不可行（缺虚拟化支持）。已交付真机验证清单 `docs/android_device_checklist.md`（10 项冒烟点 + 反馈模板），APK 可直接 adb install 验证。
- 生存整圈为 headless 数学模拟（无随机事件的最坏情况），真窗口只实测到第一站闭环；全圈真实体感待玩家试玩反馈
- 慢速 120 km/h 长程资源耗尽属设计内（慢速低效 + 可失败），若玩家反馈过难可再调

本轮不执行 Git commit，保留工作区差异供审阅。
