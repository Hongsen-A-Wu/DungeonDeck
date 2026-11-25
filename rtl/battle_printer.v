// 绘制敌人、卡牌、血条、选择框
// Zicheng
// Pixel format: {red[2:0], green[2:0], blue[2:0]}.
module battle_printer  #(parameter [6:0] PLAYER_MAX_HP = 7'd50,parameter [6:0] ENEMY_MAX_HP  = 7'd30)
(
    input  wire  clk,
	 input  wire [7:0]  pixel_x, 
    input  wire [6:0]  pixel_y, 
    input  wire [6:0]  player_hp,
    input  wire [6:0]  enemy_hp,
    input  wire [3:0]  energy,
    input  wire player_turn, 
    input  wire [15:0] player_hand, 	//手牌ID
    input  wire [2:0]  player_hand_count, // 手牌数量
    input  wire [1:0]  selected_index, // 选中了哪个手牌槽
    input  wire selected_card_affordable, // 能量是否足够打出选中的牌
    output reg  [8:0]  pixel_color
);
    localparam [8:0] BACKGROUND = 9'b001_001_010;
    localparam [8:0] PANEL      = 9'b001_010_011;
    localparam [8:0] EMPTY_BAR  = 9'b010_010_010;
    localparam [8:0] WHITE      = 9'b111_111_111;
    localparam [8:0] GREEN      = 9'b010_110_011;
    localparam [8:0] RED        = 9'b111_001_001;
    localparam [8:0] YELLOW     = 9'b111_110_000;
    localparam [8:0] BLUE       = 9'b001_011_110;
    localparam [8:0] PURPLE     = 9'b100_010_110;
    localparam [8:0] DARK_RED   = 9'b100_001_001;
    localparam [8:0] BLACK      = 9'b000_000_000;
    // Both HP bars are 64 pixels wide.
    wire [12:0] player_hp_scaled = {player_hp, 6'b000000}; // hp*64
    wire [12:0] enemy_hp_scaled  = {enemy_hp, 6'b000000};
    wire [6:0] player_bar_width =(player_hp >= PLAYER_MAX_HP) ? 7'd64 : player_hp_scaled / PLAYER_MAX_HP; // draw as a rate
    wire [6:0] enemy_bar_width = (enemy_hp >= ENEMY_MAX_HP) ? 7'd64 :enemy_hp_scaled / ENEMY_MAX_HP;

    // Four 32-pixel slots start at x = 16, 48, 80 and 112.
    // The first 28 pixels of each slot form the card.
    wire [7:0] hand_x = pixel_x - 8'd16;
    wire [1:0] slot   = hand_x[6:5]; 
    wire [4:0] card_x = hand_x[4:0]; // 32*
    wire [6:0] card_y = pixel_y - 7'd86; // 

    wire in_card = (pixel_x >= 8'd16) && (pixel_x < 8'd144) && (pixel_y >= 7'd86) && (pixel_y < 7'd116) && (card_x < 5'd28) && (slot < player_hand_count);

    // Slot 0 uses [3:0], slot 1 uses [7:4], etc.
    wire [3:0] card_id = player_hand[slot * 4 +: 4];

    wire card_border = (card_x < 5'd2)  || (card_x >= 5'd26) || (card_y < 7'd2)  || (card_y >= 7'd28);

    // A 3x5 digit. Each group of three bits is one row.
    function [14:0] digit_shape;
        input [3:0] id;
        begin
            case (id)
                4'd0: digit_shape = 15'b111_101_101_101_111;
                4'd1: digit_shape = 15'b010_110_010_010_111;
                4'd2: digit_shape = 15'b111_001_111_100_111;
                4'd3: digit_shape = 15'b111_001_111_001_111;
                4'd4: digit_shape = 15'b101_101_111_001_001;
                4'd5: digit_shape = 15'b111_100_111_001_111;
                4'd6: digit_shape = 15'b111_100_111_101_111;
                4'd7: digit_shape = 15'b111_001_001_001_001;
                4'd8: digit_shape = 15'b111_101_111_101_111;
                4'd9: digit_shape = 15'b111_101_111_001_111;
                default: digit_shape = 15'd0;
            endcase
        end
    endfunction

    // Enlarge each digit pixel to 2x2, giving a 6x10 digit.
    wire [14:0] digit_bits = digit_shape(card_id);
    wire [4:0] digit_col = (card_x - 5'd11) >> 1;
    wire [6:0] digit_row = (card_y - 7'd10) >> 1;
    wire in_digit = (card_x >= 5'd11) && (card_x < 5'd17) && (card_y >= 7'd10) && (card_y < 7'd20);

    // Goblin sprite: 32x32 pixels, {opaque, red[2:0], green[2:0], blue[2:0]}.
    (* ram_init_file = "../data/goblin.mif" *)
    reg [9:0] goblin_rom [0:1023];
    reg [9:0] goblin_pixel;

    // Prefetch the pixel that printer will draw after the next clock edge.
    wire end_of_line = (pixel_x == 8'd159);
    wire [7:0] next_x = end_of_line ? 8'd0 : pixel_x + 8'd1;
    wire [6:0] next_y = end_of_line ? ((pixel_y == 7'd119) ? 7'd0 : pixel_y + 7'd1): pixel_y;

    // The top-left corner of the sprite is at screen position (96, 28).
    wire [7:0] goblin_x = next_x - 8'd96;
    wire [6:0] goblin_y = next_y - 7'd28;
    wire [9:0] goblin_addr = {goblin_y[4:0], goblin_x[4:0]};

    always @(posedge clk) begin
        goblin_pixel <= goblin_rom[goblin_addr];
    end

    // Check the screen position currently being drawn.
    wire in_enemy = (pixel_x >= 8'd96) && (pixel_x < 8'd128) && (pixel_y >= 7'd28) && (pixel_y < 7'd60);

    // Up to 15 energy pips, each six pixels wide with a two-pixel gap.
    wire [7:0] energy_x = pixel_x - 8'd16;
    wire in_energy = (pixel_x >= 8'd16) && (pixel_x < 8'd136) && (pixel_y >= 7'd74) && (pixel_y < 7'd79) && (energy_x[7:3] < energy) && (energy_x[2:0] < 3'd6);

    always @(*) begin
        pixel_color = BACKGROUND;
        // Player HP: x = 8..71. Enemy HP: x = 88..151.
        if (pixel_y >= 7'd8 && pixel_y < 7'd14) begin
            if (pixel_x >= 8'd8 && pixel_x < 8'd72) begin
                if (pixel_x - 8'd8 < player_bar_width)
                    pixel_color = GREEN;
                else
                    pixel_color = EMPTY_BAR;
            end 
				else if (pixel_x >= 8'd88 && pixel_x < 8'd152) begin
					  if (pixel_x - 8'd88 < enemy_bar_width)
                    pixel_color = RED;
                else
                    pixel_color = EMPTY_BAR;
            end
        end

        // Draw opaque goblin pixels over the battle background.
        if (in_enemy && goblin_pixel[9]) pixel_color = goblin_pixel[8:0];

        // Bottom hand panel and energy.
        if (pixel_y >= 7'd82) pixel_color = PANEL;
        if (in_energy) pixel_color = YELLOW;
        if (in_card) begin
            // IDs 0..3 attack, 4..6 effect, 7..9 defense.
            if (card_id <= 4'd3)
                pixel_color = DARK_RED;
            else if (card_id <= 4'd6)
                pixel_color = PURPLE;
            else
                pixel_color = BLUE;

            if (in_digit && digit_bits[14 - digit_row * 3 - digit_col])
                pixel_color = WHITE;

            if (card_border) begin
                if (player_turn && slot == selected_index)
                    pixel_color = selected_card_affordable ? YELLOW : RED;
                else
                    pixel_color = BLACK;
            end
        end
    end

endmodule