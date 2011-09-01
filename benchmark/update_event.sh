#!/bin/sh
#/ Usage: update_event
#/ Benchmark the update_event API
set -e

# show program usage
test "$1" == "--help" && {
    grep '^#/' <"$0" |
    cut -c4-
    exit 2
}

for timelines in 10 25 50 100 300; do
  for updates in 10; do # 100 1000
    echo "-----" >> results.txt
    echo "$timelines, $updates" >> results.txt
    ruby -rubygems -Ilib benchmark/update_event.rb $timelines $updates >> results.txt
  done
done

