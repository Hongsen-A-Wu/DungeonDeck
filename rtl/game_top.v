// Checked by Hongsen on 2026-11-17

// Dungeon Deck - Day 1 board debug top (no VGA/PS2 core yet)
// DE1-SoC: KEY inputs are active low.
module game_top (CLOCK_50,KEY,SW,PS2_CLK,PS2_DAT,LEDR,VGA_R,VGA_G,VGA_B,VGA_HS,VGA_VS,VGA_CLK,VGA_BLANK_N,VGA_SYNC_N);

    input  wire CLOCK_50;
    input  wire [3:0] KEY;
    input  wire [9:0] SW;
    inout wire PS2_CLK, PS2_DAT;
    output wire [9:0] LEDR;
    output wire [7:0] VGA_R, VGA_G, VGA_B;
    output wire VGA_HS, VGA_VS, VGA_CLK;
    output wire VGA_BLANK_N, VGA_SYNC_N;

    wire restart_pulse;
    wire system_resetn = KEY[0];
    wire resetn = system_resetn && !restart_pulse;

    wire step_pulse, interact_pulse, back_pulse, move_pulse;
    wire[1:0] move_dir;
    wire [2:0] scene;
    wire [4:0] player_x, player_y;

    // Change the size
    wire [7:0] draw_x; // 0~159
    wire [6:0] draw_y; // 0~119

    wire [8:0] draw_color; // 9 bits RGB
    wire vga_write;

    reg [2:0] previous_scene;
    wire scene_ready;

    wire [7:0] scan_code;
    wire scan_valid;

    localparam [2:0] SCENE_HOUSE1 = 3'd1;
    localparam [2:0] SCENE_HOUSE2 = 3'd2;
    localparam [2:0] SCENE_DUNGEON = 3'd3;
    localparam [1:0] DLG_NONE = 2'd0;
    localparam [1:0] DLG_HOUSE1 = 2'd1;
    localparam [1:0] DLG_HOUSE2 = 2'd2;
    localparam [1:0] DLG_MONSTER = 2'd3;

    // Character positions in the 160x120 backgrounds (20x15 tiles, 8px/tile).
    localparam [4:0] HOUSE1_NPC_X = 5'd13, HOUSE1_NPC_Y = 5'd6;
    localparam [4:0] HOUSE2_NPC_X = 5'd13, HOUSE2_NPC_Y = 5'd6;
    localparam [4:0] MONSTER_X = 5'd10, MONSTER_Y = 5'd8;

    wire dialogue_active;
    wire [1:0] dialogue_id;
    wire [1:0] dialogue_page;
    wire [1:0] dialogue_start_id;
    wire dialogue_start_allowed;
    wire dialogue_finished_pulse;

    // Manhattan distance exactly 1: must be immediately above/below/left/right.
    function adjacent4;
        input [4:0] ax, ay, bx, by;
        begin
            adjacent4 = ((ax == bx) &&
                         ((ay + 5'd1 == by) || (by + 5'd1 == ay))) ||
                        ((ay == by) &&
                         ((ax + 5'd1 == bx) || (bx + 5'd1 == ax)));
        end
    endfunction


    wire move_up, move_down, move_left, move_right;
    wire confirm, back;

    PS2_Controller ps2(
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

        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right),

        .confirm(confirm),
        .back(back),
        .restart(restart_pulse)
    );

    always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn)
        previous_scene <= 3'd7; //START
    else
        previous_scene <= scene;
    end

    assign scene_ready = (scene == previous_scene);
    

    // Pulse signals
    /*button_pulse step_button (
        .clock(CLOCK_50), .resetn(resetn), .key_n(KEY[1]), .pulse(step_pulse)
    );
    button_pulse interact_button (
        .clock(CLOCK_50), .resetn(resetn), .key_n(KEY[2]), .pulse(interact_pulse)
    );
    button_pulse back_button (
        .clock(CLOCK_50), .resetn(resetn), .key_n(KEY[3]), .pulse(back_pulse)
    );*/

    assign move_pulse =
    move_up | move_down | move_left | move_right;

    assign move_dir =
        move_up   ? 2'b00 :
        move_down ? 2'b01 :
        move_left ? 2'b10 :
                    2'b11;

    // Start conversation only beside the actual actor, never at an exit.
    wire near_house1_npc = scene_ready && (scene == SCENE_HOUSE1) &&
        adjacent4(player_x, player_y, HOUSE1_NPC_X, HOUSE1_NPC_Y);
    wire near_house2_npc = scene_ready && (scene == SCENE_HOUSE2) &&
        adjacent4(player_x, player_y, HOUSE2_NPC_X, HOUSE2_NPC_Y);
    wire near_monster = scene_ready && (scene == SCENE_DUNGEON) &&
        adjacent4(player_x, player_y, MONSTER_X, MONSTER_Y);

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

    // Next tile candidate; do not allow walking over a painted NPC/monster.
    reg [4:0] next_player_x, next_player_y;
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

    // Enter used by dialogue must not also be received by game_fsm.
    assign interact_pulse = confirm && scene_ready && !dialogue_active && !dialogue_start_allowed;
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

    // Should be modified after setting the map using VGA
    // Enter a building or dungeon by pressing KEY[2] on its door tile.
    wire at_house1 = 
        (player_x == 5'd4)  && (player_y == 5'd5); 
    wire at_house2 = 
        (player_x == 5'd4) && (player_y == 5'd12);
    wire at_dungeon = 
        (player_x == 5'd18) && (player_y == 5'd7);

    // All three room exits: bottom row, center two tiles (9,14) or (10,14)
    // Standing there alone does not leave; the FSM also requires Enter
    wire at_bottom_center_door = (player_y == 5'd14) &&
                                 ((player_x == 5'd9) || (player_x == 5'd10));
                                 
    wire at_house1_exit = (scene == SCENE_HOUSE1) && at_bottom_center_door;
    wire at_house2_exit = (scene == SCENE_HOUSE2) && at_bottom_center_door;
    wire at_dungeon_exit = (scene == SCENE_DUNGEON) && at_bottom_center_door;

    // Combat NOT enabled yet: the goblin currently opens dialogue only.
    // Future hook: dialogue_finished_pulse && dialogue_id==DLG_MONSTER.
    wire at_enemy = 1'b0;

    vga_adapter #(
        // Change the size of background
        .RESOLUTION("160x120"),
        .COLOR_DEPTH(9)
    )VGA(
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

    // game states ports
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

        .battle_win(1'b0),   // TODO: connect combat logic in Week 2/3
        .battle_lose(1'b0),  // TODO: connect combat logic in Week 2/3
        .scene(scene)
    );

    // SW[9]=0: x coordinate on LEDR[7:3]
    // SW[9]=1: y coordinate on LEDR[7:3]
    // LEDR[2:0] = scene (0 town, 1 house1, 2 house2, 3 dungeon, 4 battle)
    assign LEDR = {2'b00, (SW[9] ? player_y : player_x), scene};

    printer print (
        .clk(CLOCK_50),
        .resetn(resetn),
        .scene(scene),
        .scene_ready(scene_ready),
        .player_x(player_x),
        .player_y(player_y),
        .dialogue_active(dialogue_active),
        .dialogue_id(dialogue_id),
        .dialogue_page(dialogue_page),

        .draw_x(draw_x),
        .draw_y(draw_y),
        .draw_color(draw_color),
        .draw_write(vga_write)
    );
endmodule
