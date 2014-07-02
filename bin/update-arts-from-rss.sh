#!/bin/bash
#
# Script to fetch the lists of recent and upcoming articles from the elife journal
# RSS feed and submit the lists to the ALM server so it can start looking for them
#
# Created 1 Jul 2014 Ruth Ivimey-Cook
#
# Version 1.0:  1 Jul 2014 - basic invocation of xslt and db:articles:load
# Version 1.1:  1 Jul 2014 - hardened w.r.t. environment, included difference code


# Get the folder that contains this script, which is also where we expect the XSL
# file to be. See:
# http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself#4774063
pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

# Bundle, Rake tools are in /usr/local/bin
export PATH=/usr/local/bin:${PATH}
export RAILS_ENV=production
almdir=/var/www/alm/shared
bundle=/usr/local/bin/bundle
xsltproc=/usr/bin/xsltproc
comm="comm -13"
xsltransform=${SCRIPTPATH}/rss-to-almdoi.xsl 
# Where we keep intermediate files, including the previous
# run for comparisons
tmpdir=/tmp/rssfeed
oldsfx=-old
newsfx=-cur
chgsfx=-changes

mkdir -p ${tmpdir}

curl -s "http://elifesciences.org/rss/recent.xml" | ${xsltproc} "${xsltransform}" -   | sort > "${tmpdir}/recent${newsfx}.txt"
curl -s "http://elifesciences.org/rss/ahead.xml" | ${xsltproc} "${xsltransform}"  -   | sort > "${tmpdir}/ahead${newsfx}.txt"

echo `date` Changes in Recent:
if [ -s "${tmpdir}/recent${oldsfx}.txt" ] ; then
  diff "${tmpdir}/recent${oldsfx}.txt" "${tmpdir}/recent${newsfx}.txt" 
  ${comm} "${tmpdir}/recent${oldsfx}.txt" "${tmpdir}/recent${newsfx}.txt" > "${tmpdir}/recent${chgsfx}.txt"
else
  echo `date` No old file found.
fi
echo `date` Changes in Ahead:
if [ -s "${tmpdir}/ahead${oldsfx}.txt" ] ; then
  diff "${tmpdir}/ahead${oldsfx}.txt" "${tmpdir}/ahead${newsfx}.txt" 
  ${comm} "${tmpdir}/ahead${oldsfx}.txt" "${tmpdir}/ahead${newsfx}.txt" > "${tmpdir}/ahead${chgsfx}.txt"
else
  echo `date` No old file found.
fi
echo `date` End Changes.

cd ${almdir}
echo `date` Loading Recent titles:
if [ -s "${tmpdir}/recent-changes.txt" ] ; then
  ${bundle} exec rake db:articles:load < "${tmpdir}/recent-changes.txt"
else
  echo `date` No changes found.
fi
echo `date` Loading Ahead titles:
if [ -s "${tmpdir}/ahead-changes.txt" ] ; then
  ${bundle} exec rake db:articles:load < "${tmpdir}/ahead-changes.txt"
else
  echo `date` No changes found.
fi

# Rename current file to previous ready for next call
mv "${tmpdir}/recent${newsfx}.txt" "${tmpdir}/recent${oldsfx}.txt"
mv "${tmpdir}/ahead${newsfx}.txt" "${tmpdir}/ahead${oldsfx}.txt"

# Delete the differences files
#rm -f "${tmpdir}/recent${chgsfx}.txt"
#rm -f "${tmpdir}/ahead${chgsfx}.txt"

echo `date` Done.
exit 0
