# EIII Rack for macOS: VST3 and Audio Unit (AUv2) instrument plugins.
#
#   cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release      (or omit -G Ninja for Unix Makefiles)
#   cmake --build build
#   -> build/EIII-Rack_assets/VST3/EIII Rack.vst3, build/EIII-Rack_assets/AUv2/EIII Rack.component
#   -DEIII_INSTALL_AFTER_BUILD=ON also copies them to ~/Library/Audio/Plug-Ins/{VST3,Components}
#
# The plugin is written as a CLAP (plugin/eiii_clap.cpp, in the static library eiii-rack-impl); clap-wrapper turns it
# into the VST3 and the AU.  The CLAP SDK, clap-wrapper, the VST3 SDK and the AudioUnitSDK are downloaded at configure
# time at pinned versions.  Universal binary (arm64 + x86_64), macOS 11 or later.
cmake_minimum_required(VERSION 3.21)

set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Architectures")
if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
	set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

project(eiii-rack VERSION 0.1.0 LANGUAGES C CXX OBJCXX ASM)

if (NOT APPLE)
	message(FATAL_ERROR "EIII Rack builds for macOS only (VST3 + AU)")
endif()

option(EIII_INSTALL_AFTER_BUILD "Copy the VST3 and the AU to ~/Library/Audio/Plug-Ins after building" OFF)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_OBJCXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# ---- dependencies (pinned) ----
include(FetchContent)
FetchContent_Declare(clap GIT_REPOSITORY https://github.com/free-audio/clap.git GIT_TAG 1.2.10 GIT_SHALLOW TRUE)
FetchContent_Declare(clap-wrapper GIT_REPOSITORY https://github.com/free-audio/clap-wrapper.git GIT_TAG v0.16.0 GIT_SHALLOW TRUE)
FetchContent_GetProperties(clap)
if (NOT clap_POPULATED)
	FetchContent_Populate(clap)          # source only: clap-wrapper adds it as its CLAP SDK
endif()
set(CLAP_SDK_ROOT "${clap_SOURCE_DIR}" CACHE PATH "CLAP SDK" FORCE)
set(CLAP_WRAPPER_DOWNLOAD_DEPENDENCIES ON CACHE BOOL "" FORCE)      # VST3 SDK + AudioUnitSDK
FetchContent_MakeAvailable(clap-wrapper)

# ---- the plugin implementation: emulator runtime + panel UI + CLAP plugin, one static library ----
set(MACHINE ${CMAKE_CURRENT_SOURCE_DIR}/machine)
set(MAME ${MACHINE}/third_party/mame)
set(SFDIR ${MAME}/3rdparty/softfloat3)

# unmodified MAME device sources (CPU, FPU, SCSI, serial): their warnings are not ours to fix
set(MAME_SRC
	${MAME}/src/devices/cpu/ns32000/ns32000.cpp ${MAME}/src/devices/cpu/ns32000/ns32000d.cpp ${MAME}/src/devices/machine/ns32081.cpp
	${MAME}/src/devices/machine/nscsi_bus.cpp ${MAME}/src/devices/machine/ncr5380.cpp ${MAME}/src/devices/machine/nscsi_hle.cpp
	${MAME}/src/devices/bus/nscsi/hd.cpp ${MAME}/src/devices/bus/nscsi/cd.cpp ${MAME}/src/devices/machine/z80scc.cpp
	${MAME}/src/devices/machine/z80daisy.cpp ${MAME}/src/lib/util/strformat.cpp ${MAME}/src/lib/util/coreutil.cpp
	${MAME}/src/lib/util/disasmintf.cpp
	${MACHINE}/eiii_scsi.cpp)       # extracted verbatim from MAME's emu3.cpp
# Berkeley SoftFloat 3e with MAME's configuration, compiled as C++ like MAME does
file(STRINGS ${MAME}/softfloat3_files.txt SF_FILES)
list(TRANSFORM SF_FILES PREPEND ${MAME}/)
set(CORE_SRC
	fchip/eiii_fchip.cpp cem/eiii_cem3387.cpp cem/eiii_cem_calibration.cpp cem/eiii_cem_cv_conditioning.cpp
	cem/eiii_cem3387_v2.cpp host/eiii_backend.cpp runtime/eiii_runtime.cpp runtime/eiii_engine.cpp
	panel/eiii_lcd.cpp panel/eiii_panel_model.cpp panel/eiii_panel_adapter.cpp
	machine/shim/emu_shim.cpp machine/diserial_shim.cpp)
set(UI_SRC
	ui/raster.cpp ui/panel_view.cpp ui/panel_menu.cpp ui/panel_window.cpp ui/mac_window.mm ui/mac_file_dialog.mm ui/fonts.S)

add_library(eiii-softfloat STATIC ${SF_FILES})
set_source_files_properties(${SF_FILES} PROPERTIES LANGUAGE CXX)
target_compile_options(eiii-softfloat PRIVATE -x c++ -std=c++17 -w -ffp-contract=off)
target_compile_definitions(eiii-softfloat PRIVATE SOFTFLOAT_ROUND_ODD INLINE_LEVEL=5 SOFTFLOAT_FAST_DIV32TO16
	SOFTFLOAT_FAST_DIV64TO32 SOFTFLOAT_FAST_INT64 LITTLEENDIAN=1)
target_include_directories(eiii-softfloat PRIVATE ${MAME}/src/osd ${SFDIR}/build/MAME ${SFDIR}/source
	${SFDIR}/source/include ${SFDIR}/source/8086 ${SFDIR}/bochs_ext)

add_library(eiii-rack-impl STATIC ${CORE_SRC} ${MAME_SRC} ${UI_SRC} plugin/eiii_clap.cpp)
set_source_files_properties(${MAME_SRC} PROPERTIES COMPILE_OPTIONS -w)
set_source_files_properties(ui/mac_window.mm ui/mac_file_dialog.mm PROPERTIES COMPILE_OPTIONS -fno-objc-arc)
set_source_files_properties(ui/fonts.S PROPERTIES INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/third_party/fonts
	OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/fonts/NotoSans-CondensedMedium.ttf;${CMAKE_CURRENT_SOURCE_DIR}/third_party/fonts/NotoSans-CondensedSemiBold.ttf;${CMAKE_CURRENT_SOURCE_DIR}/third_party/fonts/ArchivoNarrow-wght.ttf")
# -ffp-contract=off: no fused multiply-add contraction, so the analog model is bit-identical on x86-64 and ARM64
target_compile_options(eiii-rack-impl PRIVATE $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-ffp-contract=off -Wall -Wno-unused-variable
	-Wno-unused-function -Wno-unused-but-set-variable>)
target_include_directories(eiii-rack-impl PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR} ${MACHINE} ${MACHINE}/shim ${MAME} ${MAME}/src/lib ${MAME}/src/emu ${MAME}/src/osd
	${MAME}/src/lib/util ${MAME}/src/devices ${MAME}/src/devices/cpu/ns32000 ${MAME}/3rdparty)
target_link_libraries(eiii-rack-impl PUBLIC clap eiii-softfloat "-framework Cocoa")

# ---- VST3 + AU from the CLAP implementation (no CLAP is built or shipped) ----
set(EIII_OUTPUT_NAME "EIII Rack")
set(EIII_BUNDLE_ID "org.eiii-core.eiii-rack")
set(EIII_ASSETS ${CMAKE_BINARY_DIR}/EIII-Rack_assets)
set(CLAP_WRAPPER_COPY_AFTER_BUILD ${EIII_INSTALL_AFTER_BUILD})
add_custom_target(EIII-Rack_all ALL)

add_library(EIII-Rack_vst3 MODULE plugin/eiii_entry.cpp)
target_link_libraries(EIII-Rack_vst3 PRIVATE eiii-rack-impl)
target_add_vst3_wrapper(TARGET EIII-Rack_vst3
	OUTPUT_NAME "${EIII_OUTPUT_NAME}"
	BUNDLE_IDENTIFIER "${EIII_BUNDLE_ID}.vst3"
	BUNDLE_VERSION ${PROJECT_VERSION}
	ASSET_OUTPUT_DIRECTORY "${EIII_ASSETS}/VST3")
set_target_properties(EIII-Rack_vst3 PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${EIII_ASSETS}/VST3")
add_dependencies(EIII-Rack_all EIII-Rack_vst3)

add_library(EIII-Rack_auv2 MODULE plugin/eiii_entry.cpp)
target_link_libraries(EIII-Rack_auv2 PRIVATE eiii-rack-impl)
target_add_auv2_wrapper(TARGET EIII-Rack_auv2
	OUTPUT_NAME "${EIII_OUTPUT_NAME}"
	BUNDLE_IDENTIFIER "${EIII_BUNDLE_ID}.auv2"
	BUNDLE_VERSION ${PROJECT_VERSION}
	MANUFACTURER_NAME "eiii-core"
	MANUFACTURER_CODE "Eiii"
	SUBTYPE_CODE "E3rk"
	INSTRUMENT_TYPE "aumu")
set_target_properties(EIII-Rack_auv2 PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${EIII_ASSETS}/AUv2")
# clap-wrapper copies its generated Info.plist (with the AudioComponents entry) only when the AU links, and every CMake
# reconfigure rewrites the bundle's Info.plist: put it back on every build
add_custom_target(EIII-Rack_auv2_plist ALL
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_BINARY_DIR}/EIII-Rack_auv2-build-helper-output/auv2_Info.plist
		"$<TARGET_BUNDLE_CONTENT_DIR:EIII-Rack_auv2>/Info.plist"
	DEPENDS EIII-Rack_auv2 VERBATIM)
add_dependencies(EIII-Rack_all EIII-Rack_auv2 EIII-Rack_auv2_plist)
