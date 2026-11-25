// Checked by Hongsen on 2026-11-24

module combat(clock,resetn,start_battle,

              play_card_pulse,end_turn_pulse,
              player_turn_start_pulse,enemy_turn_start_pulse,
              player_draw_pulse,enemy_draw_pulse,
              player_card_used_pulse,enemy_card_used_pulse,

              victory,defeat,
              
              player_selected_index,
              player_hand,player_hand_count,player_hp,player_block,player_energy,player_draw_count,
              player_card_used_index,

              enemy_hand,enemy_hand_count,enemy_hp,enemy_block,enemy_energy,enemy_draw_count,
              enemy_card_used_index,
              
              player_turn,
              player_selected_card_id,player_selected_card_valid,selected_card_affordable);

    // Outside signals
    input wire clock, resetn,start_battle;

    // Input from keyboard, decoded by input_decoder
    input wire[15:0] player_hand, enemy_hand; // Four 4-bit card IDs
    input wire[1:0] player_selected_index; // Index of the card, 0-3
    input wire play_card_pulse,end_turn_pulse; // Enter and space

    // Represent 0-5 hand card number
    // Input from deck_manage
    input wire[2:0] player_hand_count, enemy_hand_count;

    // Return Player and Monster State
    output reg[6:0] player_hp,    enemy_hp;
    output reg[6:0] player_block, enemy_block;
    output reg[3:0] player_energy,       enemy_energy;

    // Return battle state
    output wire player_turn,victory,defeat;
    
    // Return card infomation
    output wire[3:0] player_selected_card_id; // Get the id, 0-10
    output wire player_selected_card_valid,selected_card_affordable;

    // Return card update for deck_manage to remove cards
    output reg player_card_used_pulse,enemy_card_used_pulse;
    output reg [1:0] player_card_used_index,enemy_card_used_index;

    // Used by deck_manage to draw cards
    output reg player_draw_pulse,enemy_draw_pulse;  // Effect card draw
    output reg [2:0] player_draw_count,enemy_draw_count;
    output reg player_turn_start_pulse,enemy_turn_start_pulse; // Turn draw

    // Need to be test
    parameter [6:0] PLAYER_MAX_HP = 7'd50;
    parameter [6:0] ENEMY_MAX_HP = 7'd30;
    parameter [3:0] ENERGY_PER_TURN = 4'd4;

    // Battle state parameters
    localparam [2:0] IDLE        = 3'd0; // Wait for start
    localparam [2:0] PLAYER_PREP = 3'd1; // Initialize energy and hand cards
    localparam [2:0] PLAYER      = 3'd2; // Player turn
    localparam [2:0] PLAYER_WAIT = 3'd3; // Wait for update hand card
    localparam [2:0] ENEMY_PREP  = 3'd4;
    localparam [2:0] ENEMY       = 3'd5;
    localparam [2:0] ENEMY_WAIT  = 3'd6;
    localparam [2:0] FINISHED    = 3'd7;

    // Battle state
    reg[2:0] state;
    reg win,lose;

    // Update victory and defeat
    // Ignore previous result when a new battle begins
    assign victory = win  && !start_battle;
    assign defeat = lose && !start_battle;

    // Update player_turn
    assign player_turn = (state == PLAYER_PREP) ||
                         (state == PLAYER) ||
                         (state == PLAYER_WAIT);

    // Card choosing
    wire p_valid, e_valid; // Weather they choose a card
    wire[2:0] p_cost,p_draw,p_gain, e_cost,e_draw,e_gain;
    wire [5:0] p_damage,p_block,p_heal, e_damage,e_block,e_heal;

    // Selected a card from the player's hand
    reg[3:0] player_card_id;

    always @(*) begin
        case(player_selected_index)
            2'd0: player_card_id = player_hand[3:0];
            2'd1: player_card_id = player_hand[7:4];
            2'd2: player_card_id = player_hand[11:8];
            2'd3: player_card_id = player_hand[15:12];
            default: player_card_id = 4'd0;
        endcase
    end

    // Get information
    card_rom player_card_rom (
        .card_id(player_card_id),
        .card_valid(p_valid),
        .card_type(),
        .energy_cost(p_cost),
        .damage(p_damage),
        .block(p_block),
        .heal(p_heal),
        .draw_count(p_draw),
        .energy_gain(p_gain),
        .card_name()
    );

    // If the chosen card index between 0-3
    assign player_selected_card_valid = 
        (player_selected_index < player_hand_count) && p_valid;
    assign player_selected_card_id = player_card_id;
    assign selected_card_affordable =
        player_selected_card_valid && (player_energy >= {1'b0,p_cost});

    // Selected a card from the monster's hand
    wire ai_selected_valid;
    wire[1:0] ai_selected_index; // 0-3
    wire[3:0] ai_selected_card_id; // 0-10
    
    enemy_ai enemy_choice (
        .enemy_hand(enemy_hand),
        .enemy_hand_count(enemy_hand_count),
        .enemy_energy(enemy_energy),
        .selected_valid(ai_selected_valid),
        .selected_index(ai_selected_index),
        .selected_card_id(ai_selected_card_id)
    );

    // Get card information
    card_rom enemy_card_rom (
        .card_id(ai_selected_card_id),
        .card_valid(e_valid),
        .card_type(),
        .energy_cost(e_cost),
        .damage(e_damage),
        .block(e_block),
        .heal(e_heal),
        .draw_count(e_draw),
        .energy_gain(e_gain),
        .card_name()
    );

    wire enemy_selected_card_valid = ai_selected_valid && e_valid &&
                                    (ai_selected_index < enemy_hand_count) &&
                                    (enemy_energy >= {1'b0,e_cost});

    // Update states
    // ATTACK
    wire [6:0] player_attack = {1'b0,p_damage};
    wire [6:0] enemy_attack  = {1'b0,e_damage};

    // Block State
    wire [6:0] player_block_after_hit =
        (player_block > enemy_attack) ?
        (player_block - enemy_attack) : 7'd0;
    wire [6:0] enemy_block_after_hit =
        (enemy_block > player_attack) ?
        (enemy_block - player_attack) : 7'd0;

    // Damage to HP
    wire [6:0] player_damage_to_hp =
        (enemy_attack > player_block) ?
        (enemy_attack - player_block) : 7'd0;
    wire [6:0] enemy_damage_to_hp =
        (player_attack > enemy_block) ?
        (player_attack - enemy_block) : 7'd0;

    // HP State
    wire [6:0] player_hp_after_hit =
        (player_hp > player_damage_to_hp) ?
        (player_hp - player_damage_to_hp) : 7'd0;
    wire [6:0] enemy_hp_after_hit =
        (enemy_hp > enemy_damage_to_hp) ?
        (enemy_hp - enemy_damage_to_hp) : 7'd0;
    
    // EFFECT
    wire [7:0] player_hp_with_heal = {1'b0,player_hp} + {2'b00,p_heal};
    wire [7:0] enemy_hp_with_heal  = {1'b0,enemy_hp} + {2'b00,e_heal};

    // DEFFENCE
    wire [7:0] player_block_with_gain = {1'b0,player_block} + {2'b00,p_block};
    wire [7:0] enemy_block_with_gain  = {1'b0,enemy_block} + {2'b00,e_block};

    // Energy
    wire [4:0] player_energy_after_card =
        {1'b0,player_energy} - {2'b00,p_cost} + {2'b00,p_gain};
    wire [4:0] enemy_energy_after_card =
        {1'b0,enemy_energy} - {2'b00,e_cost} + {2'b00,e_gain};

    // Battle FSM
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            // Initial battle state
            state <= IDLE;
            player_hp <= PLAYER_MAX_HP;
            enemy_hp <= ENEMY_MAX_HP;
            player_block <= 7'd0;
            enemy_block <= 7'd0;
            player_energy <= 4'd0;
            enemy_energy <= 4'd0;
            win <= 1'b0;
            lose <= 1'b0;
            player_card_used_pulse <= 1'b0;
            enemy_card_used_pulse <= 1'b0;
            player_card_used_index <= 2'd0;
            enemy_card_used_index <= 2'd0;
            player_draw_pulse <= 1'b0;
            enemy_draw_pulse <= 1'b0;
            player_draw_count <= 3'd0;
            enemy_draw_count <= 3'd0;
            player_turn_start_pulse <= 1'b0;
            enemy_turn_start_pulse <= 1'b0;
        end else begin
            // All pulses last one clock cycle
            // Need to be updated by deck_manage
            player_card_used_pulse <= 1'b0;
            enemy_card_used_pulse <= 1'b0;
            player_draw_pulse <= 1'b0;
            enemy_draw_pulse <= 1'b0;
            player_draw_count <= 3'd0;
            enemy_draw_count <= 3'd0;
            player_turn_start_pulse <= 1'b0;
            enemy_turn_start_pulse <= 1'b0;
            if (start_battle) begin
                state <= PLAYER_PREP;
                player_hp <= PLAYER_MAX_HP;
                enemy_hp <= ENEMY_MAX_HP;
                player_block <= 7'd0;
                enemy_block <= 7'd0;
                player_energy <= ENERGY_PER_TURN;
                enemy_energy <= 4'd0;
                win <= 1'b0;
                lose <= 1'b0;
                player_turn_start_pulse <= 1'b1;
            end else begin
                case (state)
                    IDLE: begin
                        // Wait for start_battle
                    end
                    PLAYER_PREP: begin
                        // Wait  1 clock cycle for deck_manage to prepare cards
                        state <= PLAYER;
                    end
                    PLAYER: begin
                        // Player uses a valid and affordable card
                        if (play_card_pulse && selected_card_affordable) begin
                            // Update player energy, largest is 15
                            player_energy <=
                                (player_energy_after_card > 5'd15) ?
                                4'd15 : player_energy_after_card[3:0];

                            // Update player HP
                            player_hp <=
                                (player_hp_with_heal > {1'b0,PLAYER_MAX_HP}) ?
                                PLAYER_MAX_HP : player_hp_with_heal[6:0];

                            // Update player block
                            player_block <=
                                (player_block_with_gain > 8'd127) ?
                                7'd127 : player_block_with_gain[6:0];

                            // Damage enemy
                            enemy_block <= enemy_block_after_hit;
                            enemy_hp <= enemy_hp_after_hit;

                            // Remove the used card
                            player_card_used_pulse <= 1'b1;
                            player_card_used_index <= player_selected_index;

                            // Extra card draw
                            player_draw_count <= p_draw;
                            player_draw_pulse <= (p_draw != 3'd0);

                            // Check victory
                            if (enemy_hp_after_hit == 7'd0) begin
                                win <= 1'b1;
                                state <= FINISHED;
                            end else begin
                                state <= PLAYER_WAIT;
                            end

                        end else if (end_turn_pulse) begin
                            // Prepare enemy turn
                            enemy_block <= 7'd0;
                            enemy_energy <= ENERGY_PER_TURN;
                            enemy_turn_start_pulse <= 1'b1;
                            state <= ENEMY_PREP;
                        end
                    end

                    PLAYER_WAIT: begin
                        // Wait for deck_manage to update cards
                        state <= PLAYER;
                    end

                    ENEMY_PREP: begin
                        // Wait for deck_manage to prepare cards
                        state <= ENEMY;
                    end

                    ENEMY: begin
                        // Enemy uses a valid and affordable card
                        if (enemy_selected_card_valid) begin
                            // Update enemy energy
                            enemy_energy <=
                                (enemy_energy_after_card > 5'd15) ?
                                4'd15 : enemy_energy_after_card[3:0];

                            // Update enemy HP
                            enemy_hp <=
                                (enemy_hp_with_heal > {1'b0,ENEMY_MAX_HP}) ?
                                ENEMY_MAX_HP : enemy_hp_with_heal[6:0];

                            // Update enemy block
                            enemy_block <=
                                (enemy_block_with_gain > 8'd127) ?
                                7'd127 : enemy_block_with_gain[6:0];

                            // Damage player
                            player_block <= player_block_after_hit;
                            player_hp <= player_hp_after_hit;

                            // Remove the used card
                            enemy_card_used_pulse <= 1'b1;
                            enemy_card_used_index <= ai_selected_index;

                            // Extra card draw
                            enemy_draw_count <= e_draw;
                            enemy_draw_pulse <= (e_draw != 3'd0);

                            // Check defeat
                            if (player_hp_after_hit == 7'd0) begin
                                lose <= 1'b1;
                                state <= FINISHED;
                            end else begin
                                state <= ENEMY_WAIT;
                            end

                        end else begin
                            // Prepare player turn
                            player_block <= 7'd0;
                            player_energy <= ENERGY_PER_TURN;
                            player_turn_start_pulse <= 1'b1;
                            state <= PLAYER_PREP;
                        end
                    end

                    ENEMY_WAIT: begin
                        // Wait for deck_manage to update cards
                        state <= ENEMY;
                    end

                    FINISHED: begin
                        // Wait for the next battle
                    end

                    default: state <= IDLE;

                endcase
            end
        end
    end
endmodule

