// Multi-character dialogue FSM. Verilog-2001, 50 MHz board clock.
// dialogue_id: 1=House1 elder, 2=House2 scholar, 3=Dungeon goblin.
module dialogue_controller (
    input  wire       clock,
    input  wire       resetn,
    input  wire       start_allowed,
    input  wire [1:0] start_dialogue_id,
    input  wire       confirm_pulse,
    input  wire       back_pulse,
    output reg        dialogue_active,
    output reg [1:0]  dialogue_id,
    output reg [1:0]  dialogue_page,
    output reg        dialogue_finished_pulse
);
    localparam [1:0] LAST_PAGE = 2'd1;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            dialogue_active          <= 1'b0;
            dialogue_id              <= 2'd0;
            dialogue_page            <= 2'd0;
            dialogue_finished_pulse  <= 1'b0;
        end else begin
            dialogue_finished_pulse <= 1'b0;
            if (dialogue_active) begin
                if (back_pulse) begin
                    dialogue_active <= 1'b0;
                end else if (confirm_pulse) begin
                    if (dialogue_page == LAST_PAGE) begin
                        dialogue_active <= 1'b0;
                        dialogue_finished_pulse <= 1'b1;
                    end else begin
                        dialogue_page <= dialogue_page + 2'd1;
                    end
                end
            end else if (start_allowed && confirm_pulse &&
                         start_dialogue_id != 2'd0) begin
                dialogue_active <= 1'b1;
                dialogue_id     <= start_dialogue_id;
                dialogue_page   <= 2'd0;
            end
        end
    end
endmodule
