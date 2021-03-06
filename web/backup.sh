#!/bin/bash
# exit immediately if a command exits with a nonzero exit status.
set -e
# treat unset variables as an error when substituting.
set -u
# backup
{% set rsync = gpg['rsync'] -%}

#check if the $1 variable is unset
if [ -z ${1+x} ]
#if it is unset
then
    #create a variable called VAR1 and set it to ""
    VAR1=""
#if it is set
else
    #create a variable called VAR1 and set it to = $1
    VAR1=$1
fi

# dump database
DUMP_FILE=/home/web/repo/backup/{{ domain }}/$(date +"%Y%m%d_%H%M").sql
echo "dump database: $DUMP_FILE"
pg_dump -U postgres {{ domain|replace('.', '_') }} -f $DUMP_FILE

# Send a metric to statsd from bash
# nstielau / send_metric_to_statsd.sh
# https://gist.github.com/nstielau/966835
#
# Useful for:
#   deploy scripts (http://codeascraft.etsy.com/2010/12/08/track-every-release/)
#   init scripts
#   sending metrics via crontab one-liners
#   sprinkling in existing bash scripts.
#
# netcat options:
#   -w timeout If a connection and stdin are idle for more than timeout seconds, then the connection is silently closed.
#   -u         Use UDP instead of the default option of TCP.
echo "{{ domain }}.rsync.backup.dump:1|c" | nc -w 1 -u {{ django.monitor }} 2003

# backup database
echo "===================="
echo "duplicity database backup (including any files within the backup folder)"
if [ `date +%d` == "01" ] || [ `date +%d` == "15" ] || [ "$VAR1" == "full" ]
then
    echo "full backup"
    echo "===================="
    # Delete extraneous duplicity files
    PASSPHRASE="{{ rsync['pass'] }}" duplicity cleanup --force scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/backup
    # Delete all full and incremental backup sets older than 12 months
    duplicity remove-older-than 12M --force scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/backup
    # Runs an full backup on the 1st or 15th
    duplicity full --encrypt-key="{{ rsync['key'] }}" /home/web/repo/backup/{{ domain }} scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/backup
    # Delete incremental backups older than the 2nd to last full backup
    duplicity remove-all-inc-of-but-n-full 2 --force scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/backup
else
    echo "incremental backup"
    echo "===================="
    # Runs an incremental backup on days other than the 1st or 15th
    PASSPHRASE="{{ rsync['pass'] }}" duplicity incr --encrypt-key="{{ rsync['key'] }}" /home/web/repo/backup/{{ domain }} scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/backup
fi

echo "{{ domain }}.rsync.backup:1|c" | nc -w 1 -u {{ django.monitor }} 2003

# echo "duplicity database backup verify (including any files within the backup folder)"
# PASSPHRASE="{{ rsync['pass'] }}" duplicity verify scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/backup /home/web/repo/backup/{{ domain }}

# echo "{{ domain }}.rsync.backup.verify:1|c" | nc -w 1 -u {{ django.monitor }} 2003

# backup files
echo "===================="
echo "duplicity files backup"
if [ `date +%d` == "01" ] || [ "$VAR1" == "full" ] 
then
    echo "full backup"
    echo "===================="
    # Delete extraneous duplicity files
    PASSPHRASE="{{ rsync['pass'] }}" duplicity cleanup --force scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/files
    # Delete all full and incremental backup sets older than 3 months
    duplicity remove-older-than 3M --force scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/files
    # Runs an full backup on the 1st
    duplicity full --encrypt-key="{{ rsync['key'] }}" /home/web/repo/files/{{ domain }} scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/files
    # Delete incremental backups older than the last full backup
    duplicity remove-all-inc-of-but-n-full 1 --force scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/files
else
    echo "incremental backup"
    echo "===================="
    # Runs an incremental backup on days other than the 1st
    PASSPHRASE="{{ rsync['pass'] }}" duplicity incr --encrypt-key="{{ rsync['key'] }}" /home/web/repo/files/{{ domain }} scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/files
fi

echo "{{ domain }}.rsync.files:1|c" | nc -w 1 -u {{ django.monitor }} 2003

# Not sure that verify this way is a good idea.  Lots of bandwidth etc.
# echo "duplicity files - verify"
# PASSPHRASE="{{ rsync['pass'] }}" duplicity verify scp://{{ rsync['user'] }}@{{ rsync['server'] }}/{{ domain }}/files /home/web/repo/files/{{ domain }}

# echo "{{ domain }}.rsync.files.verify:1|c" | nc -w 1 -u {{ django.monitor }} 2003

# remove database dump
echo "remove: $DUMP_FILE"
rm $DUMP_FILE
