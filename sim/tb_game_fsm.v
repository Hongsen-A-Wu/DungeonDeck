// Checked by Hongsen 2026-11-17

`timescale 1ns/1ps

module tb_game_fsm;
    reg clk=0, resetn=0, interact_pulse=0, back_pulse=0;
    reg at_house1=0, at_house2=0, at_dungeon=0, at_enemy=0;
    reg at_house1_exit=0, at_house2_exit=0;
    reg battle_win=0, battle_lose=0;
    wire [2:0] scene;

    localparam [2:0] TOWN    = 3'd0;
    localparam [2:0] HOUSE1  = 3'd1;
    localparam [2:0] HOUSE2  = 3'd2;
    localparam [2:0] DUNGEON = 3'd3;
    localparam [2:0] BATTLE  = 3'd4;
    localparam [2:0] VICTORY = 3'd5;
    localparam [2:0] DEFEAT  = 3'd6;
    localparam [2:0] START   = 3'd7;

    always #5 clk=~clk;

    game_fsm dut(
        .clock(clk),
        .resetn(resetn),
        .interact_pulse(interact_pulse),
        .back_pulse(back_pulse),
        .at_house1(at_house1),
        .at_house2(at_house2),
        .at_house1_exit(at_house1_exit),
        .at_house2_exit(at_house2_exit),
        .at_dungeon(at_dungeon),
        .at_enemy(at_enemy),
        .battle_win(battle_win),
        .battle_lose(battle_lose),
        .scene(scene)
    );

    task tick;
        begin @(posedge clk); #1; end
    endtask

    task check;
        input [2:0] expected;
        begin
            if (scene !== expected) begin
                $display("FAIL: scene=%d expected=%d at %0t",
                         scene, expected, $time);
                $finish;
            end
        end
    endtask

    task interact;
        begin
            @(negedge clk); interact_pulse=1;
            tick;
            @(negedge clk); interact_pulse=0;
        end
    endtask

    task back;
        begin
            @(negedge clk); back_pulse=1;
            tick;
            @(negedge clk); back_pulse=0;
        end
    endtask

    initial begin
        // Test reset -> START
        tick; resetn=1; tick;
        check(START);

        // Test START -> TOWN
        interact;
        check(TOWN);

        // Test TOWN -> HOUSE1
        at_house1=1;
        interact;
        at_house1=0;
        check(HOUSE1);

        // Test HOUSE1 cannot exit without exit position
        back;
        check(HOUSE1);

        // Test HOUSE1 -> TOWN
        at_house1_exit=1;
        back;
        at_house1_exit=0;
        check(TOWN);

        // Test TOWN -> HOUSE2
        at_house2=1;
        interact;
        at_house2=0;
        check(HOUSE2);

        // Test HOUSE2 cannot exit without exit position
        back;
        check(HOUSE2);

        // Test HOUSE2 -> TOWN
        at_house2_exit=1;
        back;
        at_house2_exit=0;
        check(TOWN);

        // Test TOWN -> DUNGEON
        at_dungeon=1;
        interact;
        at_dungeon=0;
        check(DUNGEON);

        // Test DUNGEON remains without interaction
        at_enemy=1;
        tick;
        check(DUNGEON);

        // Test DUNGEON -> BATTLE
        interact;
        at_enemy=0;
        check(BATTLE);

        // Test BATTLE -> VICTORY
        @(negedge clk); battle_win=1;
        tick;
        battle_win=0;
        check(VICTORY);

        // Test reset -> START
        @(negedge clk); resetn=0;
        tick;
        check(START);
        @(negedge clk); resetn=1;
        tick;
        check(START);

        // Test START -> TOWN -> DUNGEON -> BATTLE
        interact;
        check(TOWN);

        at_dungeon=1;
        interact;
        at_dungeon=0;
        check(DUNGEON);

        at_enemy=1;
        interact;
        at_enemy=0;
        check(BATTLE);

        // Test BATTLE -> DEFEAT
        @(negedge clk); battle_lose=1;
        tick;
        battle_lose=0;
        check(DEFEAT);

        $display("PASS tb_game_fsm");
        $finish;
    end
endmodule
