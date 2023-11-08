cmake_minimum_required(VERSION 3.15)

include(proj.conf)

add_definitions(-DU8X8_WITH_USER_PTR)

find_package(bouffalo_sdk REQUIRED HINTS $ENV{BL_SDK_BASE})

sdk_add_include_directories(. u8g2/csrc)

target_sources(app PRIVATE usb_host.c hidparser.c spi.c osd_u8g2.c menu.c)

file(GLOB COMPONENT_SRCS u8g2/csrc/*.c  u8g2/sys/bitmap/common/*.c)
target_sources(app PRIVATE ${COMPONENT_SRCS})

sdk_set_main_file(main.c)

project(misterynano_fw)
