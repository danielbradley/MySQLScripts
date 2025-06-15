#!/bin/bash

#
#   Usage:
#
#   a)  ./backup.sh  <DB HOST> <DB NAME> [BACKUP DIR] --defaults /home/ubuntu/conf/mysql.cnf --encrypt /home/ubuntu/conf/mcrypt.cnf --exclude base_exceptions
#   b)  ./install.sh <DB HOST> <DB NAME> <DB Backup>
#   c)  ./mysql.sh   <DB HOST> [USER]
#

         EXE="$0"
        FULL=`RealPath "$EXE"`
        NAME=`basename "$EXE"`
          SH=`dirname  "$FULL"`
       SHARE=`dirname  "$SH"`
        BASE=`dirname  "$SHARE"`
        DATE=`date +%Y-%m-%d`
       MYSQL=`which mysql`
   MYSQLDUMP=`which mysqldump`
      OSNAME=`uname`
         CPU=`uname -m`
     VERSION=`cat VERSION`
     SSL_DIR="share/ssl"
  DB_INSTALL=""
    DEFAULTS=""
     ENCRYPT=""
       FLAGS=""
 EXTRA_FLAGS=""

BACKUP_FLAGS=""
BACKUP_FLAGS+=" --column-statistics=0" # Does not attempt to retrieve statistics which causes errors for older MySQL versions.
BACKUP_FLAGS+=" --lock-tables"         # Lock all tables before dumping them (of only specified database).
BACKUP_FLAGS+=" --complete-insert"     # Use complete INSERT statements that include column names.
BACKUP_FLAGS+=" --replace"             # Write REPLACE statements rather than INSERT statements.
BACKUP_FLAGS+=" --extended-insert"     # Use multiple-row INSERT syntax
BACKUP_FLAGS+=" --no-tablespaces"      # Do not write any CREATE LOGFILE GROUP or CREATE TABLESPACE statements in output
BACKUP_FLAGS+=" --set-gtid-purged=OFF" # Whether to add SET @@GLOBAL.GTID_PURGED to output (prevents this).
BACKUP_FLAGS+=" --single-transaction"  # Issue a BEGIN SQL statement before dumping data from server

DATAONLY_FLAGS=""
BACKUPALL_FLAGS+=" --routines"            # Dump stored routines (procedures and functions) from dumped databases
BACKUP_SUFFIX="full"

function Usage()
{
    if   [ "$NAME" = "backup.sh"  ]
    then
        echo "Usage: ./backup.sh <DB HOST> <DB NAME> [BACKUP DIR] [--data-only] [--defaults <config>] [--encrypt <encrytion>] [...]"

    elif [ "$NAME" = "install.sh" ]
    then
        echo "Usage: ./install.sh <DB HOST> <DB NAME> [BACKUP FILE]"

    elif [ "$NAME" = "mysql.sh"   ]
    then
        echo "Usage: ./mysql.sh <DB HOST> [DB USER=root]"
    fi

    exit -1
}

function Main()
{
    if   [ "YES" = `IsInvalidDBHost` ]
    then
        echo "ERROR: could not resolve: ${DB_HOST}/"
        Usage

    elif [ -z "$DB_NAME" -a "$NAME" != "mysql.sh" ]
    then
        echo "ERROR: no database name specified for: ${NAME}"
        Usage

    elif [ "YES" = `IsInvalidProg` ]
    then

        case "$NAME" in
            "backup.sh")
                echo "ERROR: could not locate 'mysqldump'"
                ;;
            *)
                echo "ERROR: could not locate 'mysql'"
                ;;
        esac

        Usage

    elif [ "$NAME" = "backup.sh" -a ! -d "$DB_BACKUP" ]
    then
        echo "ERROR: database backup directory does not exist: ${DB_BACKUP}"
        Usage

    elif [ "$NAME" = "install.sh" -a -n "$DB_BACKUP" -a ! -f "$DB_BACKUP" ]
    then
        echo "ERROR: database backup file does not exist: ${DB_BACKUP}"
        Usage

    else

        FLAGS=`ConfigureFlags`

        if [ -z "$FLAGS" ]
        then
            echo "ERROR: could not find key/cert for remote database host in: share/ssl/${DB_HOST}/"
            Usage
        fi

        if   [ "$NAME" = "backup.sh" ]
        then
            Backup  "${FLAGS}"

        elif [ "$NAME" = "install.sh" ]
        then
            Install "${FLAGS}"

        elif [ "$NAME" = "mysql.sh" ]
        then
            MySQL   "${FLAGS}"

        fi
    fi
}

function IsInvalidDBHost()
{
    local invalid="No"

    if [ -n "$CNAME" -a "$CNAME" != "${CNAME/./}" ]
    then
	echo "Looking up DNS for: $CNAME"

        local check=`dig +short $CNAME`

        if [ -z "$check" ]
        then
            invalid="YES"
        fi
    fi

    echo "${invalid}"
}

function IsInvalidProg()
{
    local invalid="No"

    if [ ! -x $MYSQL -o ! -x $MYSQLDUMP ]
    then
        invalid="YES"

    fi

    echo "${invalid}"
}

