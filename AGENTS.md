# AGENTS.md - GrindSurvivors-QoL

## 项目概述

**GrindSurvivors-QoL** 是一个为 UE5 游戏《无尽猎杀》（Grind Survivors）提供生活质量（Quality of Life）增强的模组集合仓库，基于 UE4SS 框架和 Lua 脚本实现。

仓库统一管理所有模组及其共享依赖，便于同步开发、安装和更新。

## 仓库结构

```
GrindSurvivors-QoL/
├── AGENTS.md               # 本文档 - 开发者参考
├── README.md               # 用户文档（英文）
├── README_zh.md            # 用户文档（中文）
├── install.cmd             # 一键安装启动脚本
├── install.ps1             # 一键安装主脚本（自动安装 UE4SS + 所有模组）
├── Mods/
│   ├── FreshPerksFirst/    # 模组：智能 perk 筛选
│   │   ├── Scripts/
│   │   │   └── main.lua
│   │   └── ...
│   ├── PickupRangeXpBoost/ # 模组：拾取范围经验增益
│   │   ├── Scripts/
│   │   │   └── main.lua
│   │   └── ...
│   └── shared/             # 共享库（所有模组共用）
│       ├── UEHelpers/      # UEHelpers 辅助库
│       ├── types/          # 游戏类型定义转储
│       ├── Types.lua       # 类型定义聚合入口
│       └── jsbProfiler/    # 性能分析器
```

## 技术栈

- **框架**: UE4SS (Unreal Engine Scripting System)
- **语言**: Lua 5.4
- **目标游戏**: Grind Survivors (UE5)
- **依赖**: UEHelpers（UE4SS 内置模块 + 自定义扩展）

---

## 模组：FreshPerksFirst

### 概述

在 Infinity 模式中，防止已拥有的 perk 在升级选择中出现，直到该分类组中的所有 perk 都被学会。当完整分类被学满后，该分类的 perk 重新进入随机池。

### 核心机制

- **挂钩点**: `LevelUpWidget:Activate` / `RerollPerks`
- **操作对象**: `widget.Perks` TArray
- **方式**: 修改 perk 列表并更新 SkillCard 视觉效果

### 关键组件

| 组件 | 用途 |
|------|------|
| `UPerkSubsystem` | Perk 子系统，管理所有 perk 数据 |
| `UPerkDataAsset` | Perk 数据资产，存储 perk 定义和分类组 |
| `ULevelUpWidget` | 升级选择界面 Widget |
| `USkillCard` | 单个 perk 卡片 Widget |
| `FGameplayTag` | UE GameplayTag，标记 perk 和分类 |

### 数据流

```
OnLevelUp → LevelUpWidget:Activate()
                  ↓
           FilterPerks() → 遍历 widget.Perks
                  ↓
           检查 perk 是否已拥有 → 检查分类是否已学满
                  ↓
           移除已拥有且分类未满的 perk → 更新 UI
```

---

## 模组：PickupRangeXpBoost

### 概述

根据玩家角色的 `Stat.PickupRange` 属性值相对于基础值的增幅，按比例增加获取的经验值。

### 关键组件

| 组件 | 类型 | 用途 |
|------|------|------|
| `UStatSystem` | `UGameInstanceSubsystem` | 游戏属性系统，管理所有 Stat |
| `ULevelComponent` | `UActorComponent` | 角色等级组件，存储经验值 |
| `FGameplayTag` | 结构体 | UE GameplayTag 系统的标签 |
| `UGameplayStat` | `UObject` | 单个属性的数据容器 |
| `UUserWidget` | UMG Widget | XP 增益显示的根容器 |
| `UTextBlock` | UMG Widget | 显示增益百分比和额外经验值的文本 |

### 数据流

```
OnPlayerGainXP_Event → accumulatedBaseXP += xp
                              ↓
                       LoopAsync(500ms) → GiveBonusXP()
                              ↓
                       计算增幅 → LevelComponent.AccumulatedXpOnCurrentLevel += bonusXP
                              ↑
                       currentPickupRange ← 两个来源：
                         1. HandlePickupRangeChanged_ 事件（实时）
                         2. UpdatePickupRange() → StatSystem:GetStatValueByTag()（初始化时）
```

### 运行机制

- **XP 累积**: `OnPlayerGainXP_Event` 触发时仅累积到 `accumulatedBaseXP`，不立即计算
- **批量处理**: `LoopAsync` 每 500ms 执行一次 `GiveBonusXP()`，批量处理累积的 XP
- **关卡重置**: `OnGameLevelStarted` 时重置 `levelComponent`（防止残留失效引用）并重新初始化
- **双通道同步**: PickupRange 值通过事件实时更新 + 初始化时主动查询，确保不遗漏
- **HUD 显示**: `OnGameLevelStarted` 延迟 2s 后通过 `StaticConstructObject` 创建 UMG widget 链，锚定在屏幕顶部居中偏下（Y=55），每次 `GiveBonusXP` 或 `HandlePickupRangeChanged_` 后实时更新文本和颜色

