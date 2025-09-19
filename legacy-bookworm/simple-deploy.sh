#!/usr/bin/expect -f

set timeout 30
spawn ssh -o StrictHostKeyChecking=no pi@192.168.1.106
expect "password:"
send "palmer00\r"
expect "$ "
send "echo 'Connected successfully!'\r"
expect "$ "
send "uname -a\r"
expect "$ "
send "exit\r"
expect eof