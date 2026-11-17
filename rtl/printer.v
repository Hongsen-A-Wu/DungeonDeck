// VGA print: 320x240, 20x15 tiles, 16x16 pixels per tile.
// 9-bit RGB: 3 bits per colour channel.
// VGA adapter is instantiated in game_top.

module printer(
    input wire clk,
    input wire resetn,
    input wire [2:0] scene,
    input wire scene_ready,
    input wire [4:0] player_x,
    input wire [4:0] player_y,
    output reg [8:0] draw_x,
    output reg [7:0] draw_y,
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

    wire [4:0] tile_x;
    wire [4:0] tile_y;
    wire [3:0] inside_x;
    wire [3:0] inside_y;
    wire exploration_scene;

    // Divide pixel coordinates by 16.
    assign tile_x = draw_x[8:4];
    assign tile_y = {1'b0, draw_y[7:4]};

    assign inside_x = draw_x[3:0];
    assign inside_y = draw_y[3:0];

    assign exploration_scene =(draw_scene == TOWN) ||(draw_scene == HOUSE1) ||(draw_scene == HOUSE2) || (draw_scene == DUNGEON);

    assign draw_write = resetn;

        always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            draw_x <= 9'd0;
            draw_y <= 8'd0;
            draw_scene <= TOWN;
            draw_player_x <= 5'd10;
            draw_player_y <= 5'd7;
        end else if (draw_x == 9'd319) begin
            draw_x <= 9'd0;
            if (draw_y == 8'd239) begin
                draw_y <= 8'd0;
                if (scene_ready) begin
                    draw_scene <= scene;
                    draw_player_x <= player_x;
                    draw_player_y <= player_y;
                end
            end else draw_y <= draw_y + 8'd1;
        end else draw_x <= draw_x + 9'd1;
    end

    always @(*) begin
        // 1. Background.
        draw_color = BLACK;
        case (draw_scene)
            TOWN:    draw_color = GREEN;
            HOUSE1:  draw_color = BLUE;
            HOUSE2:  draw_color = CYAN;
            DUNGEON: draw_color = BLACK;
            BATTLE: begin
                if ((draw_x >= 9'd48) && (draw_x < 9'd96) &&
                    (draw_y >= 8'd96) && (draw_y < 8'd144))
                    draw_color = WHITE;
                if ((draw_x >= 9'd224) && (draw_x < 9'd272) &&
                    (draw_y >= 8'd96) && (draw_y < 8'd144))
                    draw_color = RED;
            end
            VICTORY: draw_color = GREEN;
            DEFEAT:  draw_color = RED;
            default: draw_color = MAGENTA;
        endcase
        if (exploration_scene) begin
            // 2. Grid lines.
            if ((inside_x == 4'd0) || (inside_y == 4'd0)) begin
                if (draw_scene == DUNGEON) draw_color = BLUE;
                else draw_color = BLACK;
            end
            // 3. Doors, exits and enemy.
            case (draw_scene)
                TOWN: begin
                    if ((tile_x == 5'd4) && (tile_y == 5'd3)) draw_color = BLUE;
                    if ((tile_x == 5'd15) && (tile_y == 5'd3)) draw_color = CYAN;
                    if ((tile_x == 5'd10) && (tile_y == 5'd12)) draw_color = MAGENTA;
                end
                HOUSE1, HOUSE2:
                    if ((tile_x == 5'd10) && (tile_y == 5'd13)) draw_color = YELLOW;
                DUNGEON:
                    if ((tile_x == 5'd10) && (tile_y == 5'd5)) draw_color = RED;
                default: begin end
            endcase
            // 4. Player: 12x12 white square, drawn last.
            if ((tile_x == draw_player_x) && (tile_y == draw_player_y) &&
                (inside_x >= 4'd2) && (inside_x <= 4'd13) &&
                (inside_y >= 4'd2) && (inside_y <= 4'd13))
                draw_color = WHITE;
        end
    end

endmodule