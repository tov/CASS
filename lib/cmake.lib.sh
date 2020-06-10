# CMake helpers

perl_find_cmake_command_arg1='
    $_ = join "", <STDIN>;
    print "$1\n" while /\b$ARGV[0]\s*\(\s*([-_[:alnum:]]+)/ig
'

find_cmake_command_arg1 () {
    perl -e "$perl_find_cmake_command_arg1" "$1" < CMakeLists.txt
}

find_cmake_programs () {
    find_cmake_command_arg1 add_program
    find_cmake_command_arg1 add_executable
}

find_cmake_test_programs () {
    find_cmake_command_arg1 add_test_program
}