function ConfigureFlags()
{
    local flags=""

    if [ -z "$DB_USER" ]
    then
        DB_USER="root"
    fi

    if [ -z "$DEFAULTS" ]
    then
        flags+=" -u ${DB_USER} -p${password}"

    else
        flags+=" $DEFAULTS"

    fi

    flags+=" --compress"

    if [ -n "$CNAME" ]
    then

        if [ "$CNAME" != "${CNAME/.amazonaws.com/}" -a "$CNAME" == "${CNAME/ec2-/}" ]
        then
            flags+=" -h ${CNAME}"
            flags+=" --ssl-ca=${SSL_DIR}/amazonaws.com/rds-combined-ca-bundle.pem"
            flags+=" --ssl-mode=VERIFY_IDENTITY"

        elif [ -f "share/ssl/${DB_HOST}/server-ca.pem" ]
        then
            flags+=" -h ${DB_HOST}"
            flags+=" --ssl-ca=${SSL_DIR}/${DB_HOST}/server-ca.pem"
            flags+=" --ssl-key=${SSL_DIR}/${DB_HOST}/client-key.pem"
            flags+=" --ssl-cert=${SSL_DIR}/${DB_HOST}/client-cert.pem"

        else
            flags+=" -h ${DB_HOST}"
        fi

        Error "CNAME:  ${CNAME}"
        Error "DBHost: ${DB_HOST}"

    else
        flags+=" -h ${DB_HOST}"
    fi

    echo $flags
}

function Backup()
{
    local flags="$1 $2"

    echo "${MYSQLDUMP} ${flags} ${BACKUP_FLAGS} ${DATAONLY_FLAGS} ${BACKUPALL_FLAGS} $DB_NAME --force $EXTRA_FLAGS >  ${DB_BACKUP}/${DB_HOST}-${DB_NAME}-${BACKUP_SUFFIX}-${DATE}.sql"
          ${MYSQLDUMP} ${flags} ${BACKUP_FLAGS} ${DATAONLY_FLAGS} ${BACKUPALL_FLAGS} $DB_NAME --force $EXTRA_FLAGS > "${DB_BACKUP}/${DB_HOST}-${DB_NAME}-${BACKUP_SUFFIX}-${DATE}.sql"
}

function Install()
{
    local flags="$1 $2"

    echo "create database ${DB_NAME}; use ${DB_NAME};  | cat - ${DB_INSTALL} ${DB_BACKUP} | ${MYSQL} ${flags} $EXTRA_FLAGS"
    echo "create database ${DB_NAME}; use ${DB_NAME};" | cat - ${DB_INSTALL} ${DB_BACKUP} | ${MYSQL} ${flags} $EXTRA_FLAGS
}

function MySQL()
{
    local flags="$1 $2"

    echo "${MYSQL} ${flags} $EXTRA_FLAGS"
          ${MYSQL} ${flags} $EXTRA_FLAGS
}

function ABSPath()
{
        local abs=$( cd "$(dirname $1)"; pwd -P )
        local name=`basename $1`
        echo "$abs/$name"
}

function LinkPath()
{
    local dirname=`dirname $1`
    local linkpath=`readlink $1`

    if [ -z "$linkpath" ]
    then
        echo $1
    
    elif [ "/" == "${linkpath:0:1}" ]
    then
        echo $linkpath

    else
        echo $dirname/$linkpath

    fi
}

function RealPath()
{
        local abspath=`ABSPath $1`
        local lnkpath=`LinkPath $abspath`

        echo $lnkpath
}

function Error()
{
    echo $@ 1>&2
}

if [ -z "$MYSQL" ]
then
    if [ "Darwin" = "$OSNAME" ]
    then
        MYSQL="${BASE}/libexec/mysql/sbin/$OSNAME-$CPU/bin/mysql"
    fi
fi

if [ -z "$MYSQLDUMP" ]
then
    if [ "Darwin" = "$OSNAME" ]
    then
        MYSQLDUMP="${BASE}/libexec/mysql/sbin/$OSNAME-$CPU/bin/mysqldump"
    fi
fi

if [ -z "$DB_BACKUP" -a "$NAME" = "backup.sh" ]
then
    DB_BACKUP="./_bak"
fi

if   [ -d "_install/${VERSION}" ]
then
    DB_INSTALL=`ls _install/${VERSION}/*.sql`

elif [ -d "share/install/${VERSION}" ]
then
    DB_INSTALL=`ls share/install/${VERSION}/*.sql`

fi

#
#   Command-line arguments are processed here.
#

while [ -n "$1" ]
do
    case "$1" in
        "--defaults")
            shift
            if [ -f "$1" ]
            then
                DEFAULTS="--defaults-extra-file $1"
                shift
            else
                echo "ERROR: defaults file does not exist."
                exit -1
            fi
            ;;

        "--encrypt")
            shift
            if [ -f "$1" ]
            then
                ENCRYPT="$1"
                shift
            else
                echo "ERROR: encrypt file does not exist."
                exit -1
            fi
            ;;

        "--data-only")
            shift

            BACKUPALL_FLAGS=""
            DATAONLY_FLAGS=" --no-create-info --skip-triggers"
            BACKUP_SUFFIX="data"
            ;;

        "--no-install")
            shift

            DB_INSTALL=""
            ;;

        "--ssl-dir")
            shift

            if [ -d "$1" ]
            then
                SSL_DIR="$1"

            else
                echo "ERROR: invalid SSL DIR: $1"
                exit -1

            fi
            ;;

        *)
            if [ -z "$DB_HOST" ]
            then
                DB_HOST="$1"
                shift

            elif [ -z "$DB_NAME" -a -z "$DB_USER" ]
            then
                if [ "$NAME" = "mysql.sh" ]
                then
                    DB_USER="$1"
                else
                    DB_NAME="$1"
                fi
                shift

            elif [ -z "$DB_BACKUP" ]
            then
                DB_BACKUP="$1"
                shift

            else
                EXTRA_FLAGS+=" $1"
                shift
            fi
            ;;
    esac

    if [ -n "$DB_HOST" -a "$DB_HOST" != "${DB_HOST/./}" ]
    then
        CNAME=`dig +short $DB_HOST | head -1 | sed 's/\.$//'`
    fi

done

Main
