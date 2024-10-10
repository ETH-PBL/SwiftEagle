########################################################
#  check schematic r5 of drone mainboard
#  (c) 2024 Center for project-based learning, ETH Zürich
########################################################

########################################################
# sensors
########################################################
# imu 0
set_property PACKAGE_PIN B11 [get_ports iic_sensors_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_sensors_sda_io]
set_property PULLUP true [get_ports iic_sensors_sda_io]
set_max_delay -from [get_ports iic_sensors_sda_io] 20.000
set_min_delay -from [get_ports iic_sensors_sda_io] 0.000
set_max_delay -to [get_ports iic_sensors_sda_io] 20.000
set_min_delay -to [get_ports iic_sensors_sda_io] 0.000

set_property PACKAGE_PIN A10 [get_ports iic_sensors_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_sensors_scl_io]
set_property PULLUP true [get_ports iic_sensors_scl_io]
set_max_delay -from [get_ports iic_sensors_scl_io] 20.000
set_min_delay -from [get_ports iic_sensors_scl_io] 0.000
set_max_delay -to [get_ports iic_sensors_scl_io] 20.000
set_min_delay -to [get_ports iic_sensors_scl_io] 0.000

#IMU0 INT1
#set_property PACKAGE_PIN D11 [get_ports imu_int1] #note: currently overlaps with GPIO_0[0]!
#IMU1 INT_A 
#set_property PACKAGE_PIN E12 [get_ports imu_int1]
#IMU1 INT_G
set_property PACKAGE_PIN B10 [get_ports imu_int1] 
set_property IOSTANDARD LVCMOS33 [get_ports imu_int1]

########################################################
# i2c expander (4 mipi camera interfaces)
########################################################
set_property PACKAGE_PIN AH12 [get_ports iic_mipi_expander_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_mipi_expander_sda_io]
set_property PULLUP true [get_ports iic_mipi_expander_sda_io]
set_max_delay -from [get_ports iic_mipi_expander_sda_io] 20.000
set_min_delay -from [get_ports iic_mipi_expander_sda_io] 0.000
set_max_delay -to [get_ports iic_mipi_expander_sda_io] 20.000
set_min_delay -to [get_ports iic_mipi_expander_sda_io] 0.000

set_property PACKAGE_PIN AH11 [get_ports iic_mipi_expander_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_mipi_expander_scl_io]
set_property PULLUP true [get_ports iic_mipi_expander_scl_io]
set_max_delay -from [get_ports iic_mipi_expander_scl_io] 20.000
set_min_delay -from [get_ports iic_mipi_expander_scl_io] 0.000
set_max_delay -to [get_ports iic_mipi_expander_scl_io] 20.000
set_min_delay -to [get_ports iic_mipi_expander_scl_io] 0.000

########################################################
# frame-based camera 0
########################################################
set_property PACKAGE_PIN AC11 [get_ports {rpi_enable}]
set_property IOSTANDARD LVCMOS33 [get_ports {rpi_enable}]

########################################################
# frame-based camera 1
########################################################
set_property PACKAGE_PIN W14 [get_ports {rpi_enable1}]
set_property IOSTANDARD LVCMOS33 [get_ports {rpi_enable1}]

########################################################
# event camera 0
########################################################
set_property PACKAGE_PIN AC13 [get_ports {eventcam_enable}]
set_property IOSTANDARD LVCMOS33 [get_ports {eventcam_enable}]
set_property PACKAGE_PIN AC14 [get_ports {eventcam_exttrig}]
set_property IOSTANDARD LVCMOS33 [get_ports {eventcam_exttrig}]

########################################################
# event camera 1
########################################################
set_property PACKAGE_PIN AB13 [get_ports {eventcam1_enable}]
set_property IOSTANDARD LVCMOS33 [get_ports {eventcam1_enable}]
set_property PACKAGE_PIN AA13 [get_ports {eventcam1_exttrig}]
set_property IOSTANDARD LVCMOS33 [get_ports {eventcam1_exttrig}]

########################################################
# sbus
########################################################
set_property PACKAGE_PIN J11 [get_ports sbus]
set_property IOSTANDARD LVCMOS33 [get_ports sbus]
set_max_delay -from [get_ports sbus] 20.000
set_min_delay -from [get_ports sbus] 0.000

########################################################
# led's
########################################################
set_property PACKAGE_PIN AE12 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
set_max_delay -to [get_ports led] 20.000
set_min_delay -to [get_ports led] 0.000

########################################################
# GPIO(s)
########################################################
set_property PACKAGE_PIN D11 [get_ports {GPIO_0_tri_io[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_0_tri_io[0]}]
set_max_delay -to [get_ports {GPIO_0_tri_io[0]}] 20.000
set_min_delay -to [get_ports {GPIO_0_tri_io[0]}] 0.000


########################################################
# motors
########################################################
set_property PACKAGE_PIN F11 [get_ports {motor_signal[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {motor_signal[0]}]
set_max_delay -to [get_ports {motor_signal[0]}] 20.000
set_min_delay -to [get_ports {motor_signal[0]}] 0.000

set_property PACKAGE_PIN J12 [get_ports {motor_signal[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {motor_signal[1]}]
set_max_delay -to [get_ports {motor_signal[1]}] 20.000
set_min_delay -to [get_ports {motor_signal[1]}] 0.000

set_property PACKAGE_PIN H12 [get_ports {motor_signal[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {motor_signal[2]}]
set_max_delay -to [get_ports {motor_signal[2]}] 20.000
set_min_delay -to [get_ports {motor_signal[2]}] 0.000

set_property PACKAGE_PIN J10 [get_ports {motor_signal[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {motor_signal[3]}]
set_max_delay -to [get_ports {motor_signal[3]}] 20.000
set_min_delay -to [get_ports {motor_signal[3]}] 0.000
