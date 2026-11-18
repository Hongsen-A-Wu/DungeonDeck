 // Checked by Hongsen on 2026-11-17

`timescale 1ns/1ps

module tb_input_decoder;

    reg clk=0, resetn=0, scan_valid=0;
    reg [7:0] scan_code=0;
    wire up,down,left,right,confirm,back,restart;

    always #5 clk=~clk;

    input_decoder dut(clk,resetn,scan_code,scan_valid,
                      up,down,left,right,confirm,back,restart);

    task send;
        input [7:0] code;
        begin
            @(negedge clk); scan_code=code; scan_valid=1;
            @(posedge clk); #1;
        end
    endtask

    task idle;
        begin
            @(negedge clk); scan_valid=0;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        // Test resetn
        @(posedge clk); #1;
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Reset outputs are not zero");
            $finish;
        end
        resetn=1;

        // Test W
        send(8'h1D);
        if (up !== 1 || down !== 0 || left !== 0 ||
            right !== 0 || confirm !== 0 || back !== 0) begin
            $display("FAIL: Wrong W press");
            $finish;
        end

        // Test automatically reset
        idle();
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Pulse not cleared");
            $finish;
        end

        // Test S
        send(8'h1B);
        if (down !== 1 || up !== 0 || left !== 0 ||
            right !== 0 || confirm !== 0 || back !== 0) begin
            $display("FAIL: Wrong S press");
            $finish;
        end

        // Test A
        send(8'h1C);
        if (left !== 1 || up !== 0 || down !== 0 ||
            right !== 0 || confirm !== 0 || back !== 0) begin
            $display("FAIL: Wrong A press");
            $finish;
        end

        // Test D
        send(8'h23);
        if (right !== 1 || up !== 0 || down !== 0 ||
            left !== 0 || confirm !== 0 || back !== 0) begin
            $display("FAIL: Wrong D press");
            $finish;
        end

        // Test Enter
        send(8'h5A);
        if (confirm !== 1 || up !== 0 || down !== 0 ||
            left !== 0 || right !== 0 || back !== 0) begin
            $display("FAIL: Wrong Enter press");
            $finish;
        end

        // Test Escape
        send(8'h76);
        if (back !== 1 || up !== 0 || down !== 0 ||
            left !== 0 || right !== 0 || confirm !== 0) begin
            $display("FAIL: Wrong Escape press");
            $finish;
        end

        // Test release
        send(8'hF0); // break prefix
        send(8'h1D); // W release
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Wrong release handling");
            $finish;
        end

        // Test pressing W again after release
        send(8'h1D);
        if (up !== 1) begin
            $display("FAIL: Missing W press after release");
            $finish;
        end

        // Test extended MAKE
        send(8'hE0);
        send(8'h75); // Up arrow
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Extended MAKE not ignored");
            $finish;
        end

        // Test extended BREAK
        send(8'hE0);
        send(8'hF0);
        send(8'h75); // Up arrow release
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Extended BREAK not ignored");
            $finish;
        end

        // Test input after extended code
        send(8'h1B);
        if (down !== 1) begin
            $display("FAIL: Input after extended code");
            $finish;
        end

        // Test invalid scan code
        send(8'h00);
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Invalid scan code");
            $finish;
        end

        // Test scan_valid = 0
        @(negedge clk);
        scan_code=8'h1D;
        scan_valid=0;
        @(posedge clk); #1;
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Input accepted without scan_valid");
            $finish;
        end

        // Test reset during break sequence
        send(8'hF0);
        @(negedge clk);
        resetn=0;
        scan_valid=0;
        #1;
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Reset during break sequence");
            $finish;
        end

        @(negedge clk);
        resetn=1;

        // Test input after reset
        send(8'h1D);
        if (up !== 1) begin
            $display("FAIL: Input after reset");
            $finish;
        end

        idle();
        if ({up,down,left,right,confirm,back} !== 6'b0) begin
            $display("FAIL: Final pulse not cleared");
            $finish;
        end


        // Test R
        send(8'h2D); // R make
        if (restart !== 1) begin
            $display("FAIL: Missing R press");
            $finish;
        end

        // Test automatically reset
        @(negedge clk); scan_valid=0;
        @(posedge clk); #1;
        if (restart !== 0) begin
            $display("FAIL: Restart pulse not cleared");
            $finish;
        end

        // Test R release
        send(8'hF0);
        send(8'h2D);
        if (restart !== 0) begin
            $display("FAIL: Wrong R release handling");
            $finish;
        end

        // Test pressing R again
        send(8'h2D);
        if (restart !== 1) begin
            $display("FAIL: Missing second R press");
            $finish;
        end

        $display("PASS tb_input_decoder");
        $finish;
    end
endmodule
