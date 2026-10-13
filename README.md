# Frostland Express（寒霜快车）

极寒末日 · 列车生存管理 Demo。在冰原上驾驶蒸汽列车，管理食物、燃料、药品、零件与弹药，抵御雪狼与劫匪，一路驶向极光城。

- 引擎：Godot 4.7.1（GL Compatibility）
- 分辨率：1280 × 720（canvas_items 自适应）
- 目标平台：Android（主力）/ Windows

## 玩法

### 生存模式（登车）
- 编组车厢、调度 4 名队员，出发穿越 4 个里程站点：白桦林站（80km）→ 冻湖站（180km）→ 铁岭口（300km）→ 极光城（420km，折返点）
- 行驶中管理资源：食物/燃料每 2 秒结算，体温/饥饿/体力持续变化；随机事件（暴风雪、幸存者求救、神秘商人等 8 种）需要抉择
- 到站可停留收集、维修、补给、继续行驶
- 失败条件：列车损毁 / 全员倒下 / 抛锚 3 次
- 单程约 30~60 分钟（现实时间，时间压缩 ×3）

### 剧情模式（第一章「启程」）
- 关卡 1「出发」：教学
- 关卡 2「雪狼袭击」：实时战斗教学（点击敌人射击，1 发/秒）
- 关卡 3「劫匪关卡」：保守防守 / 主动追击分支，持盾劫匪需 3 发破盾，匪首 Boss 30 秒限时
- 通关解锁下一关，进度独立保存

## 安装

### Android
1. 拷贝 `dist/FrostlandExpress.apk` 到手机
2. 允许安装未知来源应用后安装
3. 包名 `com.frostland.express`，v0.1.0（arm64-v8a）

### Windows
- 直接运行 `dist/FrostlandExpress.exe`（x86_64，免安装）

## 开发

```bash
# 运行（Godot 编辑器打开项目后按 F5）
# 规则测试（headless）
Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tests/day3_logic_test.gd
# ... day4 / day5 / day6 / day7
```

### 发布导出（一键）

```bash
python tools/export_release.py          # APK + exe
python tools/export_release.py --apk    # 仅 APK
python tools/export_release.py --exe    # 仅 exe
```

流程：复制项目 → 剔除 addons/godot_ai 调试插件 → Godot headless 导出 release → 产物落到 `dist/`。

### 应用图标

```bash
python tools/generate_app_icon.py       # 重新生成 assets/icon_*.png
```

## 文档

| 文档 | 内容 |
|------|------|
| `DEMO_DESIGN.md` | 设计规格定稿（v2.0） |
| `CODE_WIKI.md` | 模块结构、导出配置、平衡数值速查 |
| `docs/day2~7_acceptance.md` | 各开发日验收记录 |
| `docs/bug_log.md` | Bug 与平衡修正日志 |

## 验收记录摘要

- Day 2：车内第一人称视差行驶、编组出发闭环
- Day 3：随机事件 E1~E8、4 站点、失败结算
- Day 4：实时战斗系统（雪狼袭击）
- Day 5：第一章剧情串联、关卡 2/3、Boss 战、程序音效
- Day 6：数值平衡（时间压缩 ×3、消耗曲线、战斗重标定）、音效分级、Android 导出
- Day 7：生存整圈模拟验证、站点闭环实测、导出一键化、应用图标、README
