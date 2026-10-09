#!/usr/bin/env bash
# Mise a jour automatique de WorldFront (a lancer par cron sur le serveur).
# Si la branche suivie a avance sur GitHub : recupere, recompile, puis
# redemarre le jeu (le monde est sauvegarde a l'arret). Sinon ne fait rien.
#
# Installation (une seule fois, dans le dossier du jeu) :
#   crontab -e
#   */5 * * * * cd ~/worldfront && ./deploy/maj-auto.sh >> maj-auto.log 2>&1
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Un seul passage a la fois (une compilation peut durer plus de 5 min).
exec 9> .maj-auto.lock
flock -n 9 || exit 0

branche=$(git rev-parse --abbrev-ref HEAD)
git fetch -q origin "$branche"
# Version reellement compilee et lancee (et non celle du code : un
# « git pull » a la main ne doit pas faire croire que tout est a jour).
installee=$(cat .maj-auto.version 2>/dev/null || true)
[ "$installee" = "$(git rev-parse "origin/$branche")" ] && exit 0

echo "$(date '+%F %T') nouvelle version sur $branche : $(git log -1 --format='%h %s' "origin/$branche")"
git merge -q --ff-only "origin/$branche"
cargo build --release -q

PID=$(pgrep -f './worldfront$' || true)
if [ -n "$PID" ]; then
  kill $PID
  while kill -0 $PID 2>/dev/null; do sleep 0.5; done
fi
cp -f target/release/worldfront ./worldfront
setsid nohup ./worldfront >> worldfront.out 2>&1 < /dev/null &
git rev-parse HEAD > .maj-auto.version
echo "$(date '+%F %T') WorldFront redemarre."
