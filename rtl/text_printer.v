// Transparent dialogue overlay over the existing 160x120 scene.
// 18 columns x 2 rows; one ASCII glyph in each 8x8 cell.
module text_printer (
    input wire dialogue_active,
    input wire [1:0] dialogue_id,
    input wire [1:0] dialogue_page,
    input wire [7:0] pixel_x,
    input wire [6:0] pixel_y,
    output wire overlay_valid,
    output reg [8:0] overlay_color
);
    localparam [8:0] BOX_BG    = 9'b000_000_010;
    localparam [8:0] BOX_EDGE  = 9'b111_111_000;
    localparam [8:0] FONT_COLOR= 9'b111_111_111;

    wire inside_box = (pixel_x >= 8'd3 && pixel_x <= 8'd156 &&
                       pixel_y >= 7'd76 && pixel_y <= 7'd116);
    assign overlay_valid = dialogue_active && inside_box;

    wire on_line1 = (pixel_x >= 8'd8 && pixel_x < 8'd152 &&
                     pixel_y >= 7'd84 && pixel_y < 7'd91);
    wire on_line2 = (pixel_x >= 8'd8 && pixel_x < 8'd152 &&
                     pixel_y >= 7'd100 && pixel_y < 7'd107);

    wire [4:0] column = (pixel_x - 8'd8) >> 3;
    wire [5:0] char_index = on_line2 ? (6'd18 + {1'b0, column})
                                      : {1'b0, column};
    wire [2:0] glyph_col = pixel_x[2:0];
    wire [2:0] glyph_row = on_line2 ? (pixel_y - 7'd100)
                                      : (pixel_y - 7'd84);
    wire [7:0] ascii_code;
    wire glyph_pixel;

    dialogue_rom u_rom (
        .dialogue_id(dialogue_id),
        .page(dialogue_page), .char_index(char_index),
        .ascii_code(ascii_code)
    );
    font u_font (
        .ascii_code(ascii_code), .pixel_col(glyph_col),
        .pixel_row(glyph_row), .pixel_on(glyph_pixel)
    );

    always @(*) begin
        overlay_color = BOX_BG;
        if (pixel_x == 8'd3 || pixel_x == 8'd156 ||
            pixel_y == 7'd76 || pixel_y == 7'd116)
            overlay_color = BOX_EDGE;
        else if ((on_line1 || on_line2) && glyph_pixel)
            overlay_color = FONT_COLOR;
    end
endmodule
