[English](README.md) | 中文

# GrindSurvivors-QoL

一个为 UE5 游戏《无尽猎杀》（Grind Survivors）提供生活质量（Quality of Life）增强的模组合集，基于 UE4SS 模组框架构建。

本仓库统一管理所有模组及其共享依赖，简化安装和更新流程。

<video src="https://github.com/user-attachments/assets/2bd0c45f-4787-4523-850a-1a77c10a4348" controls="controls" width="100%" autoplay="autoplay" muted="muted" loop="loop"></video>

## 模组列表

| 模组 | 说明 |
|------|------|
| **FreshPerksFirst** | 在无尽模式中，升级时优先出现未学过的技能，只有当所有技能都被学过了，才会出现已学过的技能。 |
| **PickupRangeXpBoost** | 根据当前拾取范围相对基础值的增幅，按可配置转换比率增加获取的经验值，并在屏幕上实时显示增益百分比和额外经验值。 |

## 安装

### 自动安装（推荐）

1. 下载[最新源码](https://github.com/abevol/GrindSurvivors-QoL/archive/refs/heads/master.zip)并解压。
2. 双击根目录中的 `install.cmd`。
3. 按照提示选择你的游戏目录（通常为 `Grind Survivors/GrindSurvivors/Binaries/Win64/`）。
4. 脚本将自动下载并安装 **UE4SS 模组框架**并配置好所有模组。

### 手动安装

1. 确保已安装 [UE4SS](https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest)（**experimental-latest** 版本）。
2. 将整个 `Mods/` 文件夹复制到 `Grind Survivors/GrindSurvivors/Binaries/Win64/ue4ss/Mods/` 目录下。最终目录结构应为：
   ```
   ue4ss/Mods/
   ├── FreshPerksFirst/    # → 来自 Mods/FreshPerksFirst/
   ├── PickupRangeXpBoost/ # → 来自 Mods/PickupRangeXpBoost/
   └── shared/             # → 来自 Mods/shared/
   ```
3. 在 `Grind Survivors/GrindSurvivors/Binaries/Win64/ue4ss/Mods/mods.txt` 文件中添加以下内容以注册每个模组：
   ```text
   FreshPerksFirst : 1
   PickupRangeXpBoost : 1
   ```
4. 启动游戏。

## 验证安装

1. 启动游戏并进入任一关卡。
2. 对于 **PickupRangeXpBoost**：观察屏幕顶部，经验条中间位置若出现增益标签（如 "EXP + 70% (+3)"），则说明模组已生效。
3. 对于 **FreshPerksFirst**：在无尽模式中升级，验证是否优先展示未学过的技能。

---

## FreshPerksFirst

**无限模式智能技能筛选。**

- 对 `LevelUpWidget:Activate` / `RerollPerks` 进行后置挂钩
- 修改 `widget.Perks` TArray 并更新 SkillCard 视觉效果
- 升级时优先展示未学过的技能，直到所有技能都被学完
- 替换技能时有概率出现协同技能，这本来是个 BUG，但已予保留，现为模组特性

### 控制台命令

| 命令 | 说明 |
|------|------|
| `fpf_status` | 查看当前模组状态 |
| `fpf_debug` | 开启/关闭调试日志 |

---

## PickupRangeXpBoost

**拾取范围 → 经验增益转换。**

- 根据当前拾取范围相对基础值（360）的增幅，按可配置转换比率换算为额外经验值
- 公式：`额外经验 = 基础经验 × (当前 Stat.PickupRange - 360) / 360 × XP_CONVERSION_RATE`
- 默认转换比率：`XP_CONVERSION_RATE = 1.0`
- 每 500ms 批量结算一次额外经验
- 屏幕顶部实时显示当前增益百分比和额外经验值，颜色随增益等级变化

### 增幅示例（基于默认 `XP_CONVERSION_RATE = 1.0`）

| PickupRange | 经验增幅 | 获取 10 XP 时的额外经验 |
|-------------|----------|------------------------|
| 360 | 0% | 0 |
| 540 | 50% | 5 |
| 720 | 100% | 10 |
| 1080 | 200% | 20 |

### 控制台命令

| 命令 | 说明 |
|------|------|
| `xpboost_status` | 查看当前状态（PickupRange、拾取范围增幅、转换比率、经验增幅、待处理经验） |
| `xpboost_debug` | 开启/关闭调试日志 |
| `xpboost_ratio <值>` | 设置经验转换比率（`0` 关闭额外经验，`1` 保持原始行为） |
| `xpboost_set <值>` | 手动设置 PickupRange（测试用） |
| `xpboost_test <数量>` | 手动添加经验值到待处理队列（默认 10） |
| `xpboost_ui` | 开启/关闭屏幕增益显示 |

### 配置

修改 `Mods/PickupRangeXpBoost/Scripts/main.lua` 顶部的常量：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `BASE_PICKUP_RANGE` | 360 | PickupRange 基础值，低于此值不产生加成 |
| `XP_CONVERSION_RATE` | 1.0 | 将拾取范围增幅转换为经验增幅的比率，也可在游戏中通过 `xpboost_ratio` 修改 |
| `DEBUG_MODE` | false | 调试日志开关 |

---

## 项目结构

```
GrindSurvivors-QoL/
├── AGENTS.md                   # 开发者参考文档
├── README.md                   # 用户文档（英文）
├── README_zh.md                # 本文档
├── install.cmd                 # 一键安装启动脚本
├── install.ps1                 # 一键安装主脚本
└── Mods/
    ├── FreshPerksFirst/        # 智能 Perk 筛选模组
    │   └── Scripts/main.lua
    ├── PickupRangeXpBoost/     # 经验增益模组
    │   └── Scripts/main.lua
    └── shared/                 # 共享库
        ├── UEHelpers/
        ├── types/
        └── ...
```

## 依赖

- **UE4SS** (experimental-latest)：[下载](https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest)
- **UEHelpers**：UE4SS 内置模块（包含在 `Mods/shared/` 中）
