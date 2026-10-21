# halo3 - ReXGlue Recompiled Project (Android / Retroid Pocket build)
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(halo3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(ANDROID AND NOT TARGET rex::rexglue)
    # Cross build: the Android SDK package ships no codegen tool, so the
    # codegen step uses the Windows host tool (HALO3_HOST_REXGLUE).
    add_executable(rex::rexglue IMPORTED GLOBAL)
    set_target_properties(rex::rexglue PROPERTIES IMPORTED_LOCATION "${HALO3_HOST_REXGLUE}")
endif()

include(generated/rexglue.cmake)

# Halo 3's Waves audio plugins (waves\L360.dll, waves\Q10.dll) call into
# WavesLibDLL.dll; those import thunks are defined in src/dll_imports_*.cpp.
foreach(_halo3_dll l360 q10)
    if(TARGET halo3_${_halo3_dll})
        target_sources(halo3_${_halo3_dll} PRIVATE src/dll_imports_${_halo3_dll}.cpp)
        target_include_directories(halo3_${_halo3_dll} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
    endif()
endforeach()

# Sources
set(HALO3_SOURCES
    src/main.cpp
)

if(ANDROID)
    # Loaded by SDL's Java activity as libmain.so; it calls SDL_main().
    add_library(halo3 SHARED ${HALO3_SOURCES})
    set_target_properties(halo3 PROPERTIES OUTPUT_NAME main)
elseif(WIN32)
    add_executable(halo3 WIN32 ${HALO3_SOURCES})
else()
    add_executable(halo3 ${HALO3_SOURCES})
endif()

rexglue_setup_target(halo3)
