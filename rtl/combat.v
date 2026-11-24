// Battle system for Dungeon Deck.
// All inputs ending in _pulse are one-clock events.
// Card statistics come from card_rom; enemy decisions come from enemy_ai.
module combat(clock,resetn,start_battle,
              player_hand,player_hand_count,enemy_hand,enemy_hand_count,
              player_selected_index,play_card_pulse,end_turn_pulse,
              player_hp,enemy_hp,player_block,enemy_block,
              energy,enemy_energy,player_turn,victory,defeat,
              selected_card_id,selected_card_valid,selected_card_affordable,
              player_card_used_pulse,player_card_used_index,
              enemy_card_used_pulse,enemy_card_used_index,
              player_draw_pulse,player_draw_count,
              enemy_draw_pulse,enemy_draw_count,
              player_turn_start_pulse,enemy_turn_start_pulse);

    input wire clock,resetn,start_battle;

    // Four 4-bit card IDs in each hand
    input wire [15:0] player_hand,enemy_hand;
    input wire [2:0] player_hand_count,enemy_hand_count;

    input wire [1:0] player_selected_index;
    input wire play_card_pulse,end_turn_pulse;

    output reg [6:0] player_hp,enemy_hp;
    output reg [6:0] player_block,enemy_block;
    output reg [3:0] energy,enemy_energy;
    output wire player_turn,victory,defeat;

    output wire [3:0] selected_card_id;
    output wire selected_card_valid,selected_card_affordable;

    // Used by deck_manager to remove the played card
    output reg player_card_used_pulse,enemy_card_used_pulse;
    output reg [1:0] player_card_used_index,enemy_card_used_index;

    // Used by deck_manager to draw cards
    output reg player_draw_pulse,enemy_draw_pulse;
    output reg [2:0] player_draw_count,enemy_draw_count;
    output reg player_turn_start_pulse,enemy_turn_start_pulse;

    parameter [6:0] PLAYER_MAX_HP = 7'd80;
    parameter [6:0] ENEMY_MAX_HP = 7'd30;
    parameter [3:0] ENERGY_PER_TURN = 4'd3;

    localparam [2:0] S_IDLE        = 3'd0;
    localparam [2:0] S_PLAYER_PREP = 3'd1;
    localparam [2:0] S_PLAYER      = 3'd2;
    localparam [2:0] S_PLAYER_WAIT = 3'd3;
    localparam [2:0] S_ENEMY_PREP  = 3'd4;
    localparam [2:0] S_ENEMY      = 3'd5;
    localparam [2:0] S_ENEMY_WAIT = 3'd6;
    localparam [2:0] S_FINISHED   = 3'd7;

    reg [2:0] state;
    reg win_latched,lose_latched;

    // Ignore the previous result when a new battle begins
    assign victory = win_latched && !start_battle;
    assign defeat = lose_latched && !start_battle;
    assign player_turn = (state == S_PLAYER_PREP) ||
                         (state == S_PLAYER) ||
                         (state == S_PLAYER_WAIT);

    // Select a card from the player's hand
    reg [3:0] player_card_id;
    always @(*) begin
        case (player_selected_index)
            2'd0: player_card_id = player_hand[3:0];
            2'd1: player_card_id = player_hand[7:4];
            2'd2: player_card_id = player_hand[11:8];
            2'd3: player_card_id = player_hand[15:12];
            default: player_card_id = 4'd0;
        endcase
    end

    wire p_valid;
    wire [2:0] p_cost,p_draw,p_gain;
    wire [5:0] p_damage,p_block,p_heal;

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

    assign selected_card_id = player_card_id;
    assign selected_card_valid =
        (player_selected_index < player_hand_count) && p_valid;
    assign selected_card_affordable =
        selected_card_valid && (energy >= {1'b0,p_cost});

    // Enemy AI chooses a card from its four hand slots
    wire ai_selected_valid;
    wire [1:0] ai_selected_index;
    wire [3:0] ai_selected_card_id;

    enemy_ai enemy_choice (
        .enemy_hand(enemy_hand),
        .enemy_hand_count(enemy_hand_count),
        .enemy_energy(enemy_energy),
        .selected_valid(ai_selected_valid),
        .selected_index(ai_selected_index),
        .selected_card_id(ai_selected_card_id)
    );

    wire e_valid;
    wire [2:0] e_cost,e_draw,e_gain;
    wire [5:0] e_damage,e_block,e_heal;

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

    wire enemy_can_play = ai_selected_valid && e_valid &&
                          (ai_selected_index < enemy_hand_count) &&
                          (enemy_energy >= {1'b0,e_cost});

    // Damage first removes Block, then HP
    wire [6:0] player_attack = {1'b0,p_damage};
    wire [6:0] enemy_attack = {1'b0,e_damage};

    wire [6:0] enemy_block_after_hit =
        (enemy_block > player_attack) ?
        (enemy_block - player_attack) : 7'd0;
    wire [6:0] enemy_damage_to_hp =
        (player_attack > enemy_block) ?
        (player_attack - enemy_block) : 7'd0;
    wire [6:0] enemy_hp_after_hit =
        (enemy_hp > enemy_damage_to_hp) ?
        (enemy_hp - enemy_damage_to_hp) : 7'd0;

    wire [6:0] player_block_after_hit =
        (player_block > enemy_attack) ?
        (player_block - enemy_attack) : 7'd0;
    wire [6:0] player_damage_to_hp =
        (enemy_attack > player_block) ?
        (enemy_attack - player_block) : 7'd0;
    wire [6:0] player_hp_after_hit =
        (player_hp > player_damage_to_hp) ?
        (player_hp - player_damage_to_hp) : 7'd0;

    // Extra bits prevent overflow before limiting HP, Block and Energy
    wire [7:0] player_hp_with_heal = {1'b0,player_hp} + {2'b00,p_heal};
    wire [7:0] enemy_hp_with_heal = {1'b0,enemy_hp} + {2'b00,e_heal};
    wire [7:0] player_block_with_gain = {1'b0,player_block} + {2'b00,p_block};
    wire [7:0] enemy_block_with_gain = {1'b0,enemy_block} + {2'b00,e_block};
    wire [4:0] player_energy_after_card =
        {1'b0,energy} - {2'b00,p_cost} + {2'b00,p_gain};
    wire [4:0] enemy_energy_after_card =
        {1'b0,enemy_energy} - {2'b00,e_cost} + {2'b00,e_gain};

    // Battle FSM
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            state <= S_IDLE;
            player_hp <= PLAYER_MAX_HP;
            enemy_hp <= ENEMY_MAX_HP;
            player_block <= 7'd0;
            enemy_block <= 7'd0;
            energy <= 4'd0;
            enemy_energy <= 4'd0;
            win_latched <= 1'b0;
            lose_latched <= 1'b0;
            player_card_used_pulse <= 1'b0;
            player_card_used_index <= 2'd0;
            enemy_card_used_pulse <= 1'b0;
            enemy_card_used_index <= 2'd0;
            player_draw_pulse <= 1'b0;
            player_draw_count <= 3'd0;
            enemy_draw_pulse <= 1'b0;
            enemy_draw_count <= 3'd0;
            player_turn_start_pulse <= 1'b0;
            enemy_turn_start_pulse <= 1'b0;
        end else begin
            // All event outputs last one clock cycle
            player_card_used_pulse <= 1'b0;
            enemy_card_used_pulse <= 1'b0;
            player_draw_pulse <= 1'b0;
            enemy_draw_pulse <= 1'b0;
            player_draw_count <= 3'd0;
            enemy_draw_count <= 3'd0;
            player_turn_start_pulse <= 1'b0;
            enemy_turn_start_pulse <= 1'b0;

            if (start_battle) begin
                state <= S_PLAYER_PREP;
                player_hp <= PLAYER_MAX_HP;
                enemy_hp <= ENEMY_MAX_HP;
                player_block <= 7'd0;
                enemy_block <= 7'd0;
                energy <= ENERGY_PER_TURN;
                enemy_energy <= 4'd0;
                win_latched <= 1'b0;
                lose_latched <= 1'b0;
                player_turn_start_pulse <= 1'b1;
            end else begin
                case (state)
                    S_IDLE: begin
                        // Wait for start_battle
                    end

                    S_PLAYER_PREP: begin
                        state <= S_PLAYER;
                    end

                    S_PLAYER: begin
                        if (play_card_pulse && selected_card_affordable) begin
                            energy <= (player_energy_after_card > 5'd15) ?
                                      4'd15 : player_energy_after_card[3:0];
                            player_hp <= (player_hp_with_heal > {1'b0,PLAYER_MAX_HP}) ?
                                         PLAYER_MAX_HP : player_hp_with_heal[6:0];
                            player_block <= (player_block_with_gain > 8'd127) ?
                                            7'd127 : player_block_with_gain[6:0];
                            enemy_block <= enemy_block_after_hit;
                            enemy_hp <= enemy_hp_after_hit;

                            player_card_used_pulse <= 1'b1;
                            player_card_used_index <= player_selected_index;
                            player_draw_count <= p_draw;
                            player_draw_pulse <= (p_draw != 3'd0);

                            if (enemy_hp_after_hit == 7'd0) begin
                                win_latched <= 1'b1;
                                state <= S_FINISHED;
                            end else begin
                                state <= S_PLAYER_WAIT;
                            end
                        end else if (end_turn_pulse) begin
                            enemy_block <= 7'd0;
                            enemy_energy <= ENERGY_PER_TURN;
                            enemy_turn_start_pulse <= 1'b1;
                            state <= S_ENEMY_PREP;
                        end
                    end

                    S_PLAYER_WAIT: begin
                        // Give deck_manager time to remove the card
                        state <= S_PLAYER;
                    end

                    S_ENEMY_PREP: begin
                        state <= S_ENEMY;
                    end

                    S_ENEMY: begin
                        if (enemy_can_play) begin
                            enemy_energy <= (enemy_energy_after_card > 5'd15) ?
                                            4'd15 : enemy_energy_after_card[3:0];
                            enemy_hp <= (enemy_hp_with_heal > {1'b0,ENEMY_MAX_HP}) ?
                                        ENEMY_MAX_HP : enemy_hp_with_heal[6:0];
                            enemy_block <= (enemy_block_with_gain > 8'd127) ?
                                           7'd127 : enemy_block_with_gain[6:0];
                            player_block <= player_block_after_hit;
                            player_hp <= player_hp_after_hit;

                            enemy_card_used_pulse <= 1'b1;
                            enemy_card_used_index <= ai_selected_index;
                            enemy_draw_count <= e_draw;
                            enemy_draw_pulse <= (e_draw != 3'd0);

                            if (player_hp_after_hit == 7'd0) begin
                                lose_latched <= 1'b1;
                                state <= S_FINISHED;
                            end else begin
                                state <= S_ENEMY_WAIT;
                            end
                        end else begin
                            player_block <= 7'd0;
                            energy <= ENERGY_PER_TURN;
                            player_turn_start_pulse <= 1'b1;
                            state <= S_PLAYER_PREP;
                        end
                    end

                    S_ENEMY_WAIT: begin
                        // Give deck_manager time to remove the card
                        state <= S_ENEMY;
                    end

                    S_FINISHED: begin
                        // Wait for the next battle
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end
endmodule
