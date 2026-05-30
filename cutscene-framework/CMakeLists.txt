cmake_minimum_required(VERSION 3.21)

# Single DLL targeting SE + AE (incl. 1.6.1170) + VR via CommonLibSSE-NG's
# versionless address library. No per-runtime build needed.
project(CinematicCamera VERSION 2.0.0 LANGUAGES CXX)

# Optional: auto-copy the built DLL into your Skyrim Data/SKSE/Plugins folder.
if(DEFINED ENV{SKYRIM_FOLDER} AND IS_DIRECTORY "$ENV{SKYRIM_FOLDER}/Data")
    set(OUTPUT_FOLDER "$ENV{SKYRIM_FOLDER}/Data")
endif()
if(DEFINED ENV{SKYRIM_MODS_FOLDER} AND IS_DIRECTORY "$ENV{SKYRIM_MODS_FOLDER}")
    set(OUTPUT_FOLDER "$ENV{SKYRIM_MODS_FOLDER}/${PROJECT_NAME}")
endif()

set(SOURCES
    src/CameraPath.cpp
    src/CameraPath.h
    src/PathPlayer.cpp
    src/PathPlayer.h
    src/Papyrus.cpp
    src/Papyrus.h
    src/plugin.cpp
)

find_package(CommonLibSSE CONFIG REQUIRED)
add_commonlibsse_plugin(${PROJECT_NAME}
    SOURCES ${SOURCES}
    AUTHOR  "Ma11st"
    USE_ADDRESS_LIBRARY)

find_package(jsoncpp CONFIG REQUIRED)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)
target_precompile_headers(${PROJECT_NAME} PRIVATE src/PCH.h)
target_link_libraries(${PROJECT_NAME} PRIVATE JsonCpp::JsonCpp)

if(DEFINED OUTPUT_FOLDER)
    set(DLL_FOLDER "${OUTPUT_FOLDER}/SKSE/Plugins")
    message(STATUS "SKSE plugin output folder: ${DLL_FOLDER}")
    add_custom_command(
        TARGET "${PROJECT_NAME}" POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${DLL_FOLDER}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:${PROJECT_NAME}>" "${DLL_FOLDER}/$<TARGET_FILE_NAME:${PROJECT_NAME}>"
        VERBATIM)
endif()
