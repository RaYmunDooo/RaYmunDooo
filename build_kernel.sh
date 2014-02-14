#!/bin/sh
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/ramdisk`
export USE_SEC_FIPS_MODE=true

if [ "${1}" != "" ];then
    export KERNELDIR=`readlink -f ${1}`
fi

RAMFS_TMP="/home/ray/android/temp/tmp/ramfs-source-sgs3"

.    $KERNELDIR/.config

echo    "...............................................................COMPILAR MODULOS..........................................................."

cd  $KERNELDIR/
make -j2 || exit 1

echo  "............................................................ACTUALIZACION RAMDISK......................................................."
#remove previous ramfs files
rm  -rf    $RAMFS_TMP
rm  -rf    $RAMFS_TMP.cpio
rm  -rf    $RAMFS_TMP.cpio.gz
#copy ramfs files to tmp directory
cp  -ax   $RAMFS_SOURCE $RAMFS_TMP
#clear git repositories in ramfs
find   $RAMFS_TMP  -name    .git      -exec  rm -rf {} \;
#remove empty directory placeholders

find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;

rm -rf $RAMFS_TMP/tmp/*

#remove mercurial repository

rm -rf $RAMFS_TMP/.hg

#copy modules into ramfs

mkdir -p $RAMFS_TMP/lib/modules

find -name '*.ko' -exec cp -av {} $RAMFS_TMP/lib/modules/ \;

${CROSS_COMPILE}strip --strip-unneeded $RAMFS_TMP/lib/modules/*


echo "..................................................CONSTRUCION DE LA NUEVA RAMDISK............................................"

cd $RAMFS_TMP

find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null

ls -lh $RAMFS_TMP.cpio

gzip -9 $RAMFS_TMP.cpio


echo "...............................................................COMPILAONDO KERNEL............................................................"

cd $KERNELDIR

make -j2 zImage || exit 1


echo ".............................................................Making new boot image............................................................"

./mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --board smdk4x12 --base 0x10000000 --pagesize 2048 --ramdiskaddr 0x11000000 -o $KERNELDIR/boot.img

echo ".................................................... Preparando flasheables ................................................................"

cp boot.img $KERNELDIR/releasetools/zip
cp boot.img $KERNELDIR/releasetools/tar

cd $KERNELDIR
cd releasetools/zip
zip -0 -r $CONFIG_LOCALVERSION-$REVISION$KBUILD_BUILD_VERSION-$VERSION_KL.zip *
cd ..
cd tar
tar cf $CONFIG_LOCALVERSION-$REVISION$KBUILD_BUILD_VERSION-$VERSION_KL.tar boot.img && ls -lh $CONFIG_LOCALVERSION-$REVISION$KBUILD_BUILD_VERSION-$VERSION_KL.tar

echo "...................................................... Eliminando restos......................................................."

rm $KERNELDIR/releasetools/zip/boot.img
rm $KERNELDIR/releasetools/tar/boot.img
rm $KERNELDIR/boot.img
rm $KERNELDIR/zImage
rm -rf /home/ray/android/temp/tmp/ramfs-source-sgs3
rm /home/ray/android/temp/tmp/ramfs-source-sgs3.cpio.gz
echo "...................................................Compilacion Terminada..........................................."
