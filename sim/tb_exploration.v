`timescale 1ns/1ps

module tb_exploration;
    localparam [2:0] TOWN = 0, HOUSE1 = 1, HOUSE2 = 2,
                     DUNGEON = 3, BATTLE = 4, START = 7;
    localparam [1:0] UP = 2'b00, DOWN = 2'b01,
                     LEFT = 2'b10, RIGHT = 2'b11;

    reg clock = 0, resetn = 0, move_pulse = 0;
    reg [2:0] scene = START;
    reg [1:0] move_dir = UP;
    wire [4:0] player_x, player_y;

    exploration dut (
        .clock(clock), .resetn(resetn), .scene(scene),
        .move_pulse(move_pulse), .move_dir(move_dir),
        .player_x(player_x), .player_y(player_y)
    );

    always #10 clock = ~clock;  // 50 MHz

    // 在下降沿设置输入，在下一个上升沿后检查坐标。
    task step(input [2:0] new_scene, input pulse, input [1:0] dir);
        begin
            @(negedge clock);
            scene = new_scene;
            move_pulse = pulse;
            move_dir = dir;
            @(posedge clock);
            #1;
            move_pulse = 0;
        end
    endtask

    task check_xy(input [4:0] x, input [4:0] y);
        begin
            if (player_x !== x || player_y !== y)
                $fatal(1, "FAIL at %0t: scene=%0d expected=(%0d,%0d) got=(%0d,%0d)",
                       $time, scene, x, y, player_x, player_y);
        end
    endtask

    initial begin
        // 复位到 (11,7)，在开始界面按移动键时坐标保持不变。
        @(posedge clock);
        #1;
        check_xy(11, 7);
        resetn = 1;
        step(START, 1, RIGHT);    check_xy(11, 7);

        // Town 中每个移动脉冲走一格，pulse=0 时停在原地。
        step(TOWN, 0, UP);        check_xy(11, 7);
        step(TOWN, 1, RIGHT);     check_xy(12, 7);
        step(TOWN, 0, RIGHT);     check_xy(12, 7);
        step(TOWN, 1, UP);        check_xy(12, 6);

        // 进入房屋与移动发生在同一拍时，优先切换场景。
        // 离开任一房屋后，都应回到之前的 Town 坐标 (12,6)。
        step(HOUSE1, 1, RIGHT);   check_xy(11, 7);
        step(HOUSE1, 1, DOWN);    check_xy(11, 8);
        step(TOWN, 0, UP);        check_xy(12, 6);
        step(HOUSE2, 0, UP);      check_xy(11, 7);
        step(HOUSE2, 1, LEFT);    check_xy(10, 7);
        step(TOWN, 0, UP);        check_xy(12, 6);

        // 战斗时坐标保持不变，返回 Dungeon 后恢复战斗前的位置。
        step(DUNGEON, 0, UP);     check_xy(11, 7);
        step(DUNGEON, 1, LEFT);   check_xy(10, 7);
        step(DUNGEON, 1, UP);     check_xy(10, 6);
        step(BATTLE, 0, UP);      check_xy(10, 6);
        step(BATTLE, 1, DOWN);    check_xy(10, 6);
        step(DUNGEON, 0, UP);     check_xy(10, 6);
        step(TOWN, 0, UP);        check_xy(12, 6);

        // 到达每条边界后再向外走一步，坐标应保持不变。
        repeat (12) step(TOWN, 1, LEFT);
        check_xy(0, 6);
        step(TOWN, 1, LEFT);      check_xy(0, 6);

        repeat (6) step(TOWN, 1, UP);
        check_xy(0, 0);
        step(TOWN, 1, UP);        check_xy(0, 0);

        repeat (19) step(TOWN, 1, RIGHT);
        check_xy(19, 0);
        step(TOWN, 1, RIGHT);     check_xy(19, 0);

        repeat (14) step(TOWN, 1, DOWN);
        check_xy(19, 14);
        step(TOWN, 1, DOWN);      check_xy(19, 14);

        // 再按复位键，在下一个时钟上升沿之前就应回到 (11,7)。
        @(negedge clock);
        resetn = 0;
        #1;
        check_xy(11, 7);

        $display("PASS: all exploration tests passed");
        $finish;
    end
endmodule