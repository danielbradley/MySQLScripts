#!/bin/bash

COLUMN_STATISTICS_FLAG=""

if [ "$1" = "--ignore-column-statistics" ]
then
	COLUMN_STATISTICS="--column-statistics=0"
	shift
fi

function abspath()
{
        local abs=$( cd "$(dirname $1)"; pwd -P )
        local name=`basename $1`
        echo "$abs/$name"
}

function lnkpath()
{
        local dirname=`dirname $1`
        local linkpath=`readlink $1`

        if [ -z "$linkpath" ]
        then
                echo $1

        else
                echo $dirname/$linkpath
        fi
}

function realpath()
{
        local abspath=`abspath $1`
        local lnkpath=`lnkpath $abspath`

        echo $lnkpath
}

FULL=`realpath "$0"`
NAME=`basename "$0"`
SH=`dirname "$FULL"`
SHARE=`dirname "$SH"`
BASE=`dirname "$SHARE"`

HOST="$1"
BACKUP="$3"
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

	if [ "" = "$BACKUP" ]
	then
		BACKUP="../../bak"
	fi

elif [ "$NAME" = "install.sh" ]
then
	MODE="install"
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
		MYSQL=${BASE}/libexec/mysql/sbin/$OSNAME/mysql
	else
		echo "Error: could not locate 'mysql'"
		exit -1
	fi
fi

if [ "" = "$MYSQLDUMP" ]
then
	if [ "Darwin" = "$OSNAME" ]
	then
		MYSQLDUMP=${BASE}/libexec/mysql/sbin/$OSNAME/mysqldump
	else
		echo "Error: could not locate 'mysqldump'"
		exit -1
	fi
fi

if [ "" = "$USER" ]
then
	USER="root"
fi

function usage()
{
	if [ "$NAME" = "mysql.sh" ]
	then
		echo "Usage: ./mysql.sh <hostname> [username=root]"

	elif [ "$NAME" = "backup.sh" ]
	then
		echo "Usage: ./backup.sh <hostname> <dbname> [backup dir=../../bak]"

	elif [ "$NAME" = "install.sh" ]
	then
		echo "Usage: ./install.sh <hostname> <dbname> [backup file]"

	fi
	exit -1
}

function main()
{
	local ip=`dig +short $HOST | head -1 | sed 's/\.$//'`
	local use_ssl="TRUE"
	local flags="--force -u $USER -p"
	local version=`cat VERSION`
	local install=`ls _install/${version}/*.sql`

	if [ "192" = "${ip:0:3}" -o "127" = "${ip:0:3}" ]
	then
		use_ssl="FALSE"
	fi

	if [ "TRUE" = "$use_ssl" ]
	then
		if [ ! -f "share/ssl/${HOST}/server-ca.pem" -a ! -f "share/ssl/${HOST}/rds-combined-ca-bundle.pem" ]
		then
			echo "ERROR: could not find key/cert for remote database host in: share/ssl/${HOST}/"
			usage

		elif [ "" = "$ip" ]
		then
			echo "ERROR: could not find IP for remote db host: $HOST"
			exit -1

		elif [ -f "share/ssl/${HOST}/rds-combined-ca-bundle.pem" ]
		then
			flags+="         -h $ip"
	                flags+="   --ssl-ca=share/ssl/${HOST}/rds-combined-ca-bundle.pem"
			flags+=" --ssl-mode=VERIFY_IDENTITY"

		elif [ -f "share/ssl/${HOST}/server-ca.pem" ]
		then
			flags+="         -h $ip"
			flags+="   --ssl-ca=share/ssl/${HOST}/server-ca.pem"
			flags+="  --ssl-key=share/ssl/${HOST}/client-key.pem"
			flags+=" --ssl-cert=share/ssl/${HOST}/client-cert.pem"

		fi

	else
		flags+=" -h ${HOST}"

	fi

	if [ "$NAME" = "mysql.sh" ]
	then
		echo ${MYSQL} ${flags}
		     ${MYSQL} ${flags}

	elif [ "$NAME" = "backup.sh" ]
	then
		flags+=" -f ${COLUMN_STATISTICS} --lock-tables --no-create-info --complete-insert --replace --set-gtid-purged=OFF --skip-triggers"

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

	elif [ "$NAME" = "install.sh" ]
	then

		if [ -z "$DB" ]
		then
			echo "Aborting, no database name specified"
			usage
		fi

		if [ ! -f "${install}" ]
		then
			echo "Aborting, no install sql found in: _install/${version}/"
			usage
		fi

		if [ -n "$BACKUP" -a ! -f "$BACKUP" ]
		then
			echo "Aborting, specified backup file not found: $BACKUP"
			usage
		fi

		if [ -n "$BACKUP" ]
		then
			echo "create database ${DB} CHARACTER SET=utf8; use ${DB};" | cat - "${install}" "${BACKUP}" | ${MYSQL} ${flags} 2>&1
		else
			echo "create database ${DB} CHARACTER SET=utf8; use ${DB};" | cat - "${install}"             | ${MYSQL} ${flags} 2>&1
		fi

	fi
}

if [ -z "$HOST" ]
then
	usage
	exit -1
else
	main
fi
