// 负责随机抽卡、手牌管理、弃牌和重新洗牌，分别为玩家和怪物抽牌
// Zicheng
module deck_manager (
	 input  wire clock,
    input  wire resetn,
    input  wire start_battle,
	 
    input  wire player_card_used_pulse,
    input  wire [1:0]  player_card_used_index,
    input  wire enemy_card_used_pulse,
    input  wire [1:0]  enemy_card_used_index,

    input  wire player_draw_pulse,
    input  wire [2:0]  player_draw_count,
    input  wire enemy_draw_pulse,
    input  wire [2:0]  enemy_draw_count,

    input  wire player_turn_start_pulse,
    input  wire enemy_turn_start_pulse,

    output wire [15:0] player_hand,
    output wire [2:0]  player_hand_count,
    output wire [15:0] enemy_hand,
    output wire [2:0]  enemy_hand_count
);
    deck_manager_side #(.RNG_SEED(16'hBEEF)) player_deck (
        .clock(clock),
        .resetn(resetn),
        .start_battle(start_battle),
        .turn_start_pulse(player_turn_start_pulse),
        .card_used_pulse(player_card_used_pulse),
        .card_used_index(player_card_used_index),
        .draw_pulse(player_draw_pulse),
        .draw_count(player_draw_count),
        .hand(player_hand),
        .hand_count(player_hand_count)
    );

    deck_manager_side #(.RNG_SEED(16'hACE1)) enemy_deck (
        .clock(clock),
        .resetn(resetn),
        .start_battle(start_battle),
        .turn_start_pulse(enemy_turn_start_pulse),
        .card_used_pulse(enemy_card_used_pulse),
        .card_used_index(enemy_card_used_index),
        .draw_pulse(enemy_draw_pulse),
        .draw_count(enemy_draw_count),
        .hand(enemy_hand),
        .hand_count(enemy_hand_count)
    );

endmodule

// draw card, discard card and hand card.
module deck_manager_side #(parameter [15:0] RNG_SEED= 16'hBEEF, parameter [39:0] START_DECK = 40'h9876543210) // use 4 as cardID 10 card have 40
(
    input  wire clock,
    input  wire resetn,
    input  wire start_battle, 
    input  wire turn_start_pulse, // start to action after draw cards to 4
    input  wire card_used_pulse,
    input  wire [1:0]  card_used_index, // 0 or 1 or 2 or 3
    input  wire draw_pulse, // extra draw card
    input  wire [2:0]  draw_count, 

    output reg  [15:0] hand,
    output reg  [2:0]  hand_count
);
    reg [39:0] draw_pile, discard_pile; 
    reg [3:0]  draw_left, discard_total; // cards left in draw pile ; cards left in discard pile

    reg [39:0] next_draw_pile, next_discard_pile;
    reg [3:0]  next_draw_left, next_discard_total;
    reg [15:0] next_hand;
    reg [2:0]  next_hand_count;

    wire [15:0] random_value;

    lfsr_fib_16 #(.INITIAL_SEED(RNG_SEED)) rng (.reset(~resetn),.clk(clock), .seed(random_value));
    integer i;
    reg [2:0] cards_to_draw; //这次准备抽几张。回合开始时=空槽，卡牌有效果=draw_count
    reg [3:0] pick; // 随机选中的抽牌堆号
    reg [3:0] last;
    reg [7:0] sample;
    reg [11:0] product;
    reg [15:0] random_bits;
	 
    always @(*) begin
        next_draw_pile     = draw_pile;
        next_discard_pile  = discard_pile;
        next_draw_left     = draw_left;
        next_discard_total = discard_total;
        next_hand          = hand;
        next_hand_count    = hand_count;    // use next to count the current number and it could even decide positon for new card!

        cards_to_draw = 3'd0;
        pick          = 4'd0;
        last          = 4'd0;
        sample        = 8'd0;
        product       = 12'd0;
        random_bits   = random_value;

        // Remove the card and put it in the discard pile.
        if (card_used_pulse && card_used_index < hand_count) begin    // check 2 condition：确实打出了牌，而且所选的槽里有牌
            next_discard_pile[discard_total * 4 +: 4] = hand[card_used_index * 4 +: 4]; // put used in discard pile
            next_discard_total = discard_total + 4'd1;

            // close the gap so valid slots always start at 0.
            for (i = 0; i < 3; i = i + 1) begin
                if (i >= card_used_index && i + 1 < hand_count)
                    next_hand[i * 4 +: 4] = hand[(i + 1) * 4 +: 4]; //把旧手牌的槽 i+1，复制到新手牌 next_hand 的槽 i
            end
            next_hand_count = hand_count - 3'd1;
            next_hand[next_hand_count * 4 +: 4] = 4'd0;  // 给空槽清零
        end

        // At turn start, fill the hand. Otherwise use the card effect.
        if (turn_start_pulse)
            cards_to_draw = 3'd4 - next_hand_count; // draw cards
        else if (draw_pulse) // 有抽牌请求
            cards_to_draw = draw_count; 
				
        // A hand has four slots, so four iterations cover every request.
        for (i = 0; i < 4; i = i + 1) begin
            if (i < cards_to_draw && next_hand_count < 3'd4) begin
                if (next_draw_left == 4'd0) begin // 抽牌堆空了，就回收弃牌堆
                    next_draw_pile     = next_discard_pile;
                    next_draw_left     = next_discard_total;
                    next_discard_total = 4'd0;
                end
                if (next_draw_left != 4'd0) begin
                    // pick = floor(sample * next_draw_left / 256)
                    // This gives a slot from 0 through next_draw_left - 1.
                    sample  = random_bits[7:0]; // 随机数 （0-255）
                    product = sample * next_draw_left; //把随机数按当前牌数放大
                    pick= product[11:8]; //去掉低 8 位（除以256）
                    last= next_draw_left - 4'd1; //最后一张有效牌
                    next_hand[next_hand_count * 4 +: 4] = next_draw_pile[pick * 4 +: 4]; // for ex pick=2 从抽牌堆的2号取出卡牌 ID， next hand count=1 写入手牌的1号
                    // Move the last available card into the selected slot.
                    next_draw_pile[pick * 4 +: 4] = next_draw_pile[last * 4 +: 4]; // +:意思从起始位开始，向高位连续取4位，（每个卡4位） rotate last to 空出来的
                    next_draw_left  = last; // 正好有效是0-last
                    next_hand_count = next_hand_count + 3'd1;
                    random_bits = {random_bits[3:0], random_bits[15:4]};// Use a different group of bits for the next card.
                end
            end
        end
    end
always @(posedge clock or negedge resetn) begin
        if(!resetn) begin
            draw_pile     <= 40'd0;
            discard_pile  <= 40'd0;
            draw_left     <= 4'd0;
            discard_total <= 4'd0;
            hand          <= 16'd0;
            hand_count    <= 3'd0;
        end 
		  else if (start_battle) begin
            draw_pile     <= START_DECK;
            discard_pile  <= 40'd0;
            draw_left     <= 4'd10;
            discard_total <= 4'd0;
            hand          <= 16'd0;
            hand_count    <= 3'd0;
        end 
		  else begin
            draw_pile     <= next_draw_pile;
            discard_pile  <= next_discard_pile;
            draw_left     <= next_draw_left;
            discard_total <= next_discard_total;
            hand          <= next_hand;
            hand_count    <= next_hand_count;
        end
    end
endmodule

