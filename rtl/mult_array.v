// 4x4 unsigned array multiplier with registered inputs and output (latency 2)

module mult_array (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] a,
    input  wire [3:0] b,
    output reg  [7:0] p
);

    reg [3:0] a_r, b_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= 4'd0;
            b_r <= 4'd0;
        end else begin
            a_r <= a;
            b_r <= b;
        end
    end

    // partial products: pp_i[j] = a[j] & b[i]
    wire [3:0] pp0 = a_r & {4{b_r[0]}};
    wire [3:0] pp1 = a_r & {4{b_r[1]}};
    wire [3:0] pp2 = a_r & {4{b_r[2]}};
    wire [3:0] pp3 = a_r & {4{b_r[3]}};

    // row 0: no adders, pass upper 3 bits down
    wire [3:0] r0 = {1'b0, pp0[3], pp0[2], pp0[1]};

    // row 1: s1 = pp1 + r0
    wire [3:0] s1;
    wire [4:0] c1;
    assign c1[0] = 1'b0;

    full_adder fa_r1_0 (.a(pp1[0]), .b(r0[0]), .cin(c1[0]), .sum(s1[0]), .cout(c1[1]));
    full_adder fa_r1_1 (.a(pp1[1]), .b(r0[1]), .cin(c1[1]), .sum(s1[1]), .cout(c1[2]));
    full_adder fa_r1_2 (.a(pp1[2]), .b(r0[2]), .cin(c1[2]), .sum(s1[2]), .cout(c1[3]));
    full_adder fa_r1_3 (.a(pp1[3]), .b(r0[3]), .cin(c1[3]), .sum(s1[3]), .cout(c1[4]));

    wire [3:0] r1 = {c1[4], s1[3], s1[2], s1[1]};

    // row 2: s2 = pp2 + r1
    wire [3:0] s2;
    wire [4:0] c2;
    assign c2[0] = 1'b0;

    full_adder fa_r2_0 (.a(pp2[0]), .b(r1[0]), .cin(c2[0]), .sum(s2[0]), .cout(c2[1]));
    full_adder fa_r2_1 (.a(pp2[1]), .b(r1[1]), .cin(c2[1]), .sum(s2[1]), .cout(c2[2]));
    full_adder fa_r2_2 (.a(pp2[2]), .b(r1[2]), .cin(c2[2]), .sum(s2[2]), .cout(c2[3]));
    full_adder fa_r2_3 (.a(pp2[3]), .b(r1[3]), .cin(c2[3]), .sum(s2[3]), .cout(c2[4]));

    wire [3:0] r2 = {c2[4], s2[3], s2[2], s2[1]};

    // row 3: s3 = pp3 + r2
    wire [3:0] s3;
    wire [4:0] c3;
    assign c3[0] = 1'b0;

    full_adder fa_r3_0 (.a(pp3[0]), .b(r2[0]), .cin(c3[0]), .sum(s3[0]), .cout(c3[1]));
    full_adder fa_r3_1 (.a(pp3[1]), .b(r2[1]), .cin(c3[1]), .sum(s3[1]), .cout(c3[2]));
    full_adder fa_r3_2 (.a(pp3[2]), .b(r2[2]), .cin(c3[2]), .sum(s3[2]), .cout(c3[3]));
    full_adder fa_r3_3 (.a(pp3[3]), .b(r2[3]), .cin(c3[3]), .sum(s3[3]), .cout(c3[4]));

    wire [7:0] p_comb = {c3[4], s3[3], s3[2], s3[1], s3[0], s2[0], s1[0], pp0[0]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            p <= 8'd0;
        else
            p <= p_comb;
    end

endmodule
