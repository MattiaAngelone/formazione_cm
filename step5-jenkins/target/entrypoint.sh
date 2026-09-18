#!/bin/sh

set -e

# Avvia il server SSH: si mette in background da solo senza -D
# l'opzione -e invia i messaggi di log allo standard error
/usr/sbin/sshd -e

# Sostituisce questa shell con lo script ufficiale che avvia docker
# "$@" inoltra gli eventuali argomenti ricevuti dal container
exec dockerd-entrypoint.sh "$@"
