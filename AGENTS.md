# AGENTS.md - GrindSurvivors-QoL

## 项目概述

UE5 游戏《无尽猎杀》(Grind Survivors) 的 QoL 模组集合，基于 **UE4SS + Lua 5.4** 实现。统一管理模组及共享依赖。

## 仓库结构

```
GrindSurvivors-QoL/
├── AGENTS.md               # 本文档
├── README.md / README_zh.md
├── install.cmd / install.ps1        # 一键安装脚本
└── Mods/
    ├── FreshPerksFirst/             # 模组：智能 perk 筛选
    │   └── Scripts/main.lua
    ├── PickupRangeXpBoost/          # 模组：拾取范围经验增益
    │   └── Scripts/main.lua
    └── shared/                      # 共享库
        ├── UEHelpers/               # UE4SS UEHelpers 扩展
        ├── types/                   # 游戏类型定义转储
        └── Types.lua                # 类型聚合入口
```

---

## 模组：FreshPerksFirst

Infinity 模式中，防止已拥有的 perk 出现在升级选择中，直到该分类组全部学满。学满后该分类重新进入随机池。

| 组件 | 用途 |
|------|------|
| `UPerkSubsystem` | Perk 子系统，管理所有 perk 数据 |
| `UPerkDataAsset` | Perk 数据资产，存储定义和分类组 |
| `ULevelUpWidget` | 升级选择界面 |
| `USkillCard` | 单个 perk 卡片 |
| `FGameplayTag` | 标记 perk 和分类 |

**挂钩点**: `LevelUpWidget:Activate` / `RerollPerks`
**操作**: 修改 `widget.Perks` TArray → 原生 `DisplayPerks()` 重建卡片

**数据流**: `OnLevelUp → FilterPerks() → 遍历 Perks → 检查已拥有/分类已满 → 移除/保留 → DisplayPerks() 刷新 UI`

| 命令 | 功能 |
|------|------|
| `fpf_status` | 查看状态 |
| `fpf_debug` | 开关调试日志 |

---

## 模组：PickupRangeXpBoost

根据 `Stat.PickupRange` 相对于基础值的增幅，按比例转化为额外经验值。

**公式**: `bonusXP = floor(baseXP × (current - BASE) / BASE × RATIO)`

| 组件 | 用途 |
|------|------|
| `UStatSystem` | 属性系统，管理所有 Stat |
| `ULevelComponent` | 等级组件，存储经验值 |
| `UGameplayStat` | 单个属性数据容器 |

**数据流**:
```
OnPlayerGainXP → accumulatedBaseXP += xp
LoopAsync(500ms) → GiveBonusXP()
  → 计算增幅 → LevelComponent.AccumulatedXpOnCurrentLevel += bonusXP
  → 更新 HUD（顶部居中，Y=55）
```

**双通道 PickupRange 同步**: `HandlePickupRangeChanged_` 事件实时更新 + 初始化时 `StatSystem:GetStatValueByTag()` 主动查询

**关卡重置**: `OnGameLevelStarted` 时重置 `levelComponent`，延迟 2s 创建 HUD Widget 链

| 命令 | 功能 |
|------|------|
| `xpboost_status` | 查看状态 |
| `xpboost_debug` | 开关调试日志 |
| `xpboost_ratio <值>` | 设置经验转换比率 |
| `xpboost_set <值>` | 手动设置 PickupRange |
| `xpboost_test <数量>` | 添加测试经验值 |
| `xpboost_ui` | 开关 HUD 显示 |

---

## UE4SS 事件系统

```lua
RegisterCustomEvent("事件名", function(ContextParam, 参数1, ...)
    local val = 参数1:get()
end)
```

| 事件 | 来源 | 参数 |
|------|------|------|
| `OnGameLevelStarted` | `AGSGameMode` | 无 |
| `HandlePickupRangeChanged_` | `BP_PlayerCharacterEffects_C` | StatTag, PrevValue, NewValue |
| `OnPlayerGainXP_Event` | `BP_PlayerCharacterEffects_C` | XPAmount |

---

## 共享库

- 类型定义: `Mods/shared/types/GrindSurvivors.lua`（UE 类型转储，无源码）
- UEHelpers: `Mods/shared/UEHelpers/UEHelpers.lua`（UE4SS 内置模块的自定义扩展）
- **核验原则**: 无游戏源码，所有对游戏特定类型的调用需加日志标注"待验证"

---

## Lua 编码规约 (Expert Mode)

遵循 **LuaLS (Lua Language Server)** 标准：

### 1. 显式声明
- 文件头部定义 `---@class`，严禁匿名导出
- 已有惯例参考: `Mods/shared/types/GrindSurvivors.lua`

### 2. 拒绝 Generic Table
- 严禁裸 `table` 标注，必须使用 `Type[]`、`table<K, V>` 或内联 `---@field` 定义

### 3. 完整契约
- 所有导出函数标注 `---@param`（带描述）和 `---@return`
- 可选参数加 `?` 后缀

### 4. 字面量枚举
- 用 `---@alias` 或内联 `|` 定义状态/类型，禁魔法数字

### 5. 调度边界
- `pcall` **仅限调度边界**：`LoopAsync`、`ExecuteWithDelay`、`ExecuteInGameThread`、回调入口
- **业务逻辑内禁用**：普通 UE 属性/方法调用用 `IsValid()` + nil 检查即可
- 捕获的错误必须日志记录，禁止静默吞掉

---

## 跨模组规范

| 规则 | 说明 |
|------|------|
| **空值检查** | UE 对象使用前 `IsValid()`，关卡切换后变量必须重置为 `nil` |
| **日志前缀** | `[FreshPerksFirst]` / `[PickupRangeXpBoost]` |
| **调试日志** | `Log(...)` 始终输出；`DebugLog(...)` 仅 `DEBUG_MODE=true` 时 |
| **类型检查** | 确认返回类型：`type(v) == "number"` |

---

## 参考资源

- [UE4SS 文档](https://docs.ue4ss.com/)
- [UE5 GameplayTag 文档](https://docs.unrealengine.com/5.0/en-US/gameplay-tags-in-unreal-engine/)
- 游戏类型定义: `Mods/shared/types/`
