#!/bin/bash

FULL=`realpath $0`
NAME=`basename $0`
SH=`dirname $FULL`
SHARE=`dirname $SH`
BASE=`dirname $SHARE`

HOST=$1
BACKUP=$3
MYSQL=`which mysql`
MYSQLDUMP=`which mysqldump`
OSNAME=`uname`
MODE="???"
DATE=`date +%Y-%m-%d`

if [ "$NAME" = "mysql.sh" ]
then
	MODE="mysql"
	USER=$2

elif [ "$NAME" = "backup.sh" ]
then
	MODE="dump"
	USER=root
	DB=$2

else
	echo "Aborting: call as either 'mysql.sh', or 'backup.sh'"
	exit -1

fi

if [ "" = "$MYSQL" ]
then
	if [ "Darwin" = "$OSNAME" ]
	then
		MYSQL=$(BASE)/libexec/mysql/sbin/$OSNAME/mysql
	else
		echo "Error: could not locate 'mysql'"
		exit -1
	fi
fi

if [ "" = "$MYSQLDUMP" ]
then
	if [ "Darwin" = "$OSNAME" ]
	then
		MYSQLDUMP=$(BASE)/libexec/mysql/sbin/$OSNAME/mysqldump
	else
		echo "Error: could not locate 'mysqldump'"
		exit -1
	fi
fi

if [ "" = "$USER" ]
then
	USER="root"
fi

if [ "" = "$BACKUP" ]
then
	BACKUP="../../bak"
fi

function usage()
{
	if [ "$NAME" = "mysql.sh" ]
	then
		echo "Usage: ./mysql.sh <hostname> [username=root]"

	elif [ "$NAME" = "backup.sh" ]
	then
		echo "Usage: ./backup.sh <hostname> <dbname> [backupdir=../../bak]"

	fi
	exit -1
}

function main()
{
	local ip=`dig +short $HOST`
	local use_ssl="TRUE"
	local flags="--force -u $USER -p"

	if [ "192" = "${ip:0:3}" ]
	then
		use_ssl="FALSE"
	fi

	if [ "TRUE" = "$use_ssl" -a ! -f "share/ssl/${HOST}/server-ca.pem" ]
	then
		echo "ERROR: could not find key/cert for remote database host in: share/ssl/${HOST}/"
		usage

	elif [ "TRUE" = "$use_ssl" ]
	then
		if ["" = "$ip" ]
		then
			echo "ERROR: could not find IP for remote db host: $HOST"
			exit -1
		fi

		flags+="     -h $ip"
		flags+="   --ssl-ca=share/ssl/${HOST}/server-ca.pem"
		flags+="  --ssl-key=share/ssl/${HOST}/client-key.pem"
		flags+=" --ssl-cert=share/ssl/${HOST}/client-cert.pem"

	else
		flags+=" -h ${HOST}"

	fi

	if [ "$NAME" = "mysql.sh" ]
	then
		echo ${MYSQL} ${flags}
		     ${MYSQL} ${flags}

	elif [ "$NAME" = "backup.sh" ]
	then
		flags+=" --column-statistics=0 --lock-tables --no-create-info --complete-insert --replace --set-gtid-purged=OFF --skip-triggers"

		if [ -z "$DB" ]
		then
			echo "Aborting, no database name specified"
			usage
		fi

		if [ ! -d "${BACKUP}" ]
		then
			echo "Aborting, default backup directory does not exist: ${BACKUP}"
			usage
		fi

		echo ${MYSQLDUMP} ${flags} ${DB} \> "${BACKUP}/${HOST}-${DB}-${DATE}.sql"
		     ${MYSQLDUMP} ${flags} ${DB}  > "${BACKUP}/${HOST}-${DB}-${DATE}.sql"
	fi
}

if [ -z "$HOST" ]
then
	usage
	exit -1
else
	main
fi
