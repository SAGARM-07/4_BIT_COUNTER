`timescale 1ns/1ps

module tb_counter_4bit;

    // -------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg        enable;
    wire [3:0] count;

    integer errors = 0;

    // -------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------
    counter_4bit dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .enable (enable),
        .count  (count)
    );

    // -------------------------------------------------------
    // Clock generation - 10ns period = 100MHz
    // -------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------
    // Task: apply reset
    // -------------------------------------------------------
    task apply_reset;
        begin
            rst_n = 0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            if (count !== 4'b0000) begin
                $display("FAIL: reset -- expected count=0, got count=%0d", count);
                errors = errors + 1;
            end else begin
                $display("PASS: reset holds count at 0");
            end
            rst_n = 1; // release reset
        end
    endtask

    // -------------------------------------------------------
    // Task: check count increments correctly for N cycles
    // -------------------------------------------------------
    task check_increment;
        input integer cycles;
        integer i;
        reg [3:0] expected;
        begin
            expected = count; // start from current count value
            for (i = 0; i < cycles; i = i + 1) begin
                expected = expected + 1; // 4-bit overflow wraps naturally
                @(posedge clk); #1;
                if (count !== expected) begin
                    $display("FAIL: increment -- expected count=%0d, got count=%0d at cycle %0d",
                              expected, count, i);
                    errors = errors + 1;
                end else begin
                    $display("PASS: count=%0d correct", count);
                end
            end
        end
    endtask

    // -------------------------------------------------------
    // Task: check count freezes when enable=0
    // -------------------------------------------------------
    task check_enable_freeze;
        input integer cycles;
        integer i;
        reg [3:0] frozen_val;
        begin
            enable     = 0;
            frozen_val = count;
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk); #1;
                if (count !== frozen_val) begin
                    $display("FAIL: enable=0 -- count changed to %0d, should stay at %0d",
                              count, frozen_val);
                    errors = errors + 1;
                end else begin
                    $display("PASS: enable=0, count frozen at %0d", count);
                end
            end
            enable = 1; // re-enable after freeze test
        end
    endtask

    // -------------------------------------------------------
    // Task: async reset mid-count
    // -------------------------------------------------------
    task check_async_reset;
        begin
            // let it count a few cycles first
            @(posedge clk); #1;
            @(posedge clk); #1;
            // assert reset mid-stream (NOT on a clock edge - async!)
            #3; // mid-cycle, 3ns after last posedge
            rst_n = 0;
            #1;
            if (count !== 4'b0000) begin
                $display("FAIL: async reset -- count should be 0 immediately, got %0d", count);
                errors = errors + 1;
            end else begin
                $display("PASS: async reset forced count to 0 immediately (no clock edge needed)");
            end
            @(posedge clk); #1;
            rst_n = 1;
        end
    endtask

    // -------------------------------------------------------
    // Task: wrap-around check (count 0->15->0)
    // -------------------------------------------------------
    task check_wraparound;
        integer i;
        reg [3:0] expected;
        begin
            // reset first to get to a known state
            rst_n    = 0;
            @(posedge clk); #1;
            rst_n    = 1;
            enable   = 1;
            expected = 0;
            // count all 16 values and check wrap
            for (i = 0; i < 17; i = i + 1) begin
                @(posedge clk); #1;
                expected = expected + 1;
                if (count !== expected[3:0]) begin
                    $display("FAIL: wraparound at i=%0d -- expected %0d got %0d",
                              i, expected[3:0], count);
                    errors = errors + 1;
                end else begin
                    $display("PASS: wraparound check count=%0d", count);
                end
            end
        end
    endtask

    // -------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------
    initial begin
        $dumpfile("counter_tb.vcd");
        $dumpvars(0, tb_counter_4bit);

        // initialise
        rst_n  = 0;
        enable = 0;
        clk    = 0;

        repeat(3) @(posedge clk);

        $display("\n--- Test 1: Reset ---");
        apply_reset;

        $display("\n--- Test 2: Count up 8 cycles ---");
        enable = 1;
        check_increment(8);

        $display("\n--- Test 3: Enable freeze ---");
        check_enable_freeze(3);

        $display("\n--- Test 4: Async reset mid-count ---");
        check_async_reset;

        $display("\n--- Test 5: Full wrap-around (0 to 15 to 0) ---");
        check_wraparound;

        // ---- Summary ----
        $display("\n=========================================");
        $display(" ERRORS : %0d", errors);
        if (errors == 0)
            $display(" RESULT : ALL TESTS PASSED");
        else
            $display(" RESULT : FAILED");
        $display("=========================================\n");

        #50;
        $finish;
    end

endmodule		
