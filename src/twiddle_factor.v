`timescale 1ns / 1ps

module twiddle_factor (
    input  wire [7:0] addr,
    output wire signed [31:0] d_out
);

    (* rom_style = "distributed", ramstyle = "logic" *)
    reg signed [15:0] rom [0:127];

    wire signed [15:0] zeta16;

    assign zeta16 = rom[addr[6:0]];

    // Sign extend 16-bit Kyber zeta to 32-bit
    assign d_out = {{16{zeta16[15]}}, zeta16};

    initial begin
        rom[0]   = -16'sd1044;
        rom[1]   = -16'sd758;
        rom[2]   = -16'sd359;
        rom[3]   = -16'sd1517;
        rom[4]   =  16'sd1493;
        rom[5]   =  16'sd1422;
        rom[6]   =  16'sd287;
        rom[7]   =  16'sd202;
        rom[8]   = -16'sd171;
        rom[9]   =  16'sd622;
        rom[10]  =  16'sd1577;
        rom[11]  =  16'sd182;
        rom[12]  =  16'sd962;
        rom[13]  = -16'sd1202;
        rom[14]  = -16'sd1474;
        rom[15]  =  16'sd1468;

        rom[16]  =  16'sd573;
        rom[17]  = -16'sd1325;
        rom[18]  =  16'sd264;
        rom[19]  =  16'sd383;
        rom[20]  = -16'sd829;
        rom[21]  =  16'sd1458;
        rom[22]  = -16'sd1602;
        rom[23]  = -16'sd130;
        rom[24]  = -16'sd681;
        rom[25]  =  16'sd1017;
        rom[26]  =  16'sd732;
        rom[27]  =  16'sd608;
        rom[28]  = -16'sd1542;
        rom[29]  =  16'sd411;
        rom[30]  = -16'sd205;
        rom[31]  = -16'sd1571;

        rom[32]  =  16'sd1223;
        rom[33]  =  16'sd652;
        rom[34]  = -16'sd552;
        rom[35]  =  16'sd1015;
        rom[36]  = -16'sd1293;
        rom[37]  =  16'sd1491;
        rom[38]  = -16'sd282;
        rom[39]  = -16'sd1544;
        rom[40]  =  16'sd516;
        rom[41]  = -16'sd8;
        rom[42]  = -16'sd320;
        rom[43]  = -16'sd666;
        rom[44]  = -16'sd1618;
        rom[45]  = -16'sd1162;
        rom[46]  =  16'sd126;
        rom[47]  =  16'sd1469;

        rom[48]  = -16'sd853;
        rom[49]  = -16'sd90;
        rom[50]  = -16'sd271;
        rom[51]  =  16'sd830;
        rom[52]  =  16'sd107;
        rom[53]  = -16'sd1421;
        rom[54]  = -16'sd247;
        rom[55]  = -16'sd951;
        rom[56]  = -16'sd398;
        rom[57]  =  16'sd961;
        rom[58]  = -16'sd1508;
        rom[59]  = -16'sd725;
        rom[60]  =  16'sd448;
        rom[61]  = -16'sd1065;
        rom[62]  =  16'sd677;
        rom[63]  = -16'sd1275;

        rom[64]  = -16'sd1103;
        rom[65]  =  16'sd430;
        rom[66]  =  16'sd555;
        rom[67]  =  16'sd843;
        rom[68]  = -16'sd1251;
        rom[69]  =  16'sd871;
        rom[70]  =  16'sd1550;
        rom[71]  =  16'sd105;
        rom[72]  =  16'sd422;
        rom[73]  =  16'sd587;
        rom[74]  =  16'sd177;
        rom[75]  = -16'sd235;
        rom[76]  = -16'sd291;
        rom[77]  = -16'sd460;
        rom[78]  =  16'sd1574;
        rom[79]  =  16'sd1653;

        rom[80]  = -16'sd246;
        rom[81]  =  16'sd778;
        rom[82]  =  16'sd1159;
        rom[83]  = -16'sd147;
        rom[84]  = -16'sd777;
        rom[85]  =  16'sd1483;
        rom[86]  = -16'sd602;
        rom[87]  =  16'sd1119;
        rom[88]  = -16'sd1590;
        rom[89]  =  16'sd644;
        rom[90]  = -16'sd872;
        rom[91]  =  16'sd349;
        rom[92]  =  16'sd418;
        rom[93]  =  16'sd329;
        rom[94]  = -16'sd156;
        rom[95]  = -16'sd75;

        rom[96]  =  16'sd817;
        rom[97]  =  16'sd1097;
        rom[98]  =  16'sd603;
        rom[99]  =  16'sd610;
        rom[100] =  16'sd1322;
        rom[101] = -16'sd1285;
        rom[102] = -16'sd1465;
        rom[103] =  16'sd384;
        rom[104] = -16'sd1215;
        rom[105] = -16'sd136;
        rom[106] =  16'sd1218;
        rom[107] = -16'sd1335;
        rom[108] = -16'sd874;
        rom[109] =  16'sd220;
        rom[110] = -16'sd1187;
        rom[111] = -16'sd1659;

        rom[112] = -16'sd1185;
        rom[113] = -16'sd1530;
        rom[114] = -16'sd1278;
        rom[115] =  16'sd794;
        rom[116] = -16'sd1510;
        rom[117] = -16'sd854;
        rom[118] = -16'sd870;
        rom[119] =  16'sd478;
        rom[120] = -16'sd108;
        rom[121] = -16'sd308;
        rom[122] =  16'sd996;
        rom[123] =  16'sd991;
        rom[124] =  16'sd958;
        rom[125] = -16'sd1460;
        rom[126] =  16'sd1522;
        rom[127] =  16'sd1628;
    end

endmodule