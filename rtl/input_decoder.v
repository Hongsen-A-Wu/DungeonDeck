// Checked by Hongsen on 2026-11-13

// Independent of physical PS/2 receiver and scan_code decoder

// From the official DE1-SoC PS2_Controller core.
    // Connect scan_code to received_data
    // Connect scan_valid to received_data_en

// Emits a one-clock pulse on MAKE codes only 
// Handles F0 break, E0 extended

module input_decoder (clock,resetn,scan_code,scan_valid,
                      move_up,move_down,move_left,move_right,
                      confirm,back,restart);

    input      clock;
    input      resetn;
    input[7:0] scan_code; // Used to identify the keyboard input
    input      scan_valid; // Used to record if the input should be handled

    // Return these variables for later blocks
    output reg move_up,move_down,move_left,move_right;

    output reg confirm;
    output reg back;
    output reg restart;

    reg break_pending; // Used to record if a key is released
    reg extended_pending; // Used to ignore extended key's inputs

    always @(posedge clock or negedge resetn) begin
        // Set the initial states
        if (!resetn) begin
            break_pending    <= 1'b0;
            extended_pending <= 1'b0;
            move_up          <= 1'b0;
            move_down        <= 1'b0;
            move_left        <= 1'b0;
            move_right       <= 1'b0;
            confirm          <= 1'b0;
            back             <= 1'b0;
            restart          <= 1'b0;

        end else begin
            move_up    <= 1'b0;
            move_down  <= 1'b0;
            move_left  <= 1'b0;
            move_right <= 1'b0;
            confirm    <= 1'b0;
            back       <= 1'b0;
            restart    <= 1'b0;

            if (scan_valid) begin
                if (scan_code == 8'hE0) begin
                    extended_pending <= 1'b1;
                end else if (scan_code == 8'hF0) begin
                    break_pending <= 1'b1;
                end else begin
                    if (!break_pending && !extended_pending) begin
                        case (scan_code)
                            8'h1D: move_up    <= 1'b1; // W
                            8'h1B: move_down  <= 1'b1; // S
                            8'h1C: move_left  <= 1'b1; // A
                            8'h23: move_right <= 1'b1; // D
                            8'h5A: confirm    <= 1'b1; // Enter
                            8'h76: back       <= 1'b1; // Escape
                            8'h2D: restart    <= 1'b1; // R

                            default: ;
                        endcase
                    end
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end
            end
        end
    end
endmodule
