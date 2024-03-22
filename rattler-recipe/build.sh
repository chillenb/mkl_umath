# This is necessary to help DPC++ find Intel libraries such as SVML, IRNG, etc in build prefix
# export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${BUILD_PREFIX}/lib"

# Intel LLVM must cooperate with compiler and sysroot from conda
# echo "--gcc-toolchain=${BUILD_PREFIX} --sysroot=${BUILD_PREFIX}/${HOST}/sysroot -target ${HOST}" > icx_for_conda.cfg
# export ICXCFG="$(pwd)/icx_for_conda.cfg"

export CMAKE_GENERATOR="Ninja"
# SKBUILD_ARGS="-- -DCMAKE_C_COMPILER:PATH=icx -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON"


${PYTHON} -m pip install --no-deps --ignore-installed .

