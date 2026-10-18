# uaw - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(uaw LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(UAW_SOURCES
    src/main.cpp
    src/uaw_hooks.cpp
)

if(WIN32)
    add_executable(uaw WIN32 ${UAW_SOURCES})
else()
    add_executable(uaw ${UAW_SOURCES})
endif()

rexglue_setup_target(uaw)