### 修改指南

**添加新属性增益**:
1. 修改 `FindPickupRangeTag()` 中的标签名称
2. 更新 `BASE_PICKUP_RANGE` 常量
3. 调整 `GiveBonusXP()` 中的增幅公式

**当前增幅公式**:
```lua
local multiplier = (currentPickupRange - BASE_PICKUP_RANGE) / BASE_PICKUP_RANGE
local bonusXP = math.floor(baseXP * multiplier + 0.5)
```

### 控制台命令

| 命令 | 功能 |
|------|------|
| `xpboost_status` | 查看当前状态 |
| `xpboost_debug` | 开关调试日志 |
| `xpboost_ratio <值>` | 设置经验转换比率 |
| `xpboost_set <值>` | 手动设置 PickupRange |
| `xpboost_test <数量>` | 添加测试经验值 |
| `xpboost_ui` | 开关 HUD 增益显示 |

---

## UE4SS 事件系统

### RegisterCustomEvent

注册蓝图自定义事件的回调：

```lua
RegisterCustomEvent("事件名", function(ContextParam, 参数1, 参数2, ...)
    local actualValue = 参数1:get()
end)
```

### 常用事件

| 事件 | 来源 | 参数 |
|------|------|------|
| `OnGameLevelStarted` | `AGSGameMode` | 无 |
| `HandlePickupRangeChanged_` | `BP_PlayerCharacterEffects_C` | StatTag, PrevValue, NewValue |
| `OnPlayerGainXP_Event` | `BP_PlayerCharacterEffects_C` | XPAmount |

---

## 共享库

### 游戏类型定义

我们没有游戏源码，需要根据转储的游戏类型定义进行功能推定。

- 类型定义目录: `Mods/shared/types/`
- GrindSurvivors 类型定义: `Mods/shared/types/GrindSurvivors.lua`
- UEHelpers 入口: `Mods/shared/UEHelpers/UEHelpers.lua`

### UEHelpers

`Mods/shared/UEHelpers/` 是 UE4SS 内置 `UEHelpers` 模块的自定义扩展/副本，提供更便捷的 UE 对象查找和操作方法。

### 核验式调用原则

我们没有游戏源码，不能笃定游戏的实际功能与类型定义完全一致。所有对游戏特定类型的调用都应做好日志，注明实际功能有待验证，并提醒开发者验证。

---

## 代码规范（跨模组通用）

### 1. `pcall` 使用原则

- **严禁滥用**: 禁止使用 `pcall` 处理可通过 `if/else` 或 `nil` 检查避免的逻辑错误。
- **最小化作用域**: 仅包裹可能失败的特定代码行（如 `json.decode`、文件 I/O、网络请求）。
- **强制错误处理**: 严禁"静默失败"。所有 `pcall` 必须配合错误分支进行日志记录、资源回收或状态回滚。
- **调试优先**: 在需要获取调用栈的场景下，优先使用 `xpcall` 并传入 `debug.traceback`。
- **标准返回模式**: 统一遵循 `local ok, val_or_err = pcall(...)` 命名规范，并立即检查 `ok` 状态。
- **不要**用 `pcall` 包装普通的 UE 对象属性访问和方法调用——用 `nil` 检查 + `IsValid()` 即可。
- **边界防护**: `LoopAsync`、`ExecuteWithDelay`、`ExecuteInGameThread` 等回调入口必须被 `pcall` 包裹，严禁让业务逻辑的错误杀死循环或破坏线程状态。
- `pcall` 捕获的错误**必须记录日志**，禁止静默吞掉：`local ok, err = pcall(fn); if not ok then Log(err) end`
- 判断标准：「如果这里抛异常，是否会导致不可恢复的后果（如定时器停止）？」——是则 `pcall`，否则让错误自然暴露。

### 2. 空值检查

- 在使用对象前调用 `IsValid()` 验证
- UE 对象或结构体在关卡切换后可能被 GC，必须重置

### 3. 类型检查

- 使用 `type(value) == "number"` 确认返回类型

### 4. 日志前缀

- `FreshPerksFirst`: `[FreshPerksFirst]`
- `PickupRangeXpBoost`: `[PickupRangeXpBoost]`

### 5. 关卡切换状态重置

- 每个持有 UE 对象、结构体或从中派生值的变量，**必须**在关卡切换时重置为 `nil` 或初始值。
- 新增的缓存引用也必须添加到重置列表中。

### 6. 调试日志

```lua
Log("消息")        -- 始终输出
DebugLog("消息")   -- 仅在 DEBUG_MODE=true 时输出
```

---

## 参考资源

- UE4SS 文档: https://docs.ue4ss.com/
- UE5 GameplayTag 文档: https://docs.unrealengine.com/5.0/en-US/gameplay-tags-in-unreal-engine/
- 游戏类型定义: `Mods/shared/types/`
