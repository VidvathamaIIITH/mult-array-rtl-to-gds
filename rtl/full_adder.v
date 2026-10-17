// full_adder.v
// 1-bit full adder written with continuous assignments.
//   sum  = a XOR b XOR cin
//   cout = majority(a, b, cin)

module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);

endmodule
