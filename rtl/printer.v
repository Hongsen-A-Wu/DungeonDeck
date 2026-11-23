// VGA print: 160x120, 20x15 tiles, 8x8 pixels per tile.
// 9-bit RGB: 3 bits per colour channel.
module printer(
    input wire clk,
    input wire resetn,
    input wire [2:0] scene,
    input wire scene_ready,
    input wire [4:0] player_x,
    input wire [4:0] player_y,
    input wire dialogue_active,
    input wire [1:0] move_dir,
    input wire [1:0] dialogue_id,
    input wire [1:0] dialogue_page,
    output reg [7:0] draw_x,
    output reg [6:0] draw_y,
    output reg [8:0] draw_color,
    output wire draw_write
);
    localparam [2:0] TOWN    = 3'd0;
    localparam [2:0] HOUSE1  = 3'd1;
    localparam [2:0] HOUSE2  = 3'd2;
    localparam [2:0] DUNGEON = 3'd3;
    localparam [2:0] BATTLE  = 3'd4;
    localparam [2:0] VICTORY = 3'd5;
    localparam [2:0] DEFEAT  = 3'd6;
    localparam [2:0] START = 3'd7;

    // Color format: {RRR, GGG, BBB}.
    localparam [8:0] BLACK   = 9'b000_000_000;
    localparam [8:0] BLUE    = 9'b000_000_111;
    localparam [8:0] GREEN   = 9'b000_111_000;
    localparam [8:0] CYAN    = 9'b000_111_111;
    localparam [8:0] RED     = 9'b111_000_000;
    localparam [8:0] MAGENTA = 9'b111_000_111;
    localparam [8:0] YELLOW  = 9'b111_111_000;
    localparam [8:0] WHITE   = 9'b111_111_111;

    // Hold game data constant during one complete redraw.
    reg [2:0] draw_scene;
    reg [4:0] draw_player_x;
    reg [4:0] draw_player_y;

    // Change the size from 76799 to 19199
    // Memory of background
    (* ram_init_file = "../data/start.mif" *)
    reg [8:0] start_rom [0:19199]; 
    (* ram_init_file = "../data/town.mif" *)
    reg [8:0] town_rom [0:19199];
	(* ram_init_file = "../data/house1.mif" *)
	reg [8:0] house1_rom [0:19199];
	(* ram_init_file = "../data/house2.mif" *)
	reg [8:0] house2_rom [0:19199];
	(* ram_init_file = "../data/dungeon.mif" *)
	reg [8:0] dungeon_rom [0:19199];

    // Change the size to keep the tile constant 
	/*reg [7:0] house1_pixel, house2_pixel, dungeon_pixel;
    reg [7:0] start_pixel;
    reg [7:0] town_pixel;*/
	reg [6:0] next_y;
    reg [7:0] next_x;
    reg [8:0] start_pixel, town_pixel;
    reg [8:0] house1_pixel, house2_pixel, dungeon_pixel;

	 always @(*) begin
    if (draw_x == 9'd159)
        next_x = 8'd0;
    else
        next_x = draw_x[7:0] + 8'd1;
	 end
	 always @(*) begin
    if (draw_x == 9'd159) begin
        if (draw_y == 8'd119)
            next_y = 7'd0;
        else
            next_y = draw_y[6:0] + 7'd1;
    end else begin
        next_y = draw_y[6:0];
    end
	end
    wire [14:0] pixel_addr = !resetn ? 15'd0 :next_y * 15'd160 + next_x;
    //wire [16:0] pixel_addr = ({9'd0,next_y}<<8)+({9'd0,next_y}<<6)+{8'd0,next_x}; 
    (* ram_init_file = "../data/player.mif" *)
    reg [9:0] player_rom [0:255];
    reg [9:0] player_pixel;
    wire [7:0] player_addr = !resetn ? 8'd0 :{move_dir, next_y[2:0], next_x[2:0]}; // 这行用高 2 位选方向、低 6 位选该方向图里的像素

	always @(posedge clk) begin
		start_pixel   <= start_rom[pixel_addr];
		town_pixel    <= town_rom[pixel_addr];
		house1_pixel  <= house1_rom[pixel_addr];
		house2_pixel  <= house2_rom[pixel_addr];
		dungeon_pixel <= dungeon_rom[pixel_addr];
        player_pixel <= player_rom[player_addr];
    end
    wire [4:0] tile_x;
    wire [4:0] tile_y;
    wire [2:0] inside_x;
    wire [2:0] inside_y;
    wire exploration_scene;

    // Divide pixel coordinates by 8.
    assign tile_x = draw_x[7:3];
    assign tile_y = {1'b0, draw_y[6:3]};

    assign inside_x = draw_x[2:0];
    assign inside_y = draw_y[2:0];

    assign exploration_scene =(draw_scene == TOWN) ||(draw_scene == HOUSE1) ||(draw_scene == HOUSE2) || (draw_scene == DUNGEON);

    assign draw_write = resetn;

        always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            draw_scene <= START;
            draw_player_x <= 5'd0;
            draw_player_y <= 5'd0;

            draw_x <= 8'd0;
            draw_y <= 7'd0;
        end else if (draw_x == 8'd159) begin
            draw_x <= 8'd0;
            if (draw_y == 7'd119) begin
                draw_y <= 7'd0;
                if (scene_ready) begin
                    draw_scene <= scene;
                    draw_player_x <= player_x;
                    draw_player_y <= player_y;
                end
            end else draw_y <= draw_y + 7'd1;
        end else draw_x <= draw_x + 8'd1;
    end

    wire dialogue_overlay_valid;
    wire [8:0] dialogue_overlay_color;
    text_printer u_text_printer (
        .dialogue_active(dialogue_active),
        .dialogue_id(dialogue_id),
        .dialogue_page(dialogue_page),
        .pixel_x(draw_x), .pixel_y(draw_y),
        .overlay_valid(dialogue_overlay_valid),
        .overlay_color(dialogue_overlay_color)
    );

		always @(*) begin
    case (draw_scene)
        START:   draw_color = start_pixel;
        TOWN:    draw_color = town_pixel;
        HOUSE1:  draw_color = house1_pixel;
        HOUSE2:  draw_color = house2_pixel;
        DUNGEON: draw_color = dungeon_pixel;

        // Placeholder
        BATTLE: begin
        draw_color = BLACK;
        if (draw_y >= 8'd48 && draw_y < 8'd72) begin
            if (draw_x >= 9'd24 && draw_x < 9'd48) draw_color = WHITE;
            else if (draw_x >= 9'd112 && draw_x < 9'd136) draw_color = RED;
        end
        end

        VICTORY: draw_color = GREEN;
        DEFEAT:  draw_color = RED;
        default: draw_color = MAGENTA;
    endcase
    // Draw the player last, on top of the exploration map.
    if (exploration_scene && tile_x == draw_player_x && tile_y == draw_player_y && player_pixel[9]) 
    begin
        draw_color = player_pixel[8:0];
    end

    if (dialogue_overlay_valid)
        draw_color = dialogue_overlay_color;
    end
endmodule
