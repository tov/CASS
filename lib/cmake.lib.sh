# CMake helpers

perl_find_cmake_command_arg1='
    my $inp = join "", grep /^\s*[^#]/, <STDIN>;
    my $pat = join "|", @ARGV;
    my $re  = qr/\b(?:$pat) \s*\(\s* ([-_[:alnum:]]+)/ix;
    print "$1\n" while $inp =~ /$re/ig;
'

find_cmake_command_arg1 () {
    perl -e "$perl_find_cmake_command_arg1" "$@" < CMakeLists.txt
}

find_cmake_programs () {
    find_cmake_command_arg1 add_program add_executable
}

find_cmake_test_programs () {
    find_cmake_command_arg1 add_test_program
}
