#!/usr/bin/expect

set username [lindex $argv 0]
set password  [lindex $argv 1]
set container_id [lindex $argv 2]

spawn docker exec -it $container_id ntfy user add --role=admin $username

expect "password:"
send "$password\r"

expect "confirm:"
send "$password\r"

expect eof

