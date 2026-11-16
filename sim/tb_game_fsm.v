// Checked by Hongsen on 2026-11-16

`timescale 1ns/1ps
module tb_game_fsm;
    reg clk=0, resetn=0, interact_pulse=0, back_pulse=0;
    reg at_house1=0, at_house2=0, at_dungeon=0, at_enemy=0;
    reg battle_win=0, battle_lose=0;
    wire [2:0] scene;

    always #5 clk=~clk;

    game_fsm dut(clk, resetn, interact_pulse, back_pulse,
                 at_house1, at_house2, at_dungeon, at_enemy,
                 battle_win, battle_lose, scene);

    task tick;
        begin @(posedge clk); #1; end
    endtask

    task check;
        input [2:0] expected;
        begin
            if (scene !== expected) begin
                $display("FAIL scene=%d expected=%d at %0t", scene, expected, $time);
                $finish;
            end
        end
    endtask
    
    initial begin
        // Test reset, current scene should be town
        tick; resetn=1; tick; check(3'd0);

        // To house1
        @(negedge clk); at_house1=1; interact_pulse=1;
        tick; check(3'd1);

        // Back
        @(negedge clk); interact_pulse=0; at_house1=0; back_pulse=1;
        tick; check(3'd0);

        // To dungeon
        @(negedge clk); back_pulse=0; at_dungeon=1; interact_pulse=1;
        tick; check(3'd3);

        // To enemy
        @(negedge clk); at_dungeon=0; at_enemy=1; interact_pulse=0;
        tick; check(3'd3);

        // To battle
        @(negedge clk); interact_pulse=1;
        tick; check(3'd4);

        // To win
        @(negedge clk); interact_pulse=0; battle_win=1;
        tick; check(3'd5);

        $display("PASS tb_game_fsm"); $finish;
    end
endmodule
