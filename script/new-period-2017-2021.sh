#!/bin/bash

set -e
set -x

bundle exec script/import parliament-sessions && \
  bundle exec script/import parties && \
  bundle exec rails r script/import-promises-2017 | tee import-r.log  && \
  bundle exec rails r script/upgrade_categories.rb  && \
  bundle exec script/import daily --period 2013-2017 --session 2016-2017  && \
  bundle exec script/import daily --period 2017-2021 --session 2017-2018 && \
  bundle exec rake images:party_logos && \
  bundle exec rake images:all && \
  bundle exec rails r script/remove-promise-duplicates-2017.rb && \
  bundle exec rake search:reindex && \
  bundle exec script/import agreement-stats && \
  bundle exec script/dump-promises.sh > /webapps/files/data/csv/promises.csv
