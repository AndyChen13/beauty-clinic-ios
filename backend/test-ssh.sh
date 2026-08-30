#!/bin/bash
# Test SSH connection to腾讯云 server

expect << EOF
spawn ssh -o StrictHostKeyChecking=no ubuntu@124.221.217.56 "whoami && hostname"
expect {
    "*password:" { send "sw4)3Vhm\$9eX!~W\r"; exp_continue }
    eof
}
EOF
