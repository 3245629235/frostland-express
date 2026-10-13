# Day 5 验收记录

项目：Frostland Express Demo  
引擎：Godot 4.7.1，GL Compatibility，1280×720  
范围：第一章「启程」剧情串联、关卡 1 教学、关卡 2 正式接入、关卡 3 劫匪战分支、基础程序音效

## 实现内容

- `scripts/story_progress.gd`
  - 独立保存 `user://story_progress.json`
  - 记录当前关卡、解锁关卡、完成关卡、分支、重试次数、第一章完成状态
  - 防止直接进入未解锁关卡
- `scripts/story_hub.gd` + `scenes/story_hub.tscn`
  - 第一章剧情目录
  - 关卡锁定/解锁显示
  - 分支和完成进度显示
- `scripts/story_intro.gd` + `scenes/story_intro.tscn`
  - 第一章开场文字剧情
  - 进入列车教学
- `scripts/travel.gd`
  - 关卡 1 真实 Travel 教学目标：移动、车内交互、启动列车
  - 教学期间冻结资源/角色消耗和随机事件，但保留真实列车物理
  - 教学完成后进入关卡 2
- `scripts/battle_data.gd`
  - 关卡 3 保守防守/主动追击两套劫匪波次
  - 散兵、持盾劫匪、匪首 Boss
- `scripts/battle.gd` + `scripts/systems/battle_system.gd`
  - 读取剧情当前关卡和分支
  - 射速限制 2 发/秒
  - 关卡 3 Boss 出场后独立 30 秒限时
  - 全员存活角色攻击力合计作为队伍火力
  - 持盾劫匪需要 3 次破盾，破盾后进入正常伤害阶段
  - 胜利进入下一关/第一章完成，失败记录重试次数
- `scripts/story_transition.gd` + `scenes/story_transition.tscn`
  - 关卡 2 完成后的文字过渡与分支选择
  - 第一章完成后的结尾页
- `scripts/audio_fx.gd`
  - 程序合成射击、命中、波次、警报、胜利、失败音效
- `scripts/title_screen.gd`
  - 标题页新增“剧情模式：第一章启程”入口
  - 原有“开始”继续作为生存模式入口
- `scripts/defeat.gd`、`scripts/victory.gd`
  - 剧情失败重试当前关卡
  - 剧情结算返回剧情目录
- `scripts/story_hub.gd`
  - 已解锁的第 3 关从剧情目录直接进入战斗，不再误回分支选择页

## 验收结果

- [x] Day 5 专项规则测试：`Day 5 规则测试通过`
- [x] Day 4 规则回归：`Day 4 规则测试通过`
- [x] Day 3 规则回归：`Day 3 规则测试通过`
- [x] 标题页 → 剧情目录真窗口通过
- [x] 剧情目录关卡锁定状态真窗口通过
- [x] 开场文字页真窗口通过
- [x] 关卡 1 Travel 教学面板真窗口通过
- [x] 真窗口完成“移动 + 锅炉交互 + 加速”后显示“教学完成，可以进入下一关”
- [x] 修复教学期间随机事件遮挡问题：重启后教学期间不再触发随机事件
- [x] 正式 `battle.tscn` 真窗口显示“关卡 2「雪狼袭击」”、2 波、敌人数量和 HUD
- [x] 第 3 关主动分支真窗口显示“关卡 3「劫匪关卡」”、第一波劫匪、敌人名称、Boss 尚未出现状态
- [x] Day 5 规则测试覆盖 Boss 出场后 30 秒超时、Boss 提前攻击、持盾劫匪三次破盾、安全/主动两条完整波次模拟
- [x] 新增剧情场景 headless 启动通过：story_hub、story_intro、story_transition、battle、title_screen、travel
- [x] `git diff --check` 通过
- [x] 用户存档恢复：`game_state.json`、`train_save.json` SHA-256 与 Day 3 备份一致

## 已知边界

- 本轮真窗口验证到第 3 关第一波和 Boss 出场前 HUD；完整 Boss 点击通关由 headless 双分支模拟覆盖，未在真窗口中自动代打整场 Boss。
- 当前程序音效为运行时合成音，不依赖外部音频文件；正式音色和音量平衡可在 Day 6 调整。
- Day 6 继续做最终数值平衡、Android 导出和完整发布验收。

本轮不执行 Git commit，保留工作区差异供审阅。
