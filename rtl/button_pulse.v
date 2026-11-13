// Checked by Hongsen on 2026-11-13

// Generate one 50MHz-clock pulse per debounced active-low button press

module button_pulse (clock,resetn,key_n,pulse);

    parameter DEBOUNCE_CYCLES = 500000;  // ~10 ms at 50 MHz

    input clock,resetn,key_n;
    output reg pulse;

    // Use two register to prevent metastability
    reg key_unstable, key_stable, stable;
    // log2(500000)
    reg [18:0] counter;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            key_unstable <= 1'b1;
            key_stable <= 1'b1;
            stable   <= 1'b1;
            counter  <= 32'd0;
            pulse    <= 1'b0;
        end else begin

            key_unstable <= key_n;
            key_stable <= key_unstable;
            pulse    <= 1'b0;
            // 1. No change: Keep pressing or releasing
            if (key_stable == stable) begin
                counter <= 32'd0;
            end else if (counter >= DEBOUNCE_CYCLES - 1) begin
                // 2.1 Reach stable time, change the stable value
                stable  <= key_stable;
                counter <= 32'd0;
                // 2.2 If change from 1 to 0(release to press), produce pulse
                if (!key_stable)
                    pulse <= 1'b1;
            end else begin
                // 3. Increase counter
                counter <= counter + 32'd1;
            end
        end
    end
endmodule
