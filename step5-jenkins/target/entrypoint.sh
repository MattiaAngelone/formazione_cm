#!/bin/sh

set -e

# sshd si mette in background da solo senza -D
/usr/sbin/sshd -e

# dockerd diventa PID 1 e riceve i segnali
exec dockerd-entrypoint.sh "$@"
