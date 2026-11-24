`timescale 1ns/1ps
module tb_card_rom;
    reg [3:0] card_id;
    wire card_valid;
    wire [1:0] card_type;
    wire [2:0] energy_cost;
    wire [5:0] damage,block,heal;
    wire [2:0] draw_count,energy_gain;
    wire [63:0] card_name;
    integer errors;

    card_rom dut (
        .card_id(card_id), .card_valid(card_valid),
        .card_type(card_type), .energy_cost(energy_cost),
        .damage(damage), .block(block), .heal(heal),
        .draw_count(draw_count), .energy_gain(energy_gain),
        .card_name(card_name)
    );

    initial begin
        errors = 0;

        card_id = 4'd0; #1;
        if (!card_valid || card_type != 2'd0 ||
            energy_cost != 3'd1 || damage != 6'd6 ||
            card_name != "STRIKE  ") begin
            $display("FAIL: Strike card"); errors = errors + 1;
        end

        card_id = 4'd4; #1;
        if (!card_valid || card_type != 2'd1 || heal != 6'd6 ||
            damage != 6'd0) begin
            $display("FAIL: Heal card"); errors = errors + 1;
        end

        card_id = 4'd6; #1;
        if (!card_valid || card_type != 2'd1 || draw_count != 3'd2) begin
            $display("FAIL: Insight card"); errors = errors + 1;
        end

        card_id = 4'd8; #1;
        if (!card_valid || card_type != 2'd2 || block != 6'd10) begin
            $display("FAIL: Wall card"); errors = errors + 1;
        end

        card_id = 4'd15; #1;
        if (card_valid || damage != 0 || heal != 0 || block != 0 ||
            draw_count != 0 || energy_gain != 0) begin
            $display("FAIL: Invalid card must be inert"); errors = errors + 1;
        end

        if (errors == 0) $display("PASS: tb_card_rom");
        else $display("FAIL: tb_card_rom, %0d error(s)",errors);
        $finish;
    end
endmodule
