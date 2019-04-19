# Library for printing out student info

email () {
    cat $COURSE_DB/students/$1/email
}

first () {
    if [ "$1" = '-' ]; then
        sed 's/ .*//' $COURSE_DB/students/$2/first
    else
        cat $COURSE_DB/students/$1/first
    fi
}

last () {
    cat $COURSE_DB/students/$1/last
}

name () {
    echo `first $1; last $1`
}

github () {
    cat $COURSE_DB/students/$1/github
}

