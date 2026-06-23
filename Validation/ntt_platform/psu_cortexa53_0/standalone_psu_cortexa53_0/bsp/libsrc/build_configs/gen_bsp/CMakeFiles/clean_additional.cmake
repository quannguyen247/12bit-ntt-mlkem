# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "/mnt/c/Users/Quan/Desktop/NTT-FPGA/Validation/ntt_platform/psu_cortexa53_0/standalone_psu_cortexa53_0/bsp/include/sleep.h"
  "/mnt/c/Users/Quan/Desktop/NTT-FPGA/Validation/ntt_platform/psu_cortexa53_0/standalone_psu_cortexa53_0/bsp/include/xiltimer.h"
  "/mnt/c/Users/Quan/Desktop/NTT-FPGA/Validation/ntt_platform/psu_cortexa53_0/standalone_psu_cortexa53_0/bsp/include/xtimer_config.h"
  "/mnt/c/Users/Quan/Desktop/NTT-FPGA/Validation/ntt_platform/psu_cortexa53_0/standalone_psu_cortexa53_0/bsp/lib/libxiltimer.a"
  )
endif()
