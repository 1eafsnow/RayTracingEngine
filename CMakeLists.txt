cmake_minimum_required(VERSION 3.10)

#set(CUDA_PATH $ENV{CUDA_PATH})
#message("The value of CUDA_PATH is: ${CUDA_PATH}")
#set(CMAKE_GENERATOR_TOOLSET "cuda=${CUDA_PATH}")

project(RenderEngine VERSION 1.0 LANGUAGES CUDA CXX)

set(CMAKE_CXX_STANDARD 17)

# 启用 RDC 支持
set(CMAKE_CUDA_SEPARABLE_COMPILATION ON)
set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/bin)

find_package(CUDAToolkit REQUIRED)

include_directories(${PROJECT_SOURCE_DIR}/src)
include_directories(${PROJECT_SOURCE_DIR}/3rd/assimp)
include_directories(${PROJECT_SOURCE_DIR}/3rd/glew-2.2.0/include)
include_directories(${PROJECT_SOURCE_DIR}/3rd/glfw-3.3.8)
include_directories(${PROJECT_SOURCE_DIR}/3rd/imgui-1.90.4)
include_directories(${PROJECT_SOURCE_DIR}/3rd/stb)

file(GLOB SRCS CONFIGURE_DEPENDS 
    ${PROJECT_SOURCE_DIR}/src/GUI/*.cpp
    ${PROJECT_SOURCE_DIR}/src/GUI/*.cu
    ${PROJECT_SOURCE_DIR}/src/Material/*.cpp
    ${PROJECT_SOURCE_DIR}/src/Material/*.cu
    ${PROJECT_SOURCE_DIR}/src/Math/*.cpp
    ${PROJECT_SOURCE_DIR}/src/Math/*.cu
    ${PROJECT_SOURCE_DIR}/src/Object/*.cpp
    ${PROJECT_SOURCE_DIR}/src/Object/*.cu
    ${PROJECT_SOURCE_DIR}/src/Render/*.cpp
    ${PROJECT_SOURCE_DIR}/src/Render/*.cu
    ${PROJECT_SOURCE_DIR}/src/World/*.cpp
    ${PROJECT_SOURCE_DIR}/src/World/*.cu
    ${PROJECT_SOURCE_DIR}/src/*.cpp
    ${PROJECT_SOURCE_DIR}/src/*.cu
)

add_library(opengl STATIC IMPORTED)
add_library(assimg STATIC IMPORTED)
add_library(glew STATIC IMPORTED)
add_library(glfw STATIC IMPORTED)
add_library(imgui STATIC IMPORTED)

if (CMAKE_SYSTEM_NAME MATCHES "Windows")
    set_target_properties(opengl PROPERTIES IMPORTED_LOCATION opengl32.lib)
    set_target_properties(assimg PROPERTIES IMPORTED_LOCATION ${PROJECT_SOURCE_DIR}/3rd/assimp/assimp-vc143-mt.lib)
    set_target_properties(glew PROPERTIES IMPORTED_LOCATION ${PROJECT_SOURCE_DIR}/3rd/glew-2.2.0/glew32.lib)
    set_target_properties(glfw PROPERTIES IMPORTED_LOCATION ${PROJECT_SOURCE_DIR}/3rd/glfw-3.3.8/glfw3dll.lib)
    set_target_properties(imgui PROPERTIES IMPORTED_LOCATION ${PROJECT_SOURCE_DIR}/3rd/imgui-1.90.4/imgui.lib)
elseif (CMAKE_SYSTEM_NAME MATCHES "Linux")

endif()

add_executable(RenderEngine ${SRCS})
target_link_libraries(RenderEngine opengl glew glfw CUDA::cudart assimg imgui)
if (WIN32)
    target_compile_definitions(RenderEngine PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
endif()
set_target_properties(RenderEngine PROPERTIES CUDA_ARCHITECTURES "native")
target_compile_features(RenderEngine PUBLIC cuda_std_17)
#set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --relocatable-device-code=true")
#target_compile_options(RenderEngine PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:-c "-rdc=true">)
set_target_properties(RenderEngine PROPERTIES CUDA_RESOLVE_DEVICE_SYMBOLS ON)

add_custom_command(TARGET RenderEngine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${PROJECT_SOURCE_DIR}/3rd/assimp/assimp-vc143-mt.dll"
        $<TARGET_FILE_DIR:RenderEngine>)
add_custom_command(TARGET RenderEngine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${PROJECT_SOURCE_DIR}/3rd/glew-2.2.0/glew32.dll"
        $<TARGET_FILE_DIR:RenderEngine>)
add_custom_command(TARGET RenderEngine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${PROJECT_SOURCE_DIR}/3rd/glfw-3.3.8/glfw3.dll"
        $<TARGET_FILE_DIR:RenderEngine>)