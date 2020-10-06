# Working with dates and times

human_date_fmt='%A, %-d %B'
human_time_fmt='%-I:%M %p'
human_datetime_fmt="$human_time_fmt on $human_date_fmt (%Z)"
human_tomorrow_fmt="$human_time_fmt %Z tomorrow (%a.)"
gscd_datetime_fmt='%Y-%m-%d %H:%M:%S %z'

human_datetime () {
    date "$@" +"$human_datetime_fmt"
}

gscd_datetime () {
    date "$@" +"$gscd_datetime_fmt"
}
