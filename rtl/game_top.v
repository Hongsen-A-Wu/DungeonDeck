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

    assign interact_pulse = confirm;
    assign back_pulse = back;

    reg [1:0] player_facing;

    always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn)
        player_facing <= 2'b11;  //default right
    else if (move_pulse && scene_ready && !interact_pulse && !back_pulse)
        player_facing <= move_dir;
    end

   exploration explore (
    .clock(CLOCK_50),
    .resetn(resetn),
    .scene(scene),
    .move_pulse(move_pulse && scene_ready && !interact_pulse && !back_pulse),
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
    wire at_house1_exit = 
        (player_x == 5'd9) && (player_y == 5'd14)||(player_x == 5'd10) && (player_y == 5'd14);
    wire at_house2_exit = 
        (player_x == 5'd9) && (player_y == 5'd14)||(player_x == 5'd10) && (player_y == 5'd14);

    wire at_enemy = (player_x == 5'd10) && (player_y == 5'd5);

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
        .move_dir(player_facing),

        .draw_x(draw_x),
        .draw_y(draw_y),
        .draw_color(draw_color),
        .draw_write(vga_write)
    );
endmodule
