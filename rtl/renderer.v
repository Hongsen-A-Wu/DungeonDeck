// TODO (Zicheng): graphics rendering FSM / sprite ROM and VGA adapter.
// Renderer receives game outputs; renderer must not modify game state.
// Agree on resolution and color width before implementing this module.
module renderer (clk,resetn,scene,scene_ready,player_x,player_y,VGA_R,VGA_G,VGA_B,VGA_HS,VGA_VS,VGA_CLK,VGA_BLANK_N,VGA_SYNC_N);
    input wire clk;
    input wire resetn;
    input wire [2:0] scene;
    input wire scene_ready;
    // Map coordinates, not pixel coordinates.
    input wire [4:0] player_x;
    input wire [4:0] player_y;
    output wire [7:0] VGA_R;
    output wire [7:0] VGA_G;
    output wire [7:0] VGA_B;
    output wire VGA_HS;
    output wire VGA_VS;
    output wire VGA_CLK;
    output wire VGA_BLANK_N;
    output wire VGA_SYNC_N;
    
    // Scene IDs match game_fsm.
    localparam TOWN    = 3'd0;
    localparam HOUSE1  = 3'd1;
    localparam HOUSE2  = 3'd2;
    localparam DUNGEON = 3'd3;
    localparam BATTLE  = 3'd4;
    localparam VICTORY = 3'd5;
    localparam DEFEAT  = 3'd6;

    // color: {red, green, blue}.
    localparam [2:0] BLACK   = 3'b000;
    localparam [2:0] BLUE    = 3'b001;
    localparam [2:0] GREEN   = 3'b010;
    localparam [2:0] CYAN    = 3'b011;
    localparam [2:0] RED     = 3'b100;
    localparam [2:0] MAGENTA = 3'b101;
    localparam [2:0] YELLOW  = 3'b110;
    localparam [2:0] WHITE   = 3'b111;

    // Pixel currently being written.
    reg [7:0] pixel_x;
    reg [6:0] pixel_y;
    reg [2:0] colour;

    wire plot;

    // Game data held constant during one complete redraw.
    reg [2:0] draw_scene;
    reg [4:0] draw_player_x;
    reg [4:0] draw_player_y;

    wire [4:0] tile_x;
    wire [4:0] tile_y;

    wire [2:0] inside_x;
    wire [2:0] inside_y;

    wire exploration_scene;

    // Divide pixel coordinates by 8 to find the map tile.
    assign tile_x = pixel_x[7:3];
    assign tile_y = {1'b0, pixel_y[6:3]};

    // Position inside an 8x8 tile: 0 to 7.
    assign inside_x = pixel_x[2:0];
    assign inside_y = pixel_y[2:0];

    assign exploration_scene = (draw_scene == TOWN)||(draw_scene == HOUSE1)||(draw_scene == HOUSE2)||(draw_scene == DUNGEON);

    // Write one pixel per clock whenever reset is released.
    assign plot = resetn;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            pixel_x <= 8'd0;
            pixel_y <= 7'd0;

            draw_scene <= TOWN;
            draw_player_x <= 5'd10;
            draw_player_y <= 5'd7;
        end else begin

            if (pixel_x == 8'd159) begin
                pixel_x <= 8'd0;

                if (pixel_y == 7'd119) begin
                    pixel_y <= 7'd0;

                    // Capture game data for the next redraw.
                    // Avoid capturing during a scene transition.
                    if (scene_ready) begin
                        draw_scene <= scene;
                        draw_player_x <= player_x;
                        draw_player_y <= player_y;
                    end
                end else begin
                    pixel_y <= pixel_y + 7'd1;
                end
            end else begin
                pixel_x <= pixel_x + 8'd1;
            end

        end
    end
    always @(*) begin
        // 1. Background.
        colour = BLACK;
        case (draw_scene)
            TOWN: colour = GREEN;
            HOUSE1: colour = BLUE;
            HOUSE2: colour = CYAN;
            DUNGEON: colour = BLACK;

            BATTLE: begin
                colour = BLACK;
                // Player placeholder: white rectangle.
                if ((pixel_x >= 8'd24) &&(pixel_x <  8'd48) &&(pixel_y >= 7'd48) &&(pixel_y <  7'd72))
                    colour = WHITE;
                // Enemy placeholder: red rectangle.
                if ((pixel_x >= 8'd112) &&(pixel_x <  8'd136) &&(pixel_y >= 7'd48) &&(pixel_y <  7'd72))
                    colour = RED;
            end

            VICTORY: colour = GREEN;
            DEFEAT: colour = RED;
            default: colour = MAGENTA;
        endcase

        if (exploration_scene) begin
            // 2. Grid lines.
            if ((inside_x == 3'd0) ||(inside_y == 3'd0)) begin

                if (draw_scene == DUNGEON) colour = BLUE;
                else colour = BLACK;
            end
            // 3. Doors, exits and enemy.
            case (draw_scene)
                TOWN: begin
                    // House 1 entrance: (4,3).
                    if ((tile_x == 5'd4) &&(tile_y == 5'd3))
                        colour = BLUE;
                    // House 2 entrance: (15,3).
                    if ((tile_x == 5'd15) && (tile_y == 5'd3))
                        colour = CYAN;
                    // Dungeon entrance: (10,12).
                    if ((tile_x == 5'd10) && (tile_y == 5'd12))
                        colour = MAGENTA;
                end
                HOUSE1, HOUSE2: begin
                    // Interior exit: (10,13).
                    if ((tile_x == 5'd10) && (tile_y == 5'd13))
                        colour = YELLOW;
                end
                DUNGEON: begin
                    // Enemy: (10,5).
                    if ((tile_x == 5'd10) && (tile_y == 5'd5))
                        colour = RED;
                end
                default: begin
                end
            endcase
            // 4. Player: 6x6 white square inside its tile.
            // Draw last so the player appears above the map.
            if ((tile_x == draw_player_x) &&
                (tile_y == draw_player_y) &&
                (inside_x >= 3'd1) &&
                (inside_x <= 3'd6) &&
                (inside_y >= 3'd1) &&
                (inside_y <= 3'd6))
                colour = WHITE;

        end
    end
    
    //  VGA adapter.
    vga_adapter #(
        .RESOLUTION("160x120"),
        .MONOCHROME("FALSE"),
        .BITS_PER_COLOUR_CHANNEL(1),
        .BACKGROUND_IMAGE("black.mif")
    ) VGA (
        .resetn(resetn),
        .clock(clk),
        .colour(colour),
        .x(pixel_x),
        .y(pixel_y),
        .plot(plot),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_CLK(VGA_CLK),
        .VGA_BLANK(VGA_BLANK_N),
        .VGA_SYNC(VGA_SYNC_N)
    );
endmodule

