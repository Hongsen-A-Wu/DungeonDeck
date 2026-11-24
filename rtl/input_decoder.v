// Checked by Hongsen on 2026-11-13

// Independent of physical PS/2 receiver and scan_code decoder

// From the official DE1-SoC PS2_Controller core.
    // Connect scan_code to received_data
    // Connect scan_valid to received_data_en

// Emits a one-clock pulse on MAKE codes only 
// Handles F0 break, E0 extended

module input_decoder (clock,resetn,scan_code,scan_valid,in_battle,
                      move_up,move_down,move_left,move_right,
                      confirm,back,restart,
                      player_selected_index,play_card_pulse,end_turn_pulse);

    input clock;
    input resetn;
    input [7:0] scan_code;
    input scan_valid;
    input in_battle; // 1 when scene == BATTLE

    // Exploration controls
    output reg move_up,move_down,move_left,move_right;
    output reg confirm,back,restart;

    // Battle controls
    output reg [1:0] player_selected_index; // 0..3 for hand slots 1..4
    output reg play_card_pulse; // Enter during battle
    output reg end_turn_pulse;  // Space during battle

    reg enter_down;
    reg escape_down;
    reg space_down;
    reg [3:0] number_down;
    reg break_pending;
    reg extended_pending;
    reg previous_battle;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            enter_down            <= 1'b0;
            escape_down           <= 1'b0;
            space_down            <= 1'b0;
            number_down           <= 4'b0000;
            break_pending         <= 1'b0;
            extended_pending      <= 1'b0;
            previous_battle       <= 1'b0;
            player_selected_index <= 2'd0;
            move_up               <= 1'b0;
            move_down             <= 1'b0;
            move_left             <= 1'b0;
            move_right            <= 1'b0;
            confirm               <= 1'b0;
            back                  <= 1'b0;
            restart               <= 1'b0;
            play_card_pulse       <= 1'b0;
            end_turn_pulse        <= 1'b0;

        end else begin
            move_up         <= 1'b0;
            move_down       <= 1'b0;
            move_left       <= 1'b0;
            move_right      <= 1'b0;
            confirm         <= 1'b0;
            back            <= 1'b0;
            restart         <= 1'b0;
            play_card_pulse <= 1'b0;
            end_turn_pulse  <= 1'b0;

            previous_battle <= in_battle;

            // Select the first hand slot on entering a new battle
            if (in_battle && !previous_battle)
                player_selected_index <= 2'd0;

            if (scan_valid) begin
                if (scan_code == 8'hE0) begin
                    extended_pending <= 1'b1;
                end else if (scan_code == 8'hF0) begin
                    break_pending <= 1'b1;
                end else begin
                    // Re-arm a key after its F0 release packet
                    if (break_pending && !extended_pending) begin
                        case (scan_code)
                            8'h5A: enter_down     <= 1'b0; // Enter
                            8'h76: escape_down    <= 1'b0; // Esc
                            8'h29: space_down     <= 1'b0; // Space
                            8'h16: number_down[0] <= 1'b0; // 1
                            8'h1E: number_down[1] <= 1'b0; // 2
                            8'h26: number_down[2] <= 1'b0; // 3
                            8'h25: number_down[3] <= 1'b0; // 4
                            default: ;
                        endcase
                    end

                    if (!break_pending && !extended_pending) begin
                        case (scan_code)
                            // WASD only moves the player outside battle
                            8'h1D: if (!in_battle) move_up    <= 1'b1; // W
                            8'h1B: if (!in_battle) move_down  <= 1'b1; // S
                            8'h1C: if (!in_battle) move_left  <= 1'b1; // A
                            8'h23: if (!in_battle) move_right <= 1'b1; // D

                            8'h5A: begin // Enter: interact or play a card
                                if (!enter_down) begin
                                    if (in_battle) play_card_pulse <= 1'b1;
                                    else confirm <= 1'b1;
                                end
                                enter_down <= 1'b1;
                            end

                            8'h76: begin // Esc: back or pause
                                if (!escape_down) back <= 1'b1;
                                escape_down <= 1'b1;
                            end

                            8'h2D: restart <= 1'b1; // R

                            8'h29: begin // Space: end the player's turn
                                if (in_battle && !space_down)
                                    end_turn_pulse <= 1'b1;
                                space_down <= 1'b1;
                            end

                            // Number keys select one of four hand slots
                            8'h16: begin // 1
                                if (in_battle && !number_down[0])
                                    player_selected_index <= 2'd0;
                                number_down[0] <= 1'b1;
                            end
                            8'h1E: begin // 2
                                if (in_battle && !number_down[1])
                                    player_selected_index <= 2'd1;
                                number_down[1] <= 1'b1;
                            end
                            8'h26: begin // 3
                                if (in_battle && !number_down[2])
                                    player_selected_index <= 2'd2;
                                number_down[2] <= 1'b1;
                            end
                            8'h25: begin // 4
                                if (in_battle && !number_down[3])
                                    player_selected_index <= 2'd3;
                                number_down[3] <= 1'b1;
                            end

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
