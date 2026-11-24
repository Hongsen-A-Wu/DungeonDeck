module battle_text(pixel_x,pixel_y,
                    player_hp,enemy_hp,player_block,enemy_block,
                    energy,player_turn,selected_card_id,selected_card_valid,
                    text_on,text_color);

    input wire [7:0] pixel_x;
    input wire [6:0] pixel_y;
    input wire [6:0] player_hp,enemy_hp;
    input wire [6:0] player_block,enemy_block;
    input wire [3:0] energy;
    input wire player_turn; // 1: player, 0: enemy
    input wire [3:0] selected_card_id;
    input wire selected_card_valid;

    output reg text_on;
    output reg [8:0] text_color;

    localparam [8:0] WHITE  = 9'b111_111_111;
    localparam [8:0] RED    = 9'b111_010_010;
    localparam [8:0] YELLOW = 9'b111_111_000;

    localparam [87:0] PLAYER_TURN_TEXT = "PLAYER TURN";
    localparam [87:0] ENEMY_TURN_TEXT  = "ENEMY TURN ";

    localparam [23:0] HP_TEXT     = "HP:";
    localparam [31:0] BLOCK_TEXT  = "BLK:";
    localparam [55:0] ENERGY_TEXT = "ENERGY:";

    localparam [39:0] COST_TEXT = "COST:";
    localparam [31:0] DMG_TEXT  = "DMG:";
    localparam [39:0] HEAL_TEXT = "HEAL:";
    localparam [39:0] DRAW_TEXT = "DRAW:";
    localparam [39:0] GAIN_TEXT = "GAIN:";
    localparam [31:0] NONE_TEXT = "NONE";
    localparam [39:0] CARD_TEXT = "CARD:";

    wire card_valid; // 0~9 valid
    wire [1:0] card_type; // 00 attack; 01 effect; 10 deffense
    wire [2:0] card_cost,card_draw,card_energy_gain;
    wire [5:0] card_damage,card_block,card_heal;
    wire [63:0] card_name;

    card_rom selected_card(
        .card_id(selected_card_id),

        .card_valid(card_valid),
        .card_type(card_type),
        .energy_cost(card_cost),
        .damage(card_damage),
        .block(card_block),
        .heal(card_heal),
        .draw_count(card_draw),
        .energy_gain(card_energy_gain),
        .card_name(card_name)
    );

    reg active;
    reg [7:0] ascii_char;
    // coordinate inside text region
    reg [7:0] local_x;
    reg [6:0] local_y;
    reg [4:0] char_index;
    
    wire font_pixel_on;
    font battle_font(
        .ascii_code(ascii_char),
        .pixel_col(local_x[2:0]),
        .pixel_row(local_y[2:0]),

        .pixel_on(font_pixel_on)
    );

    always@(*) begin
        text_on = active && font_pixel_on;
    end

    wire show_card = selected_card_valid && card_valid;

    // Change character to number by ascii code
    // Player
    wire [7:0] player_hp_hundreds = "0" + player_hp / 100;
    wire [7:0] player_hp_tens= "0" + (player_hp / 10) % 10;
    wire [7:0] player_hp_ones= "0" + player_hp % 10;

    //Enemy
    wire [7:0] enemy_hp_hundreds = "0" + enemy_hp / 100;
    wire [7:0] enemy_hp_tens= "0" + (enemy_hp / 10) % 10;
    wire [7:0] enemy_hp_ones= "0" + enemy_hp % 10;

    always @(*) begin
        // Set default
        active = 1'b0;
        ascii_char = " ";
        local_x = 8'd0;
        local_y = 7'd0;
        char_index = 5'd0;
        text_color = WHITE;

        // Player HP
        if(pixel_x >= 5 && pixel_x < 53 && 
           pixel_y >= 1 && pixel_y < 9)begin
            active = 1'b1;
            local_x = pixel_x - 5;
            local_y = pixel_y - 1;
            char_index = local_x/8; // Character is 8*8

            if(char_index<3)
                // Get characters
                ascii_char = HP_TEXT[23-char_index*8 -: 8];
            else if(char_index == 3)
                ascii_char = player_hp_hundreds;
            else if(char_index == 4)
                ascii_char = player_hp_tens;
            else if(char_index == 5)
                ascii_char = player_hp_ones;
        end

        // Enemy HP
        else if(pixel_x >= 90 && pixel_x < 138 && 
                pixel_y >= 1 && pixel_y < 9) begin
            active = 1'b1;

            local_x = pixel_x-90;
            local_y = pixel_y-1;

            char_index = local_x/8;
            text_color = RED;

            if(char_index < 3)
                ascii_char = HP_TEXT[23-char_index*8 -: 8];
            else if(char_index == 3)
                ascii_char = enemy_hp_hundreds;
            else if(char_index == 4)
                ascii_char = enemy_hp_tens;
            else if(char_index == 5)
                ascii_char = enemy_hp_ones;
        end

        // Player block
        else if(pixel_x >= 5 && pixel_x < 61 &&
             pixel_y >= 10 && pixel_y < 18) begin
            active = 1'b1;

            local_x = pixel_x - 5;
            local_y = pixel_y - 10;
            char_index = local_x / 8;

            if (char_index < 4)
                ascii_char = BLOCK_TEXT[31-char_index*8 -: 8];
            else if (char_index == 4)
                ascii_char = "0" + player_block / 100;
            else if (char_index == 5)
                ascii_char = "0" + (player_block / 10) % 10;
            else if (char_index == 6)
                ascii_char = "0" + player_block % 10;
        end

        // Enemy block
        else if (pixel_x >= 90 && pixel_x < 146 &&
             pixel_y >= 10 && pixel_y < 18) begin

            active = 1'b1;

            local_x = pixel_x - 90;
            local_y = pixel_y - 10;

            char_index = local_x / 8;
            text_color = RED;

            if (char_index < 4)
                ascii_char = BLOCK_TEXT[31-char_index*8 -: 8];
            else if (char_index == 4)
                ascii_char = "0" + enemy_block / 100;
            else if (char_index == 5)
                ascii_char = "0" + (enemy_block / 10) % 10;
            else if (char_index == 6)
                ascii_char = "0" + enemy_block % 10;
        end


        // Player energy
        else if (pixel_x >= 5 && pixel_x < 77 &&
             pixel_y >= 19 && pixel_y < 27) begin

            active = 1'b1;

            local_x = pixel_x - 5;
            local_y = pixel_y - 19;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (char_index < 7)
                ascii_char = ENERGY_TEXT[55-char_index*8 -: 8];
            else if (char_index == 7)
                ascii_char = "0" + energy / 10;
            else if (char_index == 8)
                ascii_char = "0" + energy % 10;
        end

        // Current Turn
        else if (pixel_x >= 44 && pixel_x < 132 &&
             pixel_y >= 28 && pixel_y < 36) begin

            active = 1'b1;

            local_x = pixel_x - 44;
            local_y = pixel_y - 28;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (player_turn)
                ascii_char = PLAYER_TURN_TEXT[87-char_index*8 -: 8];
            else
                ascii_char = ENEMY_TURN_TEXT[87-char_index*8 -: 8];
        end

        // Selected Card Name
        else if (pixel_x >= 3 && pixel_x < 67 &&
                pixel_y >= 80 && pixel_y < 88) begin

            active = 1'b1;

            local_x = pixel_x - 3;
            local_y = pixel_y - 80;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (show_card)
                ascii_char = card_name[63-char_index*8 -: 8];
            else if (char_index < 4)
                ascii_char = NONE_TEXT[31-char_index*8 -: 8];
        end

        // Selected Card Cost
        else if (show_card &&
                pixel_x >= 3 && pixel_x < 51 &&
                pixel_y >= 89 && pixel_y < 97) begin

            active = 1'b1;

            local_x = pixel_x - 3;
            local_y = pixel_y - 89;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (char_index < 5)
                ascii_char = COST_TEXT[39-char_index*8 -: 8];
            else if (char_index == 5)
                ascii_char = "0" + card_cost;
        end

        // Selected Card Damage
        else if (show_card && card_type == 2'd0 &&
                pixel_x >= 84 && pixel_x < 132 &&
                pixel_y >= 80 && pixel_y < 88) begin

            active = 1'b1;

            local_x = pixel_x - 84;
            local_y = pixel_y - 80;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (char_index < 4)
                ascii_char = DMG_TEXT[31-char_index*8 -: 8];
            else if (char_index == 4)
                ascii_char = "0" + card_damage / 10;
            else if (char_index == 5)
                ascii_char = "0" + card_damage % 10;
        end

        // Selected Card Block
        else if (show_card && card_type == 2'd2 &&
                pixel_x >= 84 && pixel_x < 132 &&
                pixel_y >= 80 && pixel_y < 88) begin

            active = 1'b1;

            local_x = pixel_x - 84;
            local_y = pixel_y - 80;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (char_index < 4)
                ascii_char = BLOCK_TEXT[31-char_index*8 -: 8];
            else if (char_index == 4)
                ascii_char = "0" + card_block / 10;
            else if (char_index == 5)
                ascii_char = "0" + card_block % 10;
        end

        // Selected Card Heal
        else if (show_card && card_type == 2'd1 &&
                card_heal != 0 &&
                pixel_x >= 84 && pixel_x < 140 &&
                pixel_y >= 80 && pixel_y < 88) begin

            active = 1'b1;

            local_x = pixel_x - 84;
            local_y = pixel_y - 80;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (char_index < 5)
                ascii_char = HEAL_TEXT[39-char_index*8 -: 8];
            else if (char_index == 5)
                ascii_char = "0" + card_heal / 10;
            else if (char_index == 6)
                ascii_char = "0" + card_heal % 10;
        end

        // Selected Card Draw
        else if (show_card && card_type == 2'd1 &&
                card_draw != 0 &&
                pixel_x >= 84 && pixel_x < 132 &&
                pixel_y >= 80 && pixel_y < 88) begin

            active = 1'b1;

            local_x = pixel_x - 84;
            local_y = pixel_y - 80;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (char_index < 5)
                ascii_char = DRAW_TEXT[39-char_index*8 -: 8];
            else if (char_index == 5)
                ascii_char = "0" + card_draw;
        end

        // Selected Card Energy Gain
        else if (show_card && card_type == 2'd1 &&
                card_energy_gain != 0 &&
                pixel_x >= 84 && pixel_x < 132 &&
                pixel_y >= 80 && pixel_y < 88) begin

            active = 1'b1;

            local_x = pixel_x - 84;
            local_y = pixel_y - 80;

            char_index = local_x / 8;
            text_color = YELLOW;

            if (char_index < 5)
                ascii_char = GAIN_TEXT[39-char_index*8 -: 8];
            else if (char_index == 5)
                ascii_char = "0" + card_energy_gain;
        end


    end
endmodule
