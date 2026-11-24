module enemy_ai(enemy_hand,enemy_hand_count,enemy_energy,
                 selected_valid,selected_index,selected_card_id);
    input wire [15:0] enemy_hand; // Up to four 4-bit card IDs.
    input wire [2:0] enemy_hand_count; // 0..4 active hand slots.
    input wire [3:0] enemy_energy;

    output reg selected_valid;
    output reg [1:0] selected_index; // Slot 0..3.
    output reg [3:0] selected_card_id;

    localparam [1:0] ATTACK  = 2'd0;
    localparam [1:0] EFFECT  = 2'd1;
    localparam [1:0] DEFENSE = 2'd2;

    wire [4:0] slot_valid;
    wire [3:0] slot_id [0:3];
    wire [1:0] slot_type [0:3];
    wire [2:0] slot_cost [0:3];
    wire [5:0] slot_damage [0:3];

    // Generate four cards
    assign slot_id[0] = enemy_hand[3:0];
    assign slot_id[1] = enemy_hand[7:4];
    assign slot_id[2] = enemy_hand[11:8];
    assign slot_id[3] = enemy_hand[15:12];

    card_rom card_info0 (
        .card_id(slot_id[0]),
        .card_valid(slot_valid[0]),
        .card_type(slot_type[0]),
        .energy_cost(slot_cost[0]),
        .damage(slot_damage[0]),
        .block(),
        .heal(),
        .draw_count(),
        .energy_gain(),
        .card_name()
    );

    card_rom card_info1 (
        .card_id(slot_id[1]),
        .card_valid(slot_valid[1]),
        .card_type(slot_type[1]),
        .energy_cost(slot_cost[1]),
        .damage(slot_damage[1]),
        .block(),
        .heal(),
        .draw_count(),
        .energy_gain(),
        .card_name()
    );

    card_rom card_info2 (
        .card_id(slot_id[2]),
        .card_valid(slot_valid[2]),
        .card_type(slot_type[2]),
        .energy_cost(slot_cost[2]),
        .damage(slot_damage[2]),
        .block(),
        .heal(),
        .draw_count(),
        .energy_gain(),
        .card_name()
    );

    card_rom card_info3 (
        .card_id(slot_id[3]),
        .card_valid(slot_valid[3]),
        .card_type(slot_type[3]),
        .energy_cost(slot_cost[3]),
        .damage(slot_damage[3]),
        .block(),
        .heal(),
        .draw_count(),
        .energy_gain(),
        .card_name()
    );

    reg [1:0] best_priority;
    reg [5:0] best_damage;
    reg [1:0] current_priority;

    task check_card;

        input [1:0] i;
        input valid;
        input [3:0] id;
        input [1:0] card_type;
        input [2:0] cost;
        input [5:0] damage;
        input [2:0] hand_count;
        input [3:0] energy;

        begin
            if ((i < hand_count) &&
                valid &&
                ({1'b0, cost} <= energy)) begin

                case (card_type)
                    ATTACK:  current_priority = 2'd0;
                    EFFECT:  current_priority = 2'd1;
                    DEFENSE: current_priority = 2'd2;
                    default: current_priority = 2'd3;
                endcase

                if ((current_priority != 2'd3) &&
                    (!selected_valid ||
                    (current_priority < best_priority) ||
                    ((current_priority == best_priority) &&
                    (current_priority == 2'd0) &&
                    (damage > best_damage)))) begin

                    selected_valid = 1'b1;
                    selected_index = i;
                    selected_card_id = id;

                    best_priority = current_priority;
                    best_damage = damage;

                end
            end
        end
    endtask

    always @(*) begin

        // Initialize outputs
        selected_valid = 1'b0;
        selected_index = 2'd0;
        selected_card_id = 4'd0;

        // Initialize comparison variables
        best_priority = 2'd3;
        best_damage = 6'd0;
        current_priority = 2'd3;

        // Check four cards
        check_card(2'd0, slot_valid[0], slot_id[0],
                slot_type[0], slot_cost[0], slot_damage[0],
                enemy_hand_count, enemy_energy);

        check_card(2'd1, slot_valid[1], slot_id[1],
                slot_type[1], slot_cost[1], slot_damage[1],
                enemy_hand_count, enemy_energy);

        check_card(2'd2, slot_valid[2], slot_id[2],
                slot_type[2], slot_cost[2], slot_damage[2],
                enemy_hand_count, enemy_energy);

        check_card(2'd3, slot_valid[3], slot_id[3],
                slot_type[3], slot_cost[3], slot_damage[3],
                enemy_hand_count, enemy_energy);

    end
endmodule