// Checked by Hongsen on 2026-11-13

// Game-wide states. 
// All inputs ending in _pulse are ONE-CLOCK events.

module game_fsm (clock,resetn,
                 interact_pulse,back_pulse,
                 at_house1,at_house2,
                 at_house1_exit,at_house2_exit,
                 at_dungeon,at_enemy,
                 battle_win,battle_lose,
                 scene);
    
    input clock,resetn;

    // interact_pulse is created from buttom_pulse.v
    // back_pulse is created from input_decoder.v
    input interact_pulse,back_pulse;

    // Calculate from the player's coordiate
    input at_house1,at_house2,
          at_house1_exit,at_house2_exit,    
          at_dungeon,at_enemy;
    
    input battle_win,battle_lose;
    
    output reg [2:0] scene;

    parameter TOWN    = 3'd0;
    parameter HOUSE1  = 3'd1;
    parameter HOUSE2  = 3'd2;
    parameter DUNGEON = 3'd3;
    parameter BATTLE  = 3'd4;
    parameter VICTORY = 3'd5;
    parameter DEFEAT  = 3'd6;
    parameter START   = 3'd7;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            scene <= START;
        end else begin
            case (scene)

                START: begin
                    if(interact_pulse)
                        scene <= TOWN;
                end

                TOWN: begin
                    if (interact_pulse && at_house1)
                        scene <= HOUSE1;
                    else if (interact_pulse && at_house2)
                        scene <= HOUSE2;
                    else if (interact_pulse && at_dungeon)
                        scene <= DUNGEON;
                end

                HOUSE1: begin
                    if(back_pulse && at_house1_exit)
                        scene <= TOWN;  
                end

                HOUSE2: begin
                    if(back_pulse && at_house2_exit)
                        scene <= TOWN;
                end

                DUNGEON: begin
                    if (back_pulse) 
                        scene <= TOWN;
                    else if (interact_pulse && at_enemy) 
                        scene <= BATTLE;
                end

                BATTLE: begin
                    if (battle_lose) 
                        scene <= DEFEAT;
                    else if (battle_win) 
                        scene <= VICTORY;
                    /*else if(back_pulse) 暂停/保存
                        scene <= PAUSE; */ 
                end

                /*PAUSE: begin
                    if(back_pulse)
                        scene <= BATTLE;
                end*/

                VICTORY, DEFEAT: begin
                    if (back_pulse) 
                        scene <= TOWN;
                end

                default: scene <= START;
            endcase
        end
    end
endmodule
