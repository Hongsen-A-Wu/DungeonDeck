// Dungeon Deck - DE1-SoC top module
// Keyboard controls exploration, dialogue and card combat.
// Battle is started after the dungeon monster dialogue finishes.

module game_top (CLOCK_50,KEY,SW,PS2_CLK,PS2_DAT,LEDR,
                 VGA_R,VGA_G,VGA_B,VGA_HS,VGA_VS,VGA_CLK,VGA_BLANK_N,VGA_SYNC_N);

    input wire CLOCK_50;
    input wire [3:0] KEY;
    input wire [9:0] SW;
    inout wire PS2_CLK,PS2_DAT;
    output wire [9:0] LEDR;
    output wire [7:0] VGA_R,VGA_G,VGA_B;
    output wire VGA_HS,VGA_VS,VGA_CLK,VGA_BLANK_N,VGA_SYNC_N;

    localparam [2:0] SCENE_HOUSE1  = 3'd1;
    localparam [2:0] SCENE_HOUSE2  = 3'd2;
    localparam [2:0] SCENE_DUNGEON = 3'd3;
    localparam [2:0] SCENE_BATTLE  = 3'd4;

    localparam [1:0] DLG_NONE    = 2'd0;
    localparam [1:0] DLG_HOUSE1  = 2'd1;
    localparam [1:0] DLG_HOUSE2  = 2'd2;
    localparam [1:0] DLG_MONSTER = 2'd3;

    // Positions use 20x15 tiles. Each tile has 8x8 pixels.
    localparam [4:0] HOUSE1_NPC_X = 5'd13, HOUSE1_NPC_Y = 5'd6;
    localparam [4:0] HOUSE2_NPC_X = 5'd13, HOUSE2_NPC_Y = 5'd6;
    localparam [4:0] MONSTER_X    = 5'd10, MONSTER_Y    = 5'd8;

    wire restart_pulse;
    wire system_resetn = KEY[0]; // KEY[0] is active low
    wire resetn = system_resetn && !restart_pulse;

    wire [2:0] scene;
    reg [2:0] previous_scene;
    wire scene_ready;
    wire [4:0] player_x,player_y;

    wire [7:0] scan_code;
    wire scan_valid;
    wire move_up,move_down,move_left,move_right;
    wire confirm,back;
    wire move_pulse,interact_pulse,back_pulse;
    wire [1:0] move_dir;
    reg [1:0] facing_dir;

    // Battle keyboard inputs
    wire [1:0] player_selected_index;
    wire play_card_pulse,end_turn_pulse;
    wire battle_start_pulse;

    // Card hands: four 4-bit IDs per side
    wire [15:0] player_hand,enemy_hand;
    wire [2:0] player_hand_count,enemy_hand_count;
    wire player_card_used_pulse,enemy_card_used_pulse;
    wire [1:0] player_card_used_index,enemy_card_used_index;
    wire player_draw_pulse,enemy_draw_pulse;
    wire [2:0] player_draw_count,enemy_draw_count;
    wire player_turn_start_pulse,enemy_turn_start_pulse;

    // Combat status
    wire [6:0] player_hp,enemy_hp;
    wire [6:0] player_block,enemy_block;
    wire [3:0] energy,enemy_energy;
    wire player_turn,battle_win,battle_lose;
    wire [3:0] selected_card_id;
    wire selected_card_valid,selected_card_affordable;

    // VGA is 160x120, 9-bit RGB
    wire [7:0] draw_x;
    wire [6:0] draw_y;
    wire [8:0] draw_color,printer_color,battle_color;
    wire vga_write;

    wire dialogue_active;
    wire [1:0] dialogue_id,dialogue_page,dialogue_start_id;
    wire dialogue_start_allowed,dialogue_finished_pulse;

    function adjacent4;
        input [4:0] ax,ay,bx,by;
        begin
            adjacent4 = ((ax == bx) &&
                         ((ay + 5'd1 == by) || (by + 5'd1 == ay))) ||
                        ((ay == by) &&
                         ((ax + 5'd1 == bx) || (bx + 5'd1 == ax)));
        end
    endfunction

    PS2_Controller ps2 (
        .CLOCK_50(CLOCK_50),
        .reset(!system_resetn),
        .the_command(8'h00),
        .send_command(1'b0),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .command_was_sent(),
        .error_communication_timed_out(),
        .received_data(scan_code),
        .received_data_en(scan_valid)
    );

    input_decoder keyboard (
        .clock(CLOCK_50),
        .resetn(system_resetn),
        .scan_code(scan_code),
        .scan_valid(scan_valid),
        .in_battle(scene == SCENE_BATTLE),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),
        .confirm(confirm),
        .back(back),
        .restart(restart_pulse),
        .player_selected_index(player_selected_index),
        .play_card_pulse(play_card_pulse),
        .end_turn_pulse(end_turn_pulse)
    );

    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn)
            previous_scene <= 3'd7; // START
        else
            previous_scene <= scene;
    end

    assign scene_ready = (scene == previous_scene);
    assign battle_start_pulse = (scene == SCENE_BATTLE) &&
                                (previous_scene != SCENE_BATTLE);

    assign move_pulse = move_up | move_down | move_left | move_right;
    assign move_dir = move_up   ? 2'b00 :
                      move_down ? 2'b01 :
                      move_left ? 2'b10 : 2'b11;

    // Remember the last movement direction for the player's sprite.
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn)
            facing_dir <= 2'b01;
        else if (move_pulse && scene_ready && !dialogue_active)
            facing_dir <= move_dir;
    end

    // Dialogue starts when the player stands beside an NPC or monster.
    wire near_house1_npc = scene_ready && (scene == SCENE_HOUSE1) &&
        adjacent4(player_x,player_y,HOUSE1_NPC_X,HOUSE1_NPC_Y);
    wire near_house2_npc = scene_ready && (scene == SCENE_HOUSE2) &&
        adjacent4(player_x,player_y,HOUSE2_NPC_X,HOUSE2_NPC_Y);
    wire near_monster = scene_ready && (scene == SCENE_DUNGEON) &&
        adjacent4(player_x,player_y,MONSTER_X,MONSTER_Y);

    assign dialogue_start_allowed = near_house1_npc || near_house2_npc || near_monster;
    assign dialogue_start_id = near_house1_npc ? DLG_HOUSE1 :
                               near_house2_npc ? DLG_HOUSE2 :
                               near_monster ? DLG_MONSTER : DLG_NONE;

    dialogue_controller u_dialogue_controller (
        .clock(CLOCK_50),
        .resetn(resetn),
        .start_allowed(dialogue_start_allowed),
        .start_dialogue_id(dialogue_start_id),
        .confirm_pulse(confirm),
        .back_pulse(back),
        .dialogue_active(dialogue_active),
        .dialogue_id(dialogue_id),
        .dialogue_page(dialogue_page),
        .dialogue_finished_pulse(dialogue_finished_pulse)
    );

    // Stop the player from walking over characters.
    reg [4:0] next_player_x,next_player_y;
    always @(*) begin
        next_player_x = player_x;
        next_player_y = player_y;
        case (move_dir)
            2'b00: if (player_y > 5'd0)  next_player_y = player_y - 5'd1;
            2'b01: if (player_y < 5'd14) next_player_y = player_y + 5'd1;
            2'b10: if (player_x > 5'd0)  next_player_x = player_x - 5'd1;
            2'b11: if (player_x < 5'd19) next_player_x = player_x + 5'd1;
        endcase
    end

    wire move_into_character =
        ((scene == SCENE_HOUSE1) && (next_player_x == HOUSE1_NPC_X) &&
                                      (next_player_y == HOUSE1_NPC_Y)) ||
        ((scene == SCENE_HOUSE2) && (next_player_x == HOUSE2_NPC_X) &&
                                      (next_player_y == HOUSE2_NPC_Y)) ||
        ((scene == SCENE_DUNGEON) && (next_player_x == MONSTER_X) &&
                                        (next_player_y == MONSTER_Y));

    // The last page of monster dialogue triggers the fight.
    // game_fsm needs BOTH interact_pulse and at_enemy to enter BATTLE.
    wire monster_dialogue_done = near_monster && dialogue_finished_pulse &&
                                 (dialogue_id == DLG_MONSTER);
    wire at_enemy = monster_dialogue_done;

    assign interact_pulse = (confirm && scene_ready && !dialogue_active &&
                             !dialogue_start_allowed) || monster_dialogue_done;
    assign back_pulse = back && !dialogue_active;

    exploration explore (
        .clock(CLOCK_50),
        .resetn(resetn),
        .scene(scene),
        .move_pulse(move_pulse && scene_ready && !dialogue_active &&
                    !interact_pulse && !back_pulse && !move_into_character),
        .move_dir(move_dir),
        .player_x(player_x),
        .player_y(player_y)
    );

    // Door tiles from the current maps.
    wire at_house1 = (player_x == 5'd4) && (player_y == 5'd5);
    wire at_house2 = (player_x == 5'd4) && (player_y == 5'd12);
    wire at_dungeon = (player_x == 5'd18) && (player_y == 5'd7);

    // Press Enter at either of the two bottom center exit tiles.
    wire at_bottom_center_door = (player_y == 5'd14) &&
                                 ((player_x == 5'd9) || (player_x == 5'd10));
    wire at_house1_exit = (scene == SCENE_HOUSE1) && at_bottom_center_door;
    wire at_house2_exit = (scene == SCENE_HOUSE2) && at_bottom_center_door;
    wire at_dungeon_exit = (scene == SCENE_DUNGEON) && at_bottom_center_door;

    game_fsm game (
        .clock(CLOCK_50),
        .resetn(resetn),
        .interact_pulse(interact_pulse),
        .back_pulse(back_pulse),
        .at_house1(at_house1),
        .at_house2(at_house2),
        .at_house1_exit(at_house1_exit),
        .at_house2_exit(at_house2_exit),
        .at_dungeon(at_dungeon),
        .at_dungeon_exit(at_dungeon_exit),
        .at_enemy(at_enemy),
        .battle_win(battle_win),
        .battle_lose(battle_lose),
        .scene(scene)
    );

    // Temporary hand manager. It cycles through card IDs 0..9.
    // Replace this with a shuffled deck manager when the full deck is ready.
    deck_manager deck (
        .clock(CLOCK_50),
        .resetn(resetn),
        .start_battle(battle_start_pulse),
        .player_card_used_pulse(player_card_used_pulse),
        .player_card_used_index(player_card_used_index),
        .enemy_card_used_pulse(enemy_card_used_pulse),
        .enemy_card_used_index(enemy_card_used_index),
        .player_draw_pulse(player_draw_pulse),
        .player_draw_count(player_draw_count),
        .enemy_draw_pulse(enemy_draw_pulse),从起始位开始，向高位连续取 4 位
        .enemy_draw_count(enemy_draw_count),
        .player_turn_start_pulse(player_turn_start_pulse),
        .enemy_turn_start_pulse(enemy_turn_start_pulse),
        .player_hand(player_hand),
        .player_hand_count(player_hand_count),
        .enemy_hand(enemy_hand),
        .enemy_hand_count(enemy_hand_count)
    );

    combat battle (
        .clock(CLOCK_50),
        .resetn(resetn),
        .start_battle(battle_start_pulse),
        .player_hand(player_hand),
        .player_hand_count(player_hand_count),
        .enemy_hand(enemy_hand),
        .enemy_hand_count(enemy_hand_count),
        .player_selected_index(player_selected_index),
        .play_card_pulse(play_card_pulse),
        .end_turn_pulse(end_turn_pulse),
        .player_hp(player_hp),
        .enemy_hp(enemy_hp),
        .player_block(player_block),
        .enemy_block(enemy_block),
        .energy(energy),
        .enemy_energy(enemy_energy),
        .player_turn(player_turn),
        .victory(battle_win),
        .defeat(battle_lose),
        .selected_card_id(selected_card_id),
        .selected_card_valid(selected_card_valid),
        .selected_card_affordable(selected_card_affordable),
        .player_card_used_pulse(player_card_used_pulse),
        .player_card_used_index(player_card_used_index),
        .enemy_card_used_pulse(enemy_card_used_pulse),
        .enemy_card_used_index(enemy_card_used_index),
        .player_draw_pulse(player_draw_pulse),
        .player_draw_count(player_draw_count),
        .enemy_draw_pulse(enemy_draw_pulse),
        .enemy_draw_count(enemy_draw_count),
        .player_turn_start_pulse(player_turn_start_pulse),
        .enemy_turn_start_pulse(enemy_turn_start_pulse)
    );

    // A simple battle display until the final card/text renderer is ready.
    battle_printer u_battle_display (
        .pixel_x(draw_x),
        .pixel_y(draw_y),
        .player_hp(player_hp),
        .enemy_hp(enemy_hp),
        .energy(energy),
        .player_turn(player_turn),
        .player_hand(player_hand),
        .player_hand_count(player_hand_count),
        .selected_index(player_selected_index),
        .selected_card_affordable(selected_card_affordable),
        .pixel_color(battle_color)
    );

    printer print (
        .clk(CLOCK_50),
        .resetn(resetn),
        .scene(scene),
        .scene_ready(scene_ready),
        .player_x(player_x),
        .player_y(player_y),
        .move_dir(facing_dir),
        .dialogue_active(dialogue_active),
        .dialogue_id(dialogue_id),
        .dialogue_page(dialogue_page),
        .draw_x(draw_x),
        .draw_y(draw_y),
        .draw_color(printer_color),
        .draw_write(vga_write)
    );

    assign draw_color = (scene == SCENE_BATTLE) ? battle_color : printer_color;

    vga_adapter #(
        .RESOLUTION("160x120"),
        .COLOR_DEPTH(9)
    ) VGA (
        .resetn(resetn),
        .clock(CLOCK_50),
        .color(draw_color),
        .x(draw_x),
        .y(draw_y),
        .write(vga_write),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );

    // In battle, LEDs show HP; otherwise they show the player's position.
    // SW[9] = 0: player HP or X; SW[9] = 1: enemy HP or Y.
    // LEDR[2:0] always shows the current scene.
    assign LEDR = (scene == SCENE_BATTLE) ?
                  {(SW[9] ? enemy_hp : player_hp),scene} :
                  {2'b00,(SW[9] ? player_y : player_x),scene};

endmodule
