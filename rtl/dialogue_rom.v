// 3 dialogue IDs * 2 pages * 2 lines x 18 ASCII characters per page.
// 0..17 = first line; 18..35 = second line.
module dialogue_rom (
    input wire [1:0] dialogue_id,
    input wire [1:0] page,
    input wire [5:0] char_index,
    output reg [7:0] ascii_code
);
    reg [143:0] line1, line2;
    always @(*) begin
        case ({dialogue_id,page})
            4'b0100: begin line1 = "OLD MAN: WELCOME! "; line2 = "PLEASE REST HERE. "; end
            4'b0101: begin line1 = "DUNGEON IS EAST.  "; line2 = "BEWARE THE GOBLIN!"; end
            4'b1000: begin line1 = "SCHOLAR: HELLO!   "; line2 = "I STUDY OLD MAPS. "; end
            4'b1001: begin line1 = "SEEK THE DUNGEON. "; line2 = "WATCH FOR GOBLINS."; end
            4'b1100: begin line1 = "GOBLIN: WHO GOES? "; line2 = "WHO DARES ENTER?  "; end
            4'b1101: begin line1 = "THIS CAVE IS MINE!"; line2 = "PREPARE TO FIGHT! "; end
            default: begin line1 = "                  "; line2 = "                  "; end
        endcase
        ascii_code = 8'h20;
        if (char_index < 6'd18)
            ascii_code = line1[143 - (char_index * 8) -: 8];
        else if (char_index < 6'd36)
            ascii_code = line2[143 - ((char_index - 6'd18) * 8) -: 8];
    end
endmodule
