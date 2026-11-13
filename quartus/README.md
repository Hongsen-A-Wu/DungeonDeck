\# Quartus 项目创建指南

## 1. 创建 Quartus 项目

使用 **Quartus Prime Lite 18.1** 创建项目。

1. 打开 `File > New Project Wizard`。
2. 设置项目参数：
   - **Project Directory:** `DungeonDeck/quartus`
   - **Project Name:** `dungeon_deck`
   - **Top-Level Entity:** `game_top`

## 2. 添加 Verilog 文件

1. 添加 `../rtl/` 文件夹中所有已经实现的 `.v` 文件。
2. 尚未实现的模块可以暂时不添加：
   - `combat.v`
   - `renderer.v`
3. 确保所有模块之间的连接正确。

## 3. 选择 FPGA 芯片

1. 选择 **DE1-SoC Cyclone V FPGA**。
2. 确保芯片型号与课程实验板或提供的模板一致。

## 4. 配置引脚（Pin Assignments）

1. 导入课程提供的 `DE1_SoC.qsf` 引脚配置。
2. 确认顶层模块 `game_top` 的端口名称与配置一致：
   - `CLOCK_50`
   - `KEY`
   - `SW`
   - `LEDR`

**注意：** 不要使用其他 FPGA 开发板的引脚配置。

## 5. 编译与下载

1. 点击 `Processing > Start Compilation`。
2. 检查并修复编译错误。
3. 使用 USB 连接 DE1-SoC 开发板。
4. 打开 `Tools > Programmer`。
5. 选择编译生成的 `.sof` 文件。
6. 点击 `Start` 将程序下载至 FPGA。

## 6. 当前开发阶段

### LED-only Milestone

当前版本仅用于验证 LED 控制逻辑。

**当前目标：**
- 测试输入模块。
- 验证状态机（FSM）的运行。
- 通过 LED 检查控制逻辑是否正确。

**后续开发：**
- 集成 VGA 显示模块。
- 集成 PS/2 键盘控制器。
- 在控制逻辑通过仿真后，实现完整的 RPG 游戏功能。

> **Note:** VGA 和 PS/2 模块将在控制逻辑通过 ModelSim 仿真后添加。