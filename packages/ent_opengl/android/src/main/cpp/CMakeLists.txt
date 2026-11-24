cmake_minimum_required(VERSION 3.18)
project(ent_opengl C)

add_library(ent_opengl SHARED window.c)
target_link_libraries(ent_opengl android)
