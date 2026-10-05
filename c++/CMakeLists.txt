cmake_minimum_required(VERSION 3.16)
project(priism CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

string(TIMESTAMP PRIISM_BUILD_DATE "%Y-%m-%d" UTC)
add_compile_definitions(PRIISM_BUILD_DATE_STR="[${PRIISM_BUILD_DATE}]")

add_executable(priism
  src/main.cpp
  src/util.cpp
  src/ui.cpp
  src/priism.cpp
)

target_compile_options(priism PRIVATE -Wall -Wextra)

add_executable(priism-init
  src/init.cpp
  src/util.cpp
  src/ui.cpp
)

target_compile_options(priism-init PRIVATE -Wall -Wextra)
