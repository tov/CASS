# CMake helpers

perl_find_cmake_X_programs='
    $p = "add$ARGV[0]_program";
    $_ = join "", <STDIN>;
    print "$1\n" while /\b$p\s*\(\s*([-_[:alnum:]]+)/ig
'

find_cmake_X_programs () {
    perl -e "$perl_find_cmake_X_programs" "$1"
}

find_cmake_programs () {
    find_cmake_X_programs '' < CMakeLists.txt
}

find_cmake_test_programs () {
    find_cmake_X_programs _test < CMakeLists.txt
}
