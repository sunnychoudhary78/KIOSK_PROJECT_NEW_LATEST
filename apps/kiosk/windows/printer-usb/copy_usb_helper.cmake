# Builds the x86 Brother USB helper and copies it next to skp_kiosk.exe.
# Missing MSBuild or a failed helper build is a warning. The kiosk still runs;
# USB compare then reports helper_missing. SNMP is unchanged.

if(NOT EXISTS "${SOURCE_CSPROJ}")
  message(WARNING "USB helper project not found; kiosk will run without it")
  return()
endif()

set(HELPER_CONFIG "${CONFIG}")
if(HELPER_CONFIG STREQUAL "Profile" OR HELPER_CONFIG STREQUAL "")
  set(HELPER_CONFIG "Release")
endif()

find_program(VSWHERE_EXE vswhere
  HINTS "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer"
        "$ENV{ProgramFiles}/Microsoft Visual Studio/Installer")
if(NOT VSWHERE_EXE)
  message(WARNING "vswhere not found; USB helper was not built")
  return()
endif()

execute_process(
  COMMAND "${VSWHERE_EXE}" -latest -requires Microsoft.Component.MSBuild
          -find "MSBuild\\**\\Bin\\MSBuild.exe"
  OUTPUT_VARIABLE MSBUILD_OUT
  OUTPUT_STRIP_TRAILING_WHITESPACE
  RESULT_VARIABLE VSWHERE_RC
)
if(NOT VSWHERE_RC EQUAL 0 OR MSBUILD_OUT STREQUAL "")
  message(WARNING "MSBuild not found; USB helper was not built")
  return()
endif()

string(REPLACE "\r" "" MSBUILD_OUT "${MSBUILD_OUT}")
string(REPLACE "\n" ";" MSBUILD_LIST "${MSBUILD_OUT}")
list(GET MSBUILD_LIST 0 MSBUILD_EXE)
if(NOT EXISTS "${MSBUILD_EXE}")
  message(WARNING "MSBuild path is unusable; USB helper was not built")
  return()
endif()

execute_process(
  COMMAND "${MSBUILD_EXE}" "${SOURCE_CSPROJ}"
          "/p:Configuration=${HELPER_CONFIG}"
          "/p:Platform=x86"
          /v:m
          /nologo
  RESULT_VARIABLE BUILD_RC
)
if(NOT BUILD_RC EQUAL 0)
  message(WARNING "USB helper build failed (${BUILD_RC}); kiosk will run without it")
  return()
endif()

get_filename_component(PROJECT_DIR "${SOURCE_CSPROJ}" DIRECTORY)
set(BUILT_EXE "${PROJECT_DIR}/bin/${HELPER_CONFIG}/skp_printer_usb.exe")
if(NOT EXISTS "${BUILT_EXE}")
  message(WARNING "USB helper exe was not produced at ${BUILT_EXE}")
  return()
endif()

if(OUT_DIR STREQUAL "")
  message(WARNING "USB helper output directory was not set")
  return()
endif()

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${BUILT_EXE}" "${OUT_DIR}/skp_printer_usb.exe"
  RESULT_VARIABLE COPY_RC
)
if(NOT COPY_RC EQUAL 0)
  message(WARNING "USB helper could not be copied beside the kiosk")
endif()
