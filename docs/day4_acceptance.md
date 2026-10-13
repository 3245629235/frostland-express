# Day 4 验收记录

项目：Frostland Express Demo  
引擎：Godot 4.7.1，GL Compatibility，1280×720  
范围：剧情模式关卡 2「雪狼袭击」实时战斗教学

## 实现内容

- `scripts/battle_data.gd`：4 类敌人配置、2 波教学波次、目录校验。
- `scripts/systems/battle_system.gd`：战斗状态、敌人生成、点击射击、弹药消耗、无弹药近战倍率、敌人推进、角色/列车受伤、胜负判定。
- `scripts/battle.gd` + `scenes/battle.tscn`：程序绘制的车厢战斗场景、敌人形状与血条、波次 HUD、弹药/列车/队员状态、退出和结算。
- `scripts/title_screen.gd`：标题页新增“剧情战斗：雪狼袭击”入口，方便 Day 4 独立验收。
- `tests/day4_logic_test.gd`：战斗规则 headless 测试。

## 验收结果

- [x] BattleData 敌人/波次目录校验通过。
- [x] 点击敌人射击，弹药 -1，攻击力伤害和击倒计数通过。
- [x] 敌人推进到角色区域会扣角色 HP。
- [x] 无可行动角色/列车 HP 归零可进入失败结算规则。
- [x] 战斗胜利奖励：食物 +8、小口径弹药 +10、士气 +5。
- [x] `tests/day4_logic_test.gd`：`Day 4 规则测试通过`。
- [x] `tests/day3_logic_test.gd`：`Day 3 规则测试通过`，证明未破坏现有生存规则。
- [x] `battle.tscn` 使用 Godot 4.7.1 headless 启动通过，无 Parser Error/运行时错误。
- [x] `git diff --check` 通过。

## 未完成/边界

- Godot AI MCP 当前没有连接编辑器会话，因此本轮未完成 MCP 真窗口点击验收；已完成同版本 Godot headless 规则测试、项目扫描和场景启动测试。
- 当前标题入口用于 Day 4 开发验收；第一章完整剧情进度存档、关卡 3 劫匪战和音效属于 Day 5/Day 6。
- 生存 Travel 保持无战斗，符合 `DEMO_DESIGN.md` 对双模式的约束。
