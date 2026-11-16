// Checked by Hongsen on 2026-11-16

`timescale 1ns/1ps
module tb_exploration;
    reg clk=0, resetn=0, move_pulse=0;
    reg [1:0] move_dir=0;
    reg [2:0] scene=0;
    wire [4:0] player_x, player_y;

    always #5 clk=~clk;

    exploration dut(clk, resetn, scene, move_pulse, move_dir,
                    player_x, player_y);

    task tick; 
        begin @(posedge clk); 
            #1; 
        end 
    endtask
    
    task step;
        input [1:0] direction;
        begin
            @(negedge clk); move_dir=direction; move_pulse=1;
            tick;
            @(negedge clk); move_pulse=0;
        end
    endtask

    // The coordinate should be modified
    initial begin
        tick; resetn=1; tick;

        // Test Reset
        if (player_x !== 10 || player_y !== 7) begin 
            $display("FAIL: Bad reset"); 
            $finish; 
        end

        // Test movement
        step(2'b11); // right
        step(2'b01); // down

        if (player_x !== 11 || player_y !== 8) begin 
            $display("FAIL: Bad movement"); 
            $finish; 
        end

        // Test scene change
        @(negedge clk); 
        scene=3'd1;

        tick; // change scene -> center
        if (player_x !== 10 || player_y !== 7) begin 
            $display("FAIL: Bad scene reset"); 
            $finish; 
        end

        $display("PASS tb_exploration"); $finish;
    end
endmodule
