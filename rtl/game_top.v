// Checked by Hongsen on 2026-11-13

// Dungeon Deck - Day 1 board debug top (no VGA/PS2 core yet)
// DE1-SoC: KEY inputs are active low.
module game_top (CLOCK_50,KEY,SW,LEDR,VGA_R, VGA_G, VGA_B,VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N, VGA_SYNC_N);

    input  wire CLOCK_50;
    input  wire [3:0] KEY;
    input  wire [9:0] SW;
    output wire [9:0] LEDR;
    output wire [7:0] VGA_R, VGA_G, VGA_B;
    output wire VGA_HS, VGA_VS, VGA_CLK;
    output wire VGA_BLANK_N, VGA_SYNC_N;

    wire resetn = KEY[0];
    wire step_pulse, interact_pulse, back_pulse;
    wire [2:0] scene;
    wire [4:0] player_x, player_y;

    wire [8:0] draw_x; // 0~319
    wire [7:0] draw_y; // 0~239
    wire [8:0] draw_color; // 9 bits RGB
    wire vga_write;

    reg [2:0] previous_scene;
    wire scene_ready;

    always @(posedge CLOCK_50 or negedge resetn) begin
    if (!resetn)
        previous_scene <= 3'd7; //START
    else
        previous_scene <= scene;
    end

    assign scene_ready = (scene == previous_scene);
    

    // Pulse signals
    button_pulse step_button (
        .clock(CLOCK_50), .resetn(resetn), .key_n(KEY[1]), .pulse(step_pulse)
    );
    button_pulse interact_button (
        .clock(CLOCK_50), .resetn(resetn), .key_n(KEY[2]), .pulse(interact_pulse)
    );
    button_pulse back_button (
        .clock(CLOCK_50), .resetn(resetn), .key_n(KEY[3]), .pulse(back_pulse)
    );

   exploration explore (
    .clock(CLOCK_50),
    .resetn(resetn),
    .scene(scene),
    .move_pulse(step_pulse && scene_ready && !interact_pulse && !back_pulse),
    .move_dir(SW[1:0]),
    .player_x(player_x),
    .player_y(player_y)
);

    // Should be modified after setting the map using VGA
    // Enter a building or dungeon by pressing KEY[2] on its door tile.
    wire at_house1 = 
        (player_x == 5'd4)  && (player_y == 5'd6);
    wire at_house2 = 
        (player_x == 5'd4) && (player_y == 5'd13);
    wire at_dungeon = 
        (player_x == 5'd18) && (player_y == 5'd7);

    wire at_house1_exit = (player_x == 5'd10) && (player_y == 5'd13);
    wire at_house2_exit = (player_x == 5'd10) && (player_y == 5'd13);
    wire at_enemy = (player_x == 5'd10) && (player_y == 5'd5);

    vga_adapter #(
        .RESOLUTION("320x240"),
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

        .draw_x(draw_x),
        .draw_y(draw_y),
        .draw_color(draw_color),
        .draw_write(vga_write)
    );
endmodule