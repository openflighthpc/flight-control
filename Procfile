web: bin/rails server -p $PORT -e $RAILS_ENV
resque: env TERM_CHILD=1 COUNT=5 QUEUE=high,medium,low rake resque:workers
cron: sleep infinity
