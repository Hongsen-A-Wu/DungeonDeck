`timescale 1ns/1ps

module tb_combat;
    reg clk=0, resetn=0, start_battle=0;
    reg play_card_pulse=0, end_turn_pulse=0;
    reg [15:0] player_hand=0, enemy_hand=0;
    reg [2:0] player_hand_count=0, enemy_hand_count=0;
    reg [1:0] player_selected_index=0;

    wire player_turn, victory, defeat;
    wire [6:0] player_hp, enemy_hp, player_block, enemy_block;
    wire [3:0] player_energy, enemy_energy;
    wire [3:0] player_selected_card_id;
    wire player_selected_card_valid, selected_card_affordable;
    wire player_card_used_pulse, enemy_card_used_pulse;
    wire [1:0] player_card_used_index, enemy_card_used_index;
    wire player_draw_pulse, enemy_draw_pulse;
    wire [2:0] player_draw_count, enemy_draw_count;
    wire player_turn_start_pulse, enemy_turn_start_pulse;

    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] PLAYER_PREP = 3'd1;
    localparam [2:0] PLAYER      = 3'd2;
    localparam [2:0] PLAYER_WAIT = 3'd3;
    localparam [2:0] ENEMY_PREP  = 3'd4;
    localparam [2:0] ENEMY       = 3'd5;
    localparam [2:0] ENEMY_WAIT  = 3'd6;
    localparam [2:0] FINISHED    = 3'd7;

    localparam [3:0] STRIKE = 4'd0;

    always #5 clk=~clk;

    combat dut (
        .clock(clk), .resetn(resetn), .start_battle(start_battle),
        .play_card_pulse(play_card_pulse), .end_turn_pulse(end_turn_pulse),
        .player_turn_start_pulse(player_turn_start_pulse),
        .enemy_turn_start_pulse(enemy_turn_start_pulse),
        .player_draw_pulse(player_draw_pulse), .enemy_draw_pulse(enemy_draw_pulse),
        .player_card_used_pulse(player_card_used_pulse),
        .enemy_card_used_pulse(enemy_card_used_pulse),
        .victory(victory), .defeat(defeat),
        .player_selected_index(player_selected_index),
        .player_hand(player_hand), .player_hand_count(player_hand_count),
        .player_hp(player_hp), .player_block(player_block),
        .player_energy(player_energy), .player_draw_count(player_draw_count),
        .player_card_used_index(player_card_used_index),
        .enemy_hand(enemy_hand), .enemy_hand_count(enemy_hand_count),
        .enemy_hp(enemy_hp), .enemy_block(enemy_block),
        .enemy_energy(enemy_energy), .enemy_draw_count(enemy_draw_count),
        .enemy_card_used_index(enemy_card_used_index),
        .player_turn(player_turn), .player_selected_card_id(player_selected_card_id),
        .player_selected_card_valid(player_selected_card_valid),
        .selected_card_affordable(selected_card_affordable)
    );

    // Read card attributes from the project's real ROM, not a mock ROM.
    reg [3:0] rom_id=0;
    wire rom_valid;
    wire [1:0] rom_type;
    wire [2:0] rom_cost, rom_draw, rom_gain;
    wire [5:0] rom_damage, rom_block, rom_heal;
    card_rom reference_rom (
        .card_id(rom_id), .card_valid(rom_valid), .card_type(rom_type),
        .energy_cost(rom_cost), .damage(rom_damage), .block(rom_block),
        .heal(rom_heal), .draw_count(rom_draw), .energy_gain(rom_gain),
        .card_name()
    );

    integer i;
    reg [3:0] defense_id=0;
    reg defense_found=0;
    integer defense_block, defense_cost;
    reg [3:0] draw_id=0, heal_id=0, gain_id=0;
    reg draw_found=0, heal_found=0, gain_found=0;

    task tick;
        begin @(posedge clk); #1; end
    endtask

    task check;
        input condition;
        input [8*96-1:0] message;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL: %0s at %0t", message, $time);
                $display("state=%d P_HP=%d E_HP=%d P_EN=%d E_EN=%d P_BLK=%d E_BLK=%d",
                         dut.state, player_hp, enemy_hp, player_energy,
                         enemy_energy, player_block, enemy_block);
                $finish;
            end
        end
    endtask

    task begin_battle;
        begin
            @(negedge clk);
            start_battle=1;
            player_hand_count=0; enemy_hand_count=0;
            player_selected_index=0;
            tick;
            check(dut.state == PLAYER_PREP && player_turn, "Start -> PLAYER_PREP");
            check(player_hp == 100 && enemy_hp == 50, "Initial HP");
            check(player_energy == 3 && enemy_energy == 0, "Initial energy");
            check(player_block == 0 && enemy_block == 0, "Initial block");
            check(player_turn_start_pulse && !victory && !defeat, "New battle pulse/result");
            @(negedge clk); start_battle=0;
            tick;
            check(dut.state == PLAYER && !player_turn_start_pulse, "PLAYER_PREP -> PLAYER");
        end
    endtask

    task play;
        begin
            @(negedge clk); play_card_pulse=1;
            tick;
            @(negedge clk); play_card_pulse=0;
        end
    endtask

    // Model deck_manage removing the used player card before the next action.
    task player_wait;
        begin
            check(dut.state == PLAYER_WAIT, "PLAYER -> PLAYER_WAIT");
            player_hand_count=0;
            tick;
            check(dut.state == PLAYER && !player_card_used_pulse &&
                  !player_draw_pulse && player_draw_count == 0, "PLAYER_WAIT -> PLAYER, pulses clear");
        end
    endtask

    task end_turn;
        begin
            @(negedge clk); end_turn_pulse=1;
            tick;
            check(dut.state == ENEMY_PREP && !player_turn, "PLAYER -> ENEMY_PREP");
            check(enemy_turn_start_pulse && enemy_energy == 3 &&
                  enemy_block == 0, "Enemy starts with restored energy and cleared block");
            @(negedge clk); end_turn_pulse=0;
            tick;
            check(dut.state == ENEMY && !enemy_turn_start_pulse, "ENEMY_PREP -> ENEMY");
        end
    endtask

    // Model deck_manage removing the used enemy card.
    task enemy_wait;
        begin
            check(dut.state == ENEMY_WAIT, "ENEMY -> ENEMY_WAIT");
            @(negedge clk); enemy_hand_count=0;
            tick;
            check(dut.state == ENEMY && !enemy_card_used_pulse &&
                  !enemy_draw_pulse && enemy_draw_count == 0, "ENEMY_WAIT -> ENEMY, pulses clear");
        end
    endtask

    task return_to_player;
        begin
            tick;
            check(dut.state == PLAYER_PREP && player_turn, "Enemy without a card -> PLAYER_PREP");
            check(player_turn_start_pulse && player_energy == 3 &&
                  player_block == 0, "Player starts with restored energy and cleared block");
            tick;
            check(dut.state == PLAYER && !player_turn_start_pulse, "New player turn");
        end
    endtask

    task strike;
        input [1:0] index;
        integer old_hp, old_block, old_energy, damage_to_hp, remaining_hp;
        begin
            // Supply STRIKE in all four slots, only slots 0..index are active.
            @(negedge clk);
            player_hand={STRIKE,STRIKE,STRIKE,STRIKE};
            player_hand_count={1'b0,index}+3'd1;
            player_selected_index=index;
            #1;
            check(player_selected_card_id == STRIKE && player_selected_card_valid &&
                  selected_card_affordable, "Valid affordable STRIKE");
            old_hp=enemy_hp; old_block=enemy_block; old_energy=player_energy;
            damage_to_hp=(old_block < 6) ? 6-old_block : 0;
            remaining_hp=(old_hp > damage_to_hp) ? old_hp-damage_to_hp : 0;
            play;
            check(player_card_used_pulse && player_card_used_index == index,
                  "Player card used pulse/index");
            check(player_energy == old_energy-1, "STRIKE costs one energy");
            check(enemy_hp == remaining_hp, "STRIKE enemy HP damage");
            check(enemy_block == ((old_block > 6) ? old_block-6 : 0), "STRIKE enemy block damage");
            check(!player_draw_pulse && player_draw_count == 0, "STRIKE does not draw");
            if (remaining_hp != 0) player_wait;
        end
    endtask

    task enemy_strike;
        integer old_hp, old_block, damage_to_hp, remaining_hp;
        begin
            @(negedge clk);
            enemy_hand={STRIKE,STRIKE,STRIKE,STRIKE};
            enemy_hand_count=1;
            old_hp=player_hp; old_block=player_block;
            damage_to_hp=(old_block < 6) ? 6-old_block : 0;
            remaining_hp=(old_hp > damage_to_hp) ? old_hp-damage_to_hp : 0;
            end_turn;
            tick;
            check(enemy_card_used_pulse && enemy_card_used_index == 0, "Enemy AI used STRIKE");
            check(enemy_energy == 2, "Enemy STRIKE costs one energy");
            check(player_hp == remaining_hp, "Enemy STRIKE player HP damage");
            check(player_block == ((old_block > 6) ? old_block-6 : 0), "Enemy STRIKE player block damage");
            check(!enemy_draw_pulse && enemy_draw_count == 0, "Enemy STRIKE does not draw");
            if (remaining_hp != 0) begin
                enemy_wait;
                return_to_player;
            end
        end
    endtask

    // Check actual effect-card attributes without guessing the card IDs.
    // Use a non-damaging card so the test cannot accidentally finish combat.
    task player_effect;
        input [3:0] id;
        integer expected_hp, expected_energy, expected_block;
        reg [2:0] expected_draw;
        begin
            @(negedge clk);
            rom_id=id; player_hand={12'd0,id};
            player_hand_count=1; player_selected_index=0;
            #1;
            check(selected_card_affordable, "Effect card affordable");
            expected_hp=player_hp+rom_heal;
            if (expected_hp > 100) expected_hp=100;
            expected_energy=player_energy;
            expected_energy=expected_energy-rom_cost+rom_gain;
            if (expected_energy > 15) expected_energy=15;
            expected_block=player_block+rom_block;
            if (expected_block > 127) expected_block=127;
            expected_draw=rom_draw;
            play;
            check(player_card_used_pulse && player_card_used_index == 0, "Effect card used");
            check(player_hp == expected_hp && player_energy == expected_energy &&
                  player_block == expected_block, "Effect card HP/energy/block");
            check(player_draw_count == expected_draw &&
                  player_draw_pulse == (expected_draw != 0), "Effect card draw count/pulse");
            player_wait;
        end
    endtask

    initial begin
        // Test reset -> IDLE
        tick;
        check(dut.state == IDLE && !player_turn && !victory && !defeat, "Reset -> IDLE");
        check(player_hp == 100 && enemy_hp == 50 && player_energy == 0 &&
              enemy_energy == 0 && player_block == 0 && enemy_block == 0, "Reset values");
        check(!player_card_used_pulse && !enemy_card_used_pulse &&
              !player_draw_pulse && !enemy_draw_pulse &&
              !player_turn_start_pulse && !enemy_turn_start_pulse, "Reset clears pulses");
        @(negedge clk); resetn=1;

        // Check the STRIKE definition used by this testbench.
        rom_id=STRIKE; #1;
        check(rom_valid && rom_type == 0 && rom_cost == 1 && rom_damage == 6 &&
              rom_block == 0 && rom_heal == 0 && rom_draw == 0 && rom_gain == 0,
              "ROM must define card 0 as STRIKE (cost 1, damage 6, no other effects)");

        // Find defense and optional effect cards from the real ROM.
        for (i=0; i<16; i=i+1) begin
            rom_id=i; #1;
            if (rom_valid && rom_cost <= 3 && rom_damage == 0) begin
                if (!defense_found && rom_type == 2 && rom_block > 0 &&
                    rom_heal == 0 && rom_draw == 0 && rom_gain == 0) begin
                    defense_found=1; defense_id=i;
                    defense_block=rom_block; defense_cost=rom_cost;
                end
                if (!draw_found && rom_draw > 0) begin draw_found=1; draw_id=i; end
                if (!heal_found && rom_heal > 0) begin heal_found=1; heal_id=i; end
                if (!gain_found && rom_gain > 0) begin gain_found=1; gain_id=i; end
            end
        end

        // Test start battle and invalid selection.
        begin_battle;
        @(negedge clk);
        player_hand={STRIKE,STRIKE,STRIKE,STRIKE};
        player_hand_count=1; player_selected_index=3;
        #1;
        check(!player_selected_card_valid && !selected_card_affordable, "Invalid hand index");
        play;
        check(dut.state == PLAYER && !player_card_used_pulse &&
              player_energy == 3 && enemy_hp == 50, "Invalid card ignored");

        // Test attack, selected index, energy consumption and WAIT.
        strike(2'd1); check(enemy_hp == 44 && player_energy == 2, "First attack");
        strike(2'd0); check(enemy_hp == 38 && player_energy == 1, "Second attack");
        strike(2'd0); check(enemy_hp == 32 && player_energy == 0, "Third attack");

        // Test insufficient energy.
        @(negedge clk); player_hand_count=1; player_selected_index=0;
        #1;
        check(player_selected_card_valid && !selected_card_affordable, "Insufficient energy");
        play;
        check(dut.state == PLAYER && !player_card_used_pulse &&
              player_energy == 0 && enemy_hp == 32, "Unaffordable card ignored");

        // Test enemy AI attack and automatic return to player.
        enemy_strike;
        check(player_hp == 94 && player_energy == 3, "Enemy attacks then player energy restores");

        // Test player block and enemy block independently.
        if (defense_found) begin
            begin_battle;
            player_effect(defense_id);
            check(player_block == defense_block && player_energy == 3-defense_cost,
                  "Player defense card adds block");
            enemy_strike;
            check(player_block == 0, "Player block clears at new turn");

            begin_battle;
            @(negedge clk); enemy_hand={12'd0,defense_id}; enemy_hand_count=1;
            end_turn;
            tick;
            check(enemy_card_used_pulse && enemy_card_used_index == 0 &&
                  enemy_block == defense_block && enemy_energy == 3-defense_cost,
                  "Enemy defense card adds block");
            enemy_wait; return_to_player;
            check(enemy_block == defense_block, "Enemy block persists during player turn");
            strike(2'd0);
            end_turn;
            check(enemy_block == 0, "Enemy block clears at new enemy turn");
            return_to_player;
        end else $display("SKIP: no affordable pure defense card found in card_rom");

        // Test effect cards if present in the current ROM.
        if (heal_found) begin
            begin_battle;
            player_effect(heal_id); // At max HP: healing must not exceed 100.
            begin_battle;
            enemy_strike;
            player_effect(heal_id); // Heal after taking damage.
        end else $display("SKIP: no affordable non-damaging heal card found");
        if (draw_found) begin
            begin_battle; player_effect(draw_id);
        end else $display("SKIP: no affordable non-damaging draw card found");
        if (gain_found) begin
            begin_battle; player_effect(gain_id);
        end else $display("SKIP: no affordable non-damaging energy gain card found");

        // Test victory: 9 STRIKE cards reduce 50 HP to zero.
        begin_battle;
        for (i=0; i<9; i=i+1) begin
            strike(2'd0);
            if (i<8) begin
                check(!victory && !defeat, "Battle continues before lethal hit");
                end_turn; return_to_player;
            end
        end
        check(enemy_hp == 0 && victory && !defeat && !player_turn &&
              dut.state == FINISHED, "Victory -> FINISHED");
        tick;
        check(victory && !player_card_used_pulse, "Victory persists, pulse clears");

        // Test starting a new battle after victory (without global reset).
        begin_battle;
        // Test defeat: 17 enemy STRIKE cards reduce 100 HP to zero.
        for (i=0; i<17; i=i+1) begin
            enemy_strike;
            if (i<16) check(!defeat && !victory, "Player survives non-lethal hit");
        end
        check(player_hp == 0 && defeat && !victory && !player_turn &&
              dut.state == FINISHED, "Defeat -> FINISHED");
        tick;
        check(defeat && !enemy_card_used_pulse, "Defeat persists, pulse clears");

        // Test reset after battle.
        @(negedge clk); resetn=0;
        tick;
        check(dut.state == IDLE && !victory && !defeat &&
              player_hp == 100 && enemy_hp == 50 && player_energy == 0 &&
              enemy_energy == 0, "Reset after defeat");

        $display("PASS tb_combat (see SKIP messages for optional tests)");
        $finish;
    end
endmodule
