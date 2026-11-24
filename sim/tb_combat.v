`timescale 1ns/1ps
// Test with the REAL rtl/card_rom.v and rtl/enemy_ai.v.
// Minimal hand-count mock stands in for deck_manager.
// Assumes card ID 0 = STRIKE, cost 1, damage 6 (current card_rom).
module tb_combat;
    reg clock, resetn, start_battle;
    reg play_card_pulse, end_turn_pulse;
    reg [1:0] player_selected_index;
    reg enable_enemy;
    wire [15:0] player_hand = 16'h0000; // Four STRIKE cards
    wire [15:0] enemy_hand  = 16'h0000;
    reg [2:0] player_hand_count, enemy_hand_count;

    wire [6:0] player_hp, enemy_hp, player_block, enemy_block;
    wire [3:0] energy, enemy_energy;
    wire player_turn, victory, defeat;
    wire [3:0] selected_card_id;
    wire selected_card_valid, selected_card_affordable;
    wire player_card_used_pulse, enemy_card_used_pulse;
    wire [1:0] player_card_used_index, enemy_card_used_index;
    wire player_draw_pulse, enemy_draw_pulse;
    wire [2:0] player_draw_count, enemy_draw_count;
    wire player_turn_start_pulse, enemy_turn_start_pulse;

    combat dut (
        .clock(clock), .resetn(resetn), .start_battle(start_battle),
        .player_hand(player_hand), .player_hand_count(player_hand_count),
        .enemy_hand(enemy_hand), .enemy_hand_count(enemy_hand_count),
        .player_selected_index(player_selected_index),
        .play_card_pulse(play_card_pulse), .end_turn_pulse(end_turn_pulse),
        .player_hp(player_hp), .enemy_hp(enemy_hp),
        .player_block(player_block), .enemy_block(enemy_block),
        .energy(energy), .enemy_energy(enemy_energy),
        .player_turn(player_turn), .victory(victory), .defeat(defeat),
        .selected_card_id(selected_card_id),
        .selected_card_valid(selected_card_valid),
        .selected_card_affordable(selected_card_affordable),
        .player_card_used_pulse(player_card_used_pulse),
        .player_card_used_index(player_card_used_index),
        .enemy_card_used_pulse(enemy_card_used_pulse),
        .enemy_card_used_index(enemy_card_used_index),
        .player_draw_pulse(player_draw_pulse),
        .player_draw_count(player_draw_count),
        .enemy_draw_pulse(enemy_draw_pulse),
        .enemy_draw_count(enemy_draw_count),
        .player_turn_start_pulse(player_turn_start_pulse),
        .enemy_turn_start_pulse(enemy_turn_start_pulse)
    );

    initial clock = 0;
    always #10 clock = ~clock;

    // Emulate a deck_manager preparing 4 cards at turn start
    // and removing 1 card on every accepted play.
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            player_hand_count <= 3'd0;
            enemy_hand_count <= 3'd0;
        end else begin
            if (player_turn_start_pulse)
                player_hand_count <= 3'd4;
            else if (player_card_used_pulse && player_hand_count != 0)
                player_hand_count <= player_hand_count - 3'd1;

            if (enemy_turn_start_pulse)
                enemy_hand_count <= enable_enemy ? 3'd4 : 3'd0;
            else if (enemy_card_used_pulse && enemy_hand_count != 0)
                enemy_hand_count <= enemy_hand_count - 3'd1;
        end
    end

    task begin_battle;
    begin
        @(negedge clock); start_battle = 1;
        @(negedge clock); start_battle = 0;
        repeat (3) @(negedge clock);
    end
    endtask

    task play_strike;
    begin
        @(negedge clock); play_card_pulse = 1;
        @(negedge clock); play_card_pulse = 0;
        repeat (2) @(negedge clock);
    end
    endtask

    task finish_player_turn;
    begin
        @(negedge clock); end_turn_pulse = 1;
        @(negedge clock); end_turn_pulse = 0;
        wait (player_turn || victory || defeat);
        repeat (2) @(negedge clock);
    end
    endtask

    task check;
        input condition;
        input [255:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                $finish;
            end
        end
    endtask

    integer turn_num;
    initial begin
        resetn = 0;
        start_battle = 0;
        play_card_pulse = 0;
        end_turn_pulse = 0;
        player_selected_index = 0;
        enable_enemy = 0;
        repeat (3) @(negedge clock);
        resetn = 1;

        // Test 1: three strikes, exhausted energy, next turn, victory.
        begin_battle();
        check(player_hp == 80 && enemy_hp == 30 && energy == 3,
              "battle initialization");
        play_strike();
        check(enemy_hp == 24 && energy == 2, "first STRIKE");
        play_strike();
        play_strike();
        check(enemy_hp == 12 && energy == 0, "three STRIKEs");
        play_strike();
        check(enemy_hp == 12, "zero energy must reject card");
        finish_player_turn();
        check(energy == 3 && player_turn, "new player turn energy");
        play_strike();
        play_strike();
        check(victory && enemy_hp == 0, "victory after fifth STRIKE");

        // Test 2: start new battle after victory, then let enemy attack.
        enable_enemy = 1;
        @(negedge clock); start_battle = 1;
        #1 check(!victory && !defeat, "old result masked on new battle");
        @(negedge clock); start_battle = 0;
        repeat (3) @(negedge clock);
        check(player_hp == 80 && enemy_hp == 30 && !victory,
              "new battle clears result and HP");
        for (turn_num = 0; turn_num < 5; turn_num = turn_num + 1) begin
            if (!defeat) finish_player_turn();
        end
        check(defeat && player_hp == 0, "enemy eventually defeats player");
        $display("PASS: tb_combat (win, defeat, energy, re-entry)");
        $finish;
    end
endmodule
