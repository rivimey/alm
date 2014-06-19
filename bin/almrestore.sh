#!/bin/bash
# Restore script for ALM server

if [ `whoami` != 'root' ]; then
    echo "This script must be run as root."
    exit 1
fi

if [ `which s3cmd` = '' ]; then
    apt-get --yes install s3cmd
fi

s3file=$1

export TZ=GMT0BST

install_dir=/var/www/alm/shared
restore_save=/tmp/pre_restore_save
restore_root=/tmp/restore

s3access=`grep -oP "(?<=\"s3access\": \")[^\"]+" $install_dir/config.json`
s3secret=`grep -oP "(?<=\"s3secret\": \")[^\"]+" $install_dir/config.json`
s3bucket=`grep -oP "(?<=\"s3bucket\": \")[^\"]+" $install_dir/config.json`

couch_url="http://localhost:5984"
couch_name=alm
couch_dir=/var/lib/couchdb

s3cmd info $s3file 2>/dev/null | grep File
if  [ $? != 0 ]; then
    echo "Error: expected first arg to be an S3 URL to restore from, for example s3://elife-bucket/dir/file.tgz"
    echo "Got: $s3file "
    exit 1
fi

mkdir -p $restore_save
mkdir -p $restore_root/current

rm -f $restore_root/restore.tgz
s3cmd --access_key="$s3access" --secret_key="$s3secret" get $s3file "$restore_root/restore.tgz"

# unpack the files to the restore directory
tar xfz "$restore_root/restore.tgz" -C $restore_root

# Recover the state: prod/stage
export RAILS_ENV=`echo $restore_root/${couch_name}_*.sql |sed -ne 's/.*alm_\([^_]*\)_.*\.sql/\1/p'`
echo Restoring a $RAILS_ENV backup.

#take a local copy of things we are about to change...
rsync $couch_dir/${couch_name}.couch $restore_save/${couch_name}.couch
mysqldump -uroot -pLFMxwQKHDt9pe9t alm_$RAILS_ENV >$restore_save/current/alm.sql
rsync $install_dir/config.json $restore_save/
rsync $install_dir/config/settings.yml $restore_save/
rsync $install_dir/config/database.yml $restore_save/
rsync $install_dir/config/deploy/*.rb $restore_save/
rsync $couch_dir/${couch_name}.couch $restore_save/

# stop/restart the service to avoid inconsistency
starttime=`date +%s`
service apache2 stop

mysql -uroot -pLFMxwQKHDt9pe9t alm_$RAILS_ENV  < $restore_root/${couch_name}_*.sql

rsync $restore_root/config.json $install_dir/config.json
rsync $restore_root/settings.yml $install_dir/config/settings.yml
rsync $restore_root/database.yml $install_dir/config/database.yml
rsync $restore_root/$RAILS_ENV.rb $install_dir/config/deploy/$RAILS_ENV.rb
rsync $restore_root/${couch_name}_$RAILS_ENV_*.couch $couch_dir/${couch_name}.couch

# can restart the service now
service apache2 start
endtime=`date +%s`

echo Restore took $((endtime - starttime)) seconds

echo Info: Config and database files left in $restore_save for reference

exit 0

