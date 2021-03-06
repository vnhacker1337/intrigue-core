#! /bin/bash
### BEGIN INIT INFO
# Provides: intrigue
# Required-Start: $remote_fs $syslog $postgres $redis
# Required-Stop: $remote_fs $syslog $postgres $redis
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Intrigue
# Description: This file starts and stops Intrigue server
#
### END INIT INFO

# Puma: intrigue-puma.pid
# Sidekiq: intrigue-sidekiq.pid

IDIR=.
#[[ -s "/home/ubuntu/.rvm/scripts/rvm" ]] && source "/home/ubuntu/.rvm/scripts/rvm"
#cd /core
#rvm use 2.3.1@core

function setup_server {
  bundle exec rake migrate
}

function start_server {
  echo "Starting interactive task processing..."
  bundle exec sidekiq -C $IDIR/config/sidekiq-task-interactive.yml -r $IDIR/core.rb -d -L $IDIR/log/task-interactive.log
  echo "Starting autoschedule task processing..."
  bundle exec sidekiq -C $IDIR/config/sidekiq-task-autoscheduled.yml -r $IDIR/core.rb -d -L $IDIR/log/task-autoscheduled.log
  echo "Starting background worker processing..."
  bundle exec sidekiq -C $IDIR/config/sidekiq-app.yml -r $IDIR/core.rb -d -L $IDIR/log/app.log
  echo "Starting puma..."
  bundle exec puma -C $IDIR/config/puma.rb # listen on a public port
}

function stop_server {
  for x in `ls $IDIR/tmp/pids/*.pid`; do
    echo "Killing $x: `cat $x`"
    kill -KILL `cat $x`
  done

  echo "Cleaning up... "
  rm -rf $IDIR/tmp/pids/*.pid
}

function kill_all {
  for x  in `pgrep -l -f puma| cut -d ' ' -f 1`;do kill -9 $x;done
  for x  in `pgrep -l -f sidekiq| cut -d ' ' -f 1`;do kill -9 $x;done
}

function status_server {
  # Puma
  if [ -f $IDIR/tmp/pids/intrigue-puma.pid ]; then
    echo "Puma running"
  else
    echo "Puma not running"
  fi
}

# Carry out specific functions when asked to by the system
case "$1" in
  status)
    status_server
    ;;
  start)
    echo "Starting intrigue-core processes (waiting 10 seconds...)"
    sleep 10
    setup_server
    start_server
    ;;
  stop)
    echo "Stopping intrigue-core processes"
    stop_server
    ;;
  restart)
    echo "Restarting intrigue-core"
    stop_server
    start_server
    ;;
  killall)
    echo "ALERT! Killing all ruby and sidekiq processes! This command is system-wide, so use with caution!"
    kill_all
    ;;
  *)
    echo "Usage: control.sh {start|stop|restart|killall}"
    exit 1
    ;;
esac

exit 0
