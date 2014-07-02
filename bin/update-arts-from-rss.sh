#!/bin/bash
#
# Script to fetch the lists of recent and upcoming articles from the elife journal
# RSS feed and submit the lists to the ALM server so it can start looking for them
#

tmpdir=/tmp/rssfeed
mkdir -p ${tmpdir}

curl -s http://elifesciences.org/rss/recent.xml |xsltproc rss-to-almdoi.xsl -   >${tmpdir}/recent-arts.txt
curl -s http://elifesciences.org/rss/ahead.xml |xsltproc rss-to-almdoi.xsl  -   >${tmpdir}/ahead.txt

cd /var/www/alm/shared
export RAILS_ENV=production
bundle exec rake db:articles:load <${tmpdir}/recent-arts.txt
bundle exec rake db:articles:load <${tmpdir}/ahead.txt

# Clean up
#rm -f $tmpdir/recent-arts.txt
#rm -f $tmpdir/ahead.txt
