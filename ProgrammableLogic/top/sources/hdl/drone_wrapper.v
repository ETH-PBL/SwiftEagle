//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2023.2 (lin64) Build 4029153 Fri Oct 13 20:13:54 MDT 2023
//Date        : Fri Jun 21 08:50:36 2024
//Host        : michael-System-Product-Name running 64-bit Ubuntu 22.04.4 LTS
//Command     : generate_target drone_wrapper.bd
//Design      : drone_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module drone_wrapper
   (GPIO_0_tri_io,
    eventcam1_enable,
    eventcam1_exttrig,
    eventcam_enable,
    eventcam_exttrig,
    fan_en_b,
    iic_mipi_expander_scl_io,
    iic_mipi_expander_sda_io,
    iic_sensors_scl_io,
    iic_sensors_sda_io,
    imu_int1,
    led,
    mipi_phy_if_0_clk_n,
    mipi_phy_if_0_clk_p,
    mipi_phy_if_0_data_n,
    mipi_phy_if_0_data_p,
    mipi_phy_if_1_clk_n,
    mipi_phy_if_1_clk_p,
    mipi_phy_if_1_data_n,
    mipi_phy_if_1_data_p,
    mipi_phy_if_2_clk_n,
    mipi_phy_if_2_clk_p,
    mipi_phy_if_2_data_n,
    mipi_phy_if_2_data_p,
    mipi_phy_if_3_clk_n,
    mipi_phy_if_3_clk_p,
    mipi_phy_if_3_data_n,
    mipi_phy_if_3_data_p,
    motor_signal,
    rpi_enable,
    rpi_enable1,
    sbus);
  inout [0:0]GPIO_0_tri_io;
  output [0:0]eventcam1_enable;
  output [0:0]eventcam1_exttrig;
  output [0:0]eventcam_enable;
  output eventcam_exttrig;
  output [0:0]fan_en_b;
  inout iic_mipi_expander_scl_io;
  inout iic_mipi_expander_sda_io;
  inout iic_sensors_scl_io;
  inout iic_sensors_sda_io;
  input imu_int1;
  output led;
  input mipi_phy_if_0_clk_n;
  input mipi_phy_if_0_clk_p;
  input [1:0]mipi_phy_if_0_data_n;
  input [1:0]mipi_phy_if_0_data_p;
  input mipi_phy_if_1_clk_n;
  input mipi_phy_if_1_clk_p;
  input [0:0]mipi_phy_if_1_data_n;
  input [0:0]mipi_phy_if_1_data_p;
  input mipi_phy_if_2_clk_n;
  input mipi_phy_if_2_clk_p;
  input [0:0]mipi_phy_if_2_data_n;
  input [0:0]mipi_phy_if_2_data_p;
  input mipi_phy_if_3_clk_n;
  input mipi_phy_if_3_clk_p;
  input [1:0]mipi_phy_if_3_data_n;
  input [1:0]mipi_phy_if_3_data_p;
  output [3:0]motor_signal;
  output [0:0]rpi_enable;
  output [0:0]rpi_enable1;
  input sbus;

  wire [0:0]GPIO_0_tri_i_0;
  wire [0:0]GPIO_0_tri_io_0;
  wire [0:0]GPIO_0_tri_o_0;
  wire [0:0]GPIO_0_tri_t_0;
  wire [0:0]eventcam1_enable;
  wire [0:0]eventcam1_exttrig;
  wire [0:0]eventcam_enable;
  wire eventcam_exttrig;
  wire [0:0]fan_en_b;
  wire iic_mipi_expander_scl_i;
  wire iic_mipi_expander_scl_io;
  wire iic_mipi_expander_scl_o;
  wire iic_mipi_expander_scl_t;
  wire iic_mipi_expander_sda_i;
  wire iic_mipi_expander_sda_io;
  wire iic_mipi_expander_sda_o;
  wire iic_mipi_expander_sda_t;
  wire iic_sensors_scl_i;
  wire iic_sensors_scl_io;
  wire iic_sensors_scl_o;
  wire iic_sensors_scl_t;
  wire iic_sensors_sda_i;
  wire iic_sensors_sda_io;
  wire iic_sensors_sda_o;
  wire iic_sensors_sda_t;
  wire imu_int1;
  wire led;
  wire mipi_phy_if_0_clk_n;
  wire mipi_phy_if_0_clk_p;
  wire [1:0]mipi_phy_if_0_data_n;
  wire [1:0]mipi_phy_if_0_data_p;
  wire mipi_phy_if_1_clk_n;
  wire mipi_phy_if_1_clk_p;
  wire [0:0]mipi_phy_if_1_data_n;
  wire [0:0]mipi_phy_if_1_data_p;
  wire mipi_phy_if_2_clk_n;
  wire mipi_phy_if_2_clk_p;
  wire [0:0]mipi_phy_if_2_data_n;
  wire [0:0]mipi_phy_if_2_data_p;
  wire mipi_phy_if_3_clk_n;
  wire mipi_phy_if_3_clk_p;
  wire [1:0]mipi_phy_if_3_data_n;
  wire [1:0]mipi_phy_if_3_data_p;
  wire [3:0]motor_signal;
  wire [0:0]rpi_enable;
  wire [0:0]rpi_enable1;
  wire sbus;

  IOBUF GPIO_0_tri_iobuf_0
       (.I(GPIO_0_tri_o_0),
        .IO(GPIO_0_tri_io[0]),
        .O(GPIO_0_tri_i_0),
        .T(GPIO_0_tri_t_0));
  drone drone_i
       (.GPIO_0_tri_i(GPIO_0_tri_i_0),
        .GPIO_0_tri_o(GPIO_0_tri_o_0),
        .GPIO_0_tri_t(GPIO_0_tri_t_0),
        .eventcam1_enable(eventcam1_enable),
        .eventcam1_exttrig(eventcam1_exttrig),
        .eventcam_enable(eventcam_enable),
        .eventcam_exttrig(eventcam_exttrig),
        .fan_en_b(fan_en_b),
        .iic_mipi_expander_scl_i(iic_mipi_expander_scl_i),
        .iic_mipi_expander_scl_o(iic_mipi_expander_scl_o),
        .iic_mipi_expander_scl_t(iic_mipi_expander_scl_t),
        .iic_mipi_expander_sda_i(iic_mipi_expander_sda_i),
        .iic_mipi_expander_sda_o(iic_mipi_expander_sda_o),
        .iic_mipi_expander_sda_t(iic_mipi_expander_sda_t),
        .iic_sensors_scl_i(iic_sensors_scl_i),
        .iic_sensors_scl_o(iic_sensors_scl_o),
        .iic_sensors_scl_t(iic_sensors_scl_t),
        .iic_sensors_sda_i(iic_sensors_sda_i),
        .iic_sensors_sda_o(iic_sensors_sda_o),
        .iic_sensors_sda_t(iic_sensors_sda_t),
        .imu_int1(imu_int1),
        .led(led),
        .mipi_phy_if_0_clk_n(mipi_phy_if_0_clk_n),
        .mipi_phy_if_0_clk_p(mipi_phy_if_0_clk_p),
        .mipi_phy_if_0_data_n(mipi_phy_if_0_data_n),
        .mipi_phy_if_0_data_p(mipi_phy_if_0_data_p),
        .mipi_phy_if_1_clk_n(mipi_phy_if_1_clk_n),
        .mipi_phy_if_1_clk_p(mipi_phy_if_1_clk_p),
        .mipi_phy_if_1_data_n(mipi_phy_if_1_data_n),
        .mipi_phy_if_1_data_p(mipi_phy_if_1_data_p),
        .mipi_phy_if_2_clk_n(mipi_phy_if_2_clk_n),
        .mipi_phy_if_2_clk_p(mipi_phy_if_2_clk_p),
        .mipi_phy_if_2_data_n(mipi_phy_if_2_data_n),
        .mipi_phy_if_2_data_p(mipi_phy_if_2_data_p),
        .mipi_phy_if_3_clk_n(mipi_phy_if_3_clk_n),
        .mipi_phy_if_3_clk_p(mipi_phy_if_3_clk_p),
        .mipi_phy_if_3_data_n(mipi_phy_if_3_data_n),
        .mipi_phy_if_3_data_p(mipi_phy_if_3_data_p),
        .motor_signal(motor_signal),
        .rpi_enable(rpi_enable),
        .rpi_enable1(rpi_enable1),
        .sbus(sbus));
  IOBUF iic_mipi_expander_scl_iobuf
       (.I(iic_mipi_expander_scl_o),
        .IO(iic_mipi_expander_scl_io),
        .O(iic_mipi_expander_scl_i),
        .T(iic_mipi_expander_scl_t));
  IOBUF iic_mipi_expander_sda_iobuf
       (.I(iic_mipi_expander_sda_o),
        .IO(iic_mipi_expander_sda_io),
        .O(iic_mipi_expander_sda_i),
        .T(iic_mipi_expander_sda_t));
  IOBUF iic_sensors_scl_iobuf
       (.I(iic_sensors_scl_o),
        .IO(iic_sensors_scl_io),
        .O(iic_sensors_scl_i),
        .T(iic_sensors_scl_t));
  IOBUF iic_sensors_sda_iobuf
       (.I(iic_sensors_sda_o),
        .IO(iic_sensors_sda_io),
        .O(iic_sensors_sda_i),
        .T(iic_sensors_sda_t));
endmodule
