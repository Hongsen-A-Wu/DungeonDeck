// Checked by Honsgen on 2026-11-16

`timescale 1ns/1ps

module tb_input_decoder;

    reg clk=0, resetn=0, scan_valid=0;
    reg [7:0] scan_code=0;
    wire up,down,left,right,confirm,back;

    always #5 clk=~clk;

    input_decoder dut(clk,resetn,scan_code,scan_valid,
                      up,down,left,right,confirm,back);

    task send;
        input [7:0] code;
        begin
            @(negedge clk); scan_code=code; scan_valid=1;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        // Test resetn
        @(posedge clk); #1; resetn=1;
        
        // Test W
        send(8'h1D); // W make
        if (up !== 1) begin 
            $display("FAIL: Missing W press"); 
            $finish; 
        end

        // Test automatically reset 
        @(negedge clk); scan_valid=0;
        @(posedge clk); #1;
        if (up !== 0) begin 
            $display("FAIL: Pulse not cleared"); 
            $finish; 
        end

        // Test release
        send(8'hF0); // break prefix
        send(8'h1D); // W release: should not create a movement pulse
        if (up !== 0) begin 
            $display("FAIL: Wrong release handling"); 
            $finish; 
        end

        //Test enter
        send(8'h5A); // Enter
        if (confirm !== 1) begin 
            $display("FAIL: Missing Enter press"); 
            $finish; 
        end

        $display("PASS tb_input_decoder"); $finish;
    end
endmodule
