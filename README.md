
# Dungeon Deck — ECE241 起始项目

## 目标一

**KEY/SW → FSM + 坐标 → LEDR**

第一个阶段的目标是通过 DE1-SoC 开发板上的按键（KEY）和开关（SW），控制游戏有限状态机（FSM）与角色坐标，并通过 LEDR 显示结果。

这个阶段不需要 VGA 显示器，也不需要连接实体 PS/2 键盘。

## DE1-SoC 按键控制

- `KEY[0]`：低电平有效的复位按键；开发板上电后短暂按住进行复位。
- `SW[1:0]`：移动方向：`00` 上、`01` 下、`10` 左、`11` 右。
- `KEY[1]`：每按一次，角色移动一个格子。脉冲模块会对按键进行约 10 ms 的消抖处理。
- `KEY[2]`：与当前格子上的门或敌人进行交互。
- `KEY[3]`：从建筑、地牢、胜利或失败场景返回。
- `SW[9]`：选择 LED 显示的坐标（`0 = x`，`1 = y`）。
- `LEDR[7:3]`：以二进制形式显示所选坐标。
- `LEDR[2:0]`：显示当前场景 ID：
  - `0`：Town（城镇）
  - `1`：House 1（房屋 1）
  - `2`：House 2（房屋 2）
  - `3`：Dungeon（地牢）
  - `4`：Battle（战斗）
  - `5`：Victory（胜利）
  - `6`：Defeat（失败）

### 测试示例 1：进入地牢

初始角色坐标为 `(x, y) = (10, 7)`。

1. 设置 `SW[1:0] = 01`，选择向下移动。
2. 分别按下 `KEY[1]` 五次，使角色移动到 `(10, 12)`。
3. 按下 `KEY[2]`，与当前位置的对象进行交互。
4. 场景从 `0`（Town）切换到 `3`（Dungeon）。
5. 按下 `KEY[3]`，返回原来的场景。

### 测试示例 2：进入战斗

在地牢中，角色从 `(10, 7)` 开始。

1. 向上移动两次，到达 `(10, 5)`。
2. 按下 `KEY[2]`，与当前位置的敌人交互。
3. 进入 `4`（Battle）战斗场景。

**注意：** 此阶段尚未连接实际的战斗逻辑，此阶段只测试场景切换。

## 项目模块

- `rtl/game_top.v`：顶层模块，负责连接开发板上的输入输出接口，实现初始 LED 调试功能。
- `rtl/button_pulse.v`：对 DE1-SoC 的低电平有效按键进行同步和消抖处理，生成按键脉冲。
- `rtl/game_fsm.v`：游戏场景切换的有限状态机（FSM）。
- `rtl/exploration.v`：管理角色在地图中的坐标，并检查地图边界（暂时不包含墙壁碰撞检测）。
- `rtl/input_decoder.v`：将 PS/2 Set-2 扫描码字节转换为持续一个时钟周期的 WASD、Enter 和 Escape 输入事件。
- `rtl/combat.v`：战斗系统占位模块，目前只有 TODO，尚未实现具体功能。
- `rtl/print.v`：图形渲染占位模块，目前只有 TODO，尚未实现具体功能。
- `rtl/player_fsm.v`: 保存角色状态

## 仿真（Simulation）

在 ModelSim 中创建仿真项目，或者直接编译对应的 RTL 模块和测试文件：

- `sim/tb_game_fsm.v`：测试游戏场景状态机。
- `sim/tb_exploration.v`：测试角色移动与坐标管理。
- `sim/tb_input_decoder.v`：测试 PS/2 输入解码器。

如果电脑已经安装 **Icarus Verilog**，可以在终端中执行以下命令：

### FSM 仿真

```bash
iverilog -g2005-sv -s tb_game_fsm -o /tmp/tb_fsm rtl/game_fsm.v sim/tb_game_fsm.v && vvp /tmp/tb_fsm
```

### 角色移动仿真

```bash
iverilog -g2005-sv -s tb_exploration -o /tmp/tb_explore rtl/exploration.v sim/tb_exploration.v && vvp /tmp/tb_explore
```

### PS/2 输入解码器仿真

```bash
iverilog -g2005-sv -s tb_input_decoder -o /tmp/tb_ps2 rtl/input_decoder.v sim/tb_input_decoder.v && vvp /tmp/tb_ps2
```

## 后续开发计划

1. **与 VGA 开发成员统一设计**
   - 确定游戏场景 ID。
   - 确定地图的格子布局（Tile Map）。
   - 确定角色坐标系统及坐标方向约定。 

2. **集成 VGA 图形显示**
   - 添加 VGA 模块。
   - 在屏幕上绘制代表玩家的矩形。
   - 假设 VGA 逻辑分辨率为 `160 × 120`，则玩家矩形的位置为：
     - `pixel_x = player_x * 8`
     - `pixel_y = player_y * 8`

3. **完成 FSM 和角色移动的开发板调试**
   - 将 FSM 和角色移动调试顶层模块下载到 DE1-SoC 开发板。
   - 通过按键和开关控制角色移动与场景切换。
   - 验证 LEDR 显示的坐标和场景 ID 是否正确。

4. **接入 PS/2 键盘控制**
   - 获取课程提供的 DE1-SoC `PS2_Controller` 核心模块。
   - 将 `received_data` 和 `received_data_en` 连接到 `input_decoder`。
   - 使用解码后的键盘输入事件替换 `game_top` 中原本基于 KEY/SW 的调试输入。

5. **逐步完善游戏功能**
   - 添加地图墙壁及碰撞检测。
   - 实现卡牌系统。
   - 实现能量系统。
   - 实现战斗逻辑。
   - 添加角色与场景精灵图（Sprite）。
   - 丰富游戏地图、画面和场景内容。

## 注意事项

本项目目前只是一个用于**学习和调试的基础框架**，并不是完整的游戏。

当前设计有意将图形渲染与游戏逻辑分开，并优先使用开发板上的实体按键和开关进行输入测试。

在将项目集成到 DE1-SoC 开发板之前，需要确认：

- 课程提供的引脚分配文件（Pin Assignment）是否正确。
- VGA 核心模块的参数设置是否符合课程要求。
- 各模块之间的接口与信号定义是否一致。

后续将在此基础上逐步实现完整的 Dungeon Deck 游戏。
