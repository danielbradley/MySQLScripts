#!/bin/bash
#
#	Build script for building mcrypt for current platform
#

#
#	Software versions
#

MHASH=0.9.9.9
LIBMCRYPT=2.5.8
MCRYPT=2.6.8

ARCH=`uname`
TMP="/tmp/mcrypt-${MCRYPT}"
BUILD="${TMP}/build"
PREFIX="${TMP}/${ARCH}"
CWD=`pwd`
SRC="${CWD}/src"

#
#	Extract archives
#

mkdir -p "${CWD}/bin/${ARCH}" ${BUILD} ${PREFIX}

tar -C ${BUILD}  -xvf "${SRC}/mhash-${MHASH}.tar"
tar -C ${BUILD} -jxvf "${SRC}/libmcrypt-${LIBMCRYPT}.tar.bz2"
tar -C ${BUILD}  -xvf "${SRC}/mcrypt-${MCRYPT}.tar"

#
#	Export common flags
#

export CPPFLAGS="-I${PREFIX}/include"
export LDFLAGS="-L${PREFIX}/lib"
export PATH="$PREFIX/bin:$PATH"

#
#	Build 
#

cd ${BUILD}/mhash-${MHASH}
./configure --prefix=${PREFIX} -disable-shared
make
make install

cd ${BUILD}/libmcrypt-${LIBMCRYPT}
./configure --prefix=${PREFIX} -disable-shared
make
make install

cd ${BUILD}/mcrypt-${MCRYPT}
touch malloc.h
./configure --prefix=${PREFIX}
make
make install

cp ${PREFIX}/bin/mcrypt "$CWD/bin/$ARCH/"

if [ -f "$CWD/bin/$ARCH/mcrypt" ]
then
	rm -rf ${TMP}
fi
