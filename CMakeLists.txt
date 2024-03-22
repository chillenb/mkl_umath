cmake_minimum_required(VERSION 3.27...3.28 FATAL_ERROR)

cmake_policy(SET CMP0135 NEW)

project(mkl_umath
  LANGUAGES C
  DESCRIPTION "mkl_umath module"
)

option(OPTIMIZATION_REPORT
  "Whether to generate optimization vectorization report"
  ON
)

find_package(Python COMPONENTS Interpreter Development.Module NumPy REQUIRED)

set(CYTHON_FLAGS -t -w ${CMAKE_SOURCE_DIR})
# find_package(Cython REQUIRED)
find_program(Cython_EXECUTABLE REQUIRED
  NAMES cython cython3 cython.bat cython3.bat)

set(MKL_ARCH intel64)
set(MKL_LINK sdl)
set(MKL_THREADING intel_thread)
set(MKL_INTERFACE ilp64)
find_package(MKL REQUIRED)

if(WIN32)
 string(CONCAT WARNING_FLAGS
     "-Wall "
     "-Wextra "
     "-Winit-self "
     "-Wunused-function "
     "-Wuninitialized "
     "-Wmissing-declarations "
     "-Wstrict-prototypes "
     "-Wno-unused-parameter "
     "-Wno-implicit-function-declaration "
   )
   string(CONCAT SDL_FLAGS
     "/GS "
     "/DynamicBase "
   )
   set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /Ox ${WARNING_FLAGS} ${SDL_FLAGS}")
   set(CMAKE_C_FLAGS_DEBUG
     "${CMAKE_C_FLAGS_DEBUG} ${WARNING_FLAGS} ${SDL_FLAGS} -O0 -g1 -DDEBUG"
   )
  set(MKL_UMATH_LINKER_OPTIONS "LINKER:/NXCompat;LINKER:/DynamicBase")
elseif(UNIX)
   string(CONCAT WARNING_FLAGS
     "-Wall "
     "-Wextra "
     "-Winit-self "
     "-Wunused-function "
     "-Wuninitialized "
     "-Wmissing-declarations "
     "-Wstrict-prototypes "
     "-Wno-unused-parameter "
     "-fdiagnostics-color=auto "
   )
   string(CONCAT SDL_FLAGS
     "-fstack-protector "
     "-fstack-protector-all "
     "-fpic "
     "-fPIC "
     "-D_FORTIFY_SOURCE=2 "
     "-Wformat "
     "-Wformat-security "
#     "-fno-strict-overflow "    # no-strict-overflow is implied by -fwrapv
     "-fno-delete-null-pointer-checks "
     "-fwrapv "
   )
   string(CONCAT CFLAGS
     "${WARNING_FLAGS}"
     "${SDL_FLAGS}"
   )
   set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 ${CFLAGS}")
   set(CMAKE_C_FLAGS_DEBUG
     "${CMAKE_C_FLAGS_DEBUG} ${CFLAGS} -O0 -g1 -DDEBUG"
   )
   set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-incompatible-function-pointer-types ${CFLAGS}")
  set(MKL_UMATH_LINKER_OPTIONS "LINKER:-z,noexecstack,-z,relro,-z,now")
else()
  message(FATAL_ERROR "Unsupported system.")
endif()


add_custom_command(
  OUTPUT "${PROJECT_SOURCE_DIR}/mkl_umath/src/__umath_generated.c"
  COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/scripts/generate_umath.py
          --output ${PROJECT_SOURCE_DIR}/mkl_umath/src/__umath_generated.c
  VERBATIM)

add_custom_command(
  OUTPUT "${PROJECT_SOURCE_DIR}/mkl_umath/src/mkl_umath_loops.h"
  COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/_vendored/conv_template.py
          ${PROJECT_SOURCE_DIR}/mkl_umath/src/mkl_umath_loops.h.src
          > ${PROJECT_SOURCE_DIR}/mkl_umath/src/mkl_umath_loops.h
  VERBATIM
)

add_custom_command(
  OUTPUT "${PROJECT_SOURCE_DIR}/mkl_umath/src/mkl_umath_loops.c"
  COMMAND ${Python_EXECUTABLE} ${PROJECT_SOURCE_DIR}/_vendored/conv_template.py
          ${PROJECT_SOURCE_DIR}/mkl_umath/src/mkl_umath_loops.c.src
          > ${PROJECT_SOURCE_DIR}/mkl_umath/src/mkl_umath_loops.c
  VERBATIM
)


