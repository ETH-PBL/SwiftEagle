## Toolchain

- Ubuntu 22.04.2 LTS
- Vivado/Vitis v2023.2 (no SDT flow)
- custom drone hardware rev.5

## Compile design and export hardware files

1. go to the folder `top`, open Vivado project using `vivado -source drone_hw_rev5.tcl &`
2. run the synthesis and implementation steps
3. generate bitstream
4. export hardware including bitstream using `File > Export > Export hardware...`
5. use exported .xsa for generating the board support package for the R5 firmware

