# uaw - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(uaw LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(ANDROID AND NOT TARGET rex::rexglue)
    # Cross build: the Android SDK package ships no codegen tool, so the
    # codegen step uses the Windows host tool (UAW_HOST_REXGLUE).
    add_executable(rex::rexglue IMPORTED GLOBAL)
    set_target_properties(rex::rexglue PROPERTIES IMPORTED_LOCATION "${UAW_HOST_REXGLUE}")
endif()

include(generated/rexglue.cmake)

# Sources
set(UAW_SOURCES
    src/main.cpp
    src/uaw_hooks.cpp
)

if(ANDROID)
    # Loaded by SDL's Java activity as libmain.so; it calls SDL_main().
    add_library(uaw SHARED ${UAW_SOURCES})
    set_target_properties(uaw PROPERTIES OUTPUT_NAME main)
elseif(WIN32)
    add_executable(uaw WIN32 ${UAW_SOURCES})
else()
    add_executable(uaw ${UAW_SOURCES})
endif()

rexglue_setup_target(uaw)
