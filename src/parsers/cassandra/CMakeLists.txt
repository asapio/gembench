set (parsers_cassandra_src_files 
     Const.h
     decision-tree.c
     decision-tree.h
     imm-reward.c
     imm-reward.h
     mdpCassandra.c
     mdpCassandra.h
     parse_constant.h
     parse_err.c
     parse_err.h
     parse_hash.c
     parse_hash.h
     pomdpCassandraWrapper.cpp
     pomdpCassandraWrapper.h
     pomdp_spec.tab.cc
     pomdp_spec.tab.hh
     pomdp_spec.yy.cc
     sparse-matrix.c
     sparse-matrix.h)
     
set (CMAKE_CXX_FLAGS "-O3 -Wno-write-strings")     
set (CMAKE_C_FLAGS "-O3 -Wno-implicit -Wno-write-strings")     
     
add_library(parsers_cassandra ${parsers_cassandra_src_files})
