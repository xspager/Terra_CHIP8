#!/usr/bin/env sh
# from http://unix.stackexchange.com/questions/82561/convert-a-hex-string-to-binary-and-send-with-netcat

cat $1 | xxd -r -p > $2
