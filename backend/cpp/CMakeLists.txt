cmake_minimum_required(VERSION 3.25)
project(stockroom_api LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Drogon CONFIG REQUIRED)
find_package(jwt-cpp CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_subdirectory(vendor/bcrypt)

add_executable(stockroom_api src/main.cpp src/auth.cpp src/inventory.cpp src/loans.cpp src/events.cpp)
target_link_libraries(stockroom_api PRIVATE Drogon::Drogon jwt-cpp::jwt-cpp nlohmann_json::nlohmann_json bcrypt)
if(WIN32)
  target_link_libraries(stockroom_api PRIVATE ws2_32)
endif()
