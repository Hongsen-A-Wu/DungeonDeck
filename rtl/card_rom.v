// Checked by Hongsen on 2026-11-24
// A LUT storing 10 types of card

module card_rom(card_id,card_valid,card_type,energy_cost,
                damage,block,heal,draw_count,energy_gain,card_name);
    input wire [3:0] card_id;

    output reg card_valid;
    output reg [1:0] card_type;
    output reg [2:0] energy_cost;
    output reg [5:0] damage,block,heal;
    output reg [2:0] draw_count,energy_gain;
    output reg [63:0] card_name; // Eight ASCII characters, space-padded

    localparam [1:0] ATTACK  = 2'd0;
    localparam [1:0] EFFECT  = 2'd1;
    localparam [1:0] DEFENSE = 2'd2;

    localparam [3:0] CARD_COUNT = 4'd10;

    always @(*) begin
        // Set to default
        card_valid = 1'b0;
        card_type = ATTACK;
        energy_cost = 3'd0;
        damage      = 6'd0;
        block       = 6'd0;
        heal        = 6'd0;
        draw_count  = 3'd0;
        energy_gain = 3'd0;
        card_name   = "INVALID ";
        
        case(card_id)
            // Damage cards (highest enemy AI priority)
            4'd0: begin
                card_valid = 1'b1;
                card_type = ATTACK;
                energy_cost = 3'd1;
                damage = 6'd6;
                card_name = "STRIKE  ";
            end
            4'd1: begin
                card_valid = 1'b1;
                card_type = ATTACK;
                energy_cost = 3'd2;
                damage = 6'd10;
                card_name = "HEAVY   ";
            end
            4'd2: begin
                card_valid = 1'b1;
                card_type = ATTACK;
                energy_cost = 3'd0;
                damage = 6'd3;
                card_name = "QUICK   ";
            end
            4'd3: begin
                card_valid = 1'b1;
                card_type = ATTACK;
                energy_cost = 3'd2;
                damage = 6'd8;
                card_name = "FIRE    ";
            end

            // Effect cards (second priority).
            4'd4: begin
                card_valid = 1'b1;
                card_type = EFFECT;
                energy_cost = 3'd2;
                heal = 6'd6;
                card_name = "HEAL    ";
            end
            4'd5: begin
                card_valid = 1'b1;
                card_type = EFFECT;
                energy_cost = 3'd1;
                energy_gain = 3'd2;
                card_name = "FOCUS   ";
            end
            4'd6: begin
                card_valid = 1'b1;
                card_type = EFFECT;
                energy_cost = 3'd1;
                draw_count = 3'd2;
                card_name = "INSIGHT ";
            end

            // Defense cards (third priority).
            4'd7: begin
                card_valid = 1'b1;
                card_type = DEFENSE;
                energy_cost = 3'd1;
                block = 6'd5;
                card_name = "DEFEND  ";
            end
            4'd8: begin
                card_valid = 1'b1;
                card_type = DEFENSE;
                energy_cost = 3'd2;
                block = 6'd10;
                card_name = "WALL    ";
            end
            4'd9: begin
                card_valid = 1'b1;
                card_type = DEFENSE;
                energy_cost = 3'd0;
                block = 6'd2;
                card_name = "BRACE   ";
            end
            default: begin end
        endcase
    end
endmodule
