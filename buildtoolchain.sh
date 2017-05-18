#!/bin/sh
# Copyright (c) 2014, A.Haarer, All rights reserved. LGPLv3

# build 68k cross toolchain based on gcc
# set the number of make jobs as appropriate for build machine
# set the path after installation : export PATH=/opt/m68k/bin:$PATH

# first version gcc 5 (tested on debian wheezy, may 2015)
# in may 2017 reworked using MSYS2
# links:
#   http://www.mikrocontroller.net/articles/GCC_M68k
#   https://gcc.gnu.org/install/index.html
#   https://gcc.gnu.org/install/prerequisites.html
#   https://gcc.gnu.org/wiki/FAQ#configure
#   http://www.msys2.org/

# MSYS2 package requirements
# flex bison diffutils texinfo make
# mingw-w64-x86_64-gcc  
# mingw-w64-x86_64-libmangle-git 
# mingw-w64-x86_64-make
# mingw-w64-x86_64-pkg-config
# mingw-w64-x86_64-tools-git
# mingw-w64-x86_64-winstorecompat-git



# to speed up things:  chose a location without 
# - indexing (dont use windows home dir or a
# - virus scanner ( add exclusion)
#
LOGFILE="`pwd`/buildlog.txt"
#set the number of parallel makes
MAKEJOBS=4


function log_msg () {
    local logline="`date` $1"
    echo $logline >> $LOGFILE
    echo $logline
}

#todo, consider this
#fullfile="stuff.tar.gz"
#fileExt=${fullfile#*.}
#fileName=${fullfile%*.$fileExt}

function prepare_source () {
    local BASEURL=$1
    local SOURCENAME=$2
    local ARCHTYPE=$3

    if [ ! -f $SOURCENAME.$ARCHTYPE ]; then
        log_msg " downloading $SOURCENAME"
        wget $BASEURL/$SOURCENAME.$ARCHTYPE
        log_msg " downloading $SOURCENAME finished"
    else
        log_msg " downloading $SOURCENAME skipped"
    fi

    if [ ! -d $SOURCENAME ]; then
        log_msg " unpacking $SOURCENAME"
        if [ "$ARCHTYPE" == "tar.bz2" ]; then
            tar -xjf $SOURCENAME.$ARCHTYPE 
        elif [ "$ARCHTYPE" = "tar.gz" ]; then
            tar -xzf $SOURCENAME.$ARCHTYPE 
        elif [ "$ARCHTYPE" = "tar.xz" ]; then
            tar -xJf $SOURCENAME.$ARCHTYPE 
        else
            log_msg " !!!!! unknown archive format"
            exit 1
        fi
        log_msg " unpacking $SOURCENAME finished"
    else
        log_msg " unpacking $SOURCENAME skipped"
    fi
    cd $SOURCENAME

    if [ ! -d m68k-obj ]; then
        mkdir m68k-obj
    fi	
    cd m68k-obj

}

function conf_compile_source () {
    local SOURCEPACKAGE=$1
    local DETECTFILE=$2
    local CONFIGURESTRING=$3

    if [ ! -f $DETECTFILE ]; then
        log_msg "configuring $SOURCEPACKAGE"
        ../configure $CONFIGURESTRING
        log_msg "configuring $SOURCEPACKAGE finished"

        log_msg "building $SOURCEPACKAGE"
        make -j $MAKEJOBS
        log_msg "building $SOURCEPACKAGE finished"

        log_msg "install $SOURCEPACKAGE"
        make install
        log_msg "install $SOURCEPACKAGE finished"
    else
        log_msg "configuring, compiling and install $SOURCEPACKAGE skipped"
    fi

}


log_msg " start of buildscript"

if [ ! -d cross-m68k ]; then
	mkdir cross-m68k
fi

cd cross-m68k

M68KBUILD=`pwd`
echo "build path:" $M68KBUILD

#export PATH=/opt/m68k/bin:$PATH

#----------------------------------------------------------------------------------

log_msg ">>>> build binutils"
BINUTILS="binutils-2.25"

prepare_source http://ftp.gnu.org/gnu/binutils  $BINUTILS tar.bz2

conf_compile_source binutils "/opt/m68k/bin/m68k-elf-objcopy.exe" "--target=m68k-elf --prefix=/opt/m68k/" 

cd $M68KBUILD

#---------------------------------------------------------------------------------
# build gcc

log_msg ">>>> build gcc"
GCCVER="gcc-7.1.0"

prepare_source ftp://ftp.gwdg.de/pub/misc/gcc/releases/$GCCVER $GCCVER tar.bz2

if [ ! -d ../gmp ]; then
    log_msg "fetching gcc prerequisites"
    cd ..
    ./contrib/download_prerequisites
    cd m68k-obj
fi

conf_compile_source gcc "/opt/m68k/bin/m68k-elf-gcov.exe" "--target=m68k-elf --prefix=/opt/m68k/ --enable-languages=c,c++ --disable-bootstrap --with-newlib --disable-libmudflap --disable-libssp --disable-libgomp --disable-libstdcxx-pch --disable-threads --with-gnu-as --with-gnu-ld --disable-nls --with-headers=yes --disable-checking --without-headers"

cd $M68KBUILD

#---------------------------------------------------------------------------------
#build libc

log_msg ">>>> build newlib"
LIBCVER="newlib-2.5.0"

prepare_source ftp://sources.redhat.com/pub/newlib $LIBCVER tar.gz

export PATH=$PATH:/opt/m68k/bin/

conf_compile_source newlib "/opt/m68k/m68k-elf/lib/mfidoa/softfp/libc.a" " --target=m68k-elf --prefix=/opt/m68k/ --enable-newlib-reent-small --disable-malloc-debugging --enable-newlib-multithread --disable-newlib-io-float --disable-newlib-supplied-syscalls --disable-newlib-io-c99-formats --disable-newlib-mb --disable-newlib-atexit-alloc --enable-target-optspace --disable-shared --enable-static --enable-fast-install"

cd $M68KBUILD
 

#erst mal ohne gdb

#---------------------------------------------------------------------------------
#build gdb
#sudo apt-get install ncurses-dev
GDBVER="gdb-7.12"

log_msg ">>>> build gdb"
prepare_source http://ftp.gnu.org/gnu/gdb $GDBVER tar.xz

conf_compile_source gdb "/opt/m68k/bin/m68k-elf-gdb.exe" "--target=m68k-elf --prefix=/opt/m68k/"

cd $M68KBUILD
exit

# musasim bauen
# https://code.google.com/p/musasim/
#apt-get install libsdl2-dev
#apt-get install libargtable2-dev
#apt-get install libfontconfig-dev
#apt-get install libelf-dev

# dafür braucht man auch libsdl2 ttf die bei debian nicht im repo ist - suxx
#wget https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.12.tar.gz
#tar xvzf SDL2_ttf-2.0.12.tar.gz
#cd SDL2_ttf-2.0.12/
#./configure
#make
#sudo make install


#git clone https://code.google.com/p/musasim/
#cd muasim
#./bootstrap.sh
#cd musasim
## vorher in verzeichnis ui das makefile fixen, es fehlt `pkg-config --cflags SDL2_ttf` bei den cflags
#make 