set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
# set_property(GLOBAL PROPERTY GLOBAL_DEPENDS_DEBUG_MODE 1)
set(_linker_options ${MKL_UMATH_LINKER_OPTIONS})

set(_trgt mkl_umath_loops)
add_library(${_trgt} SHARED "mkl_umath/src/mkl_umath_loops.c" "mkl_umath/src/mkl_umath_loops.h")
set_target_properties(${_trgt} PROPERTIES CMAKE_POSITION_INDEPENDENT_CODE ON)
target_include_directories(${_trgt} PRIVATE "mkl_umath/src/" ${Python_NumPy_INCLUDE_DIRS} ${Python_INCLUDE_DIRS})
target_link_libraries(${_trgt} PRIVATE mkl_rt ${Python_LIBRARIES})
target_link_options(${_trgt} PRIVATE ${_linker_options})

target_compile_options(${_trgt} PRIVATE
$<$<C_COMPILER_ID:GNU>:-ftree-vectorize -ffast-math -march=x86-64-v3 -mtune=haswell>
$<$<C_COMPILER_ID:Clang>:-fvectorize -ftree-vectorize -ffast-math -fno-math-errno -O3 -mavx2>
$<$<C_COMPILER_ID:IntelLLVM>:-fvectorize -fveclib=SVML>)


if(OPTIMIZATION_REPORT)
  target_compile_options(${_trgt} PRIVATE
    $<$<C_COMPILER_ID:Intel>: -qopt-report=3>
    $<$<C_COMPILER_ID:IntelLLVM>: -qopt-report=3>
    $<$<C_COMPILER_ID:GNU>: -fopt-info-omp-vec-optimized-note>
    $<$<C_COMPILER_ID:Clang>: -Rpass="loop|vect" -Rpass-missed="loop|vect" -Rpass-analysis="loop|vect">
  )
endif()

install(TARGETS ${_trgt}
  LIBRARY DESTINATION mkl_umath
  ARCHIVE DESTINATION mkl_umath
  RUNTIME DESTINATION mkl_umath
)

Python_add_library(_ufuncs MODULE WITH_SOABI "mkl_umath/src/ufuncsmodule.c" "mkl_umath/src/__umath_generated.c")
target_include_directories(_ufuncs PRIVATE "mkl_umath/src" ${Python_NumPy_INCLUDE_DIRS} ${MKL_INCLUDE_DIR})
target_compile_definitions(_ufuncs PUBLIC NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION)
target_link_options(_ufuncs PRIVATE ${_linker_options})
target_link_libraries(_ufuncs PRIVATE mkl_umath_loops)
if (UNIX)
  set_target_properties(_ufuncs PROPERTIES INSTALL_RPATH "$ORIGIN" BUILD_RPATH_USE_ORIGIN ON BUILD_WITH_INSTALL_RPATH ON)
endif()
install(TARGETS _ufuncs LIBRARY DESTINATION mkl_umath)

set(_generated_src "${CMAKE_CURRENT_BINARY_DIR}/_patch.c")

add_custom_command(
  OUTPUT ${_generated_src}
  COMMAND ${Cython_EXECUTABLE}
  ARGS ${CYTHON_FLAGS} ${PROJECT_SOURCE_DIR}/mkl_umath/src/_patch.pyx  --output-file ${_generated_src}
  DEPENDS ${PROJECT_SOURCE_DIR}/mkl_umath/src/_patch.pyx
  VERBATIM
)

# add_cython_target(_patch "mkl_umath/src/_patch.pyx" C OUTPUT_VAR _generated_src)


Python_add_library(_patch MODULE WITH_SOABI ${_generated_src})
target_include_directories(_patch PRIVATE "mkl_umath/src/" ${Python_NumPy_INCLUDE_DIRS} ${PYTHON_INCLUDE_DIRS})
target_compile_definitions(_patch PUBLIC NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION)
target_link_libraries(_patch PRIVATE mkl_umath_loops)
if (UNIX)
  set_target_properties(_patch PROPERTIES INSTALL_RPATH "$ORIGIN" BUILD_RPATH_USE_ORIGIN ON BUILD_WITH_INSTALL_RPATH ON)
endif()
install(TARGETS _patch LIBRARY DESTINATION mkl_umath)
