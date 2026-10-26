// testbench for mult_array

`timescale 1ns/1ps

module tb_mult;

    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;

    integer i, j;
    integer errors;
    integer checked;
    reg [7:0] expected;

    mult_array dut (
        .clk  (clk),
        .rst_n(rst_n),
        .a    (a),
        .b    (b),
        .p    (p)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;   // 10 ns period

    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
    end

    initial begin
        $timeformat(-9, 0, " ns", 0);
        errors  = 0;
        checked = 0;
        a       = 4'd0;
        b       = 4'd0;

        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                // inputs change on the falling edge
                a = i[3:0];
                b = j[3:0];
                expected = i * j;

                // edge 1 loads a/b, edge 2 loads p
                repeat (2) @(posedge clk);
                @(negedge clk);

                checked = checked + 1;
                if (p !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH at %0t: a=%0d b=%0d p=%0d expected=%0d",
                             $time, a, b, p, expected);
                end
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, %0d errors", checked, errors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", checked, errors);

        $finish;
    end

    initial begin
        #100000;
        $display("FAIL: timeout after %0d vectors checked, %0d errors", checked, errors);
        $finish;
    end

endmodule
