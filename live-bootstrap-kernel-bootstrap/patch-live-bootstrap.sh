#!/bin/bash
set -euo pipefail

BUILDROOT=BUILD/live-bootstrap

rm -rf BUILD
mkdir BUILD
cd BUILD

git clone https://github.com/fosslinux/live-bootstrap
cd live-bootstrap
git checkout ae7e1f94983a47279dcdcfc2ac6d8aaa64f25235  # Feb 27, 2023
git submodule update --init --recursive
cd ../..

# For builder-hex0 related patches
cp ../utils/simple-patch.c $BUILDROOT/sysa

# mes: hex conversions and --base-address
cp -rp mes-0.24.2/simple-patches $BUILDROOT/sysa/mes-0.24.2
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../mes-0.24.2/mes-0.24.2.kaem.patch
)

# tcc fixes for builder-hex0 - only write to one file at a time
cp -rp tcc-0.9.26/simple-patches $BUILDROOT/sysa/tcc-0.9.26
cp -rp tcc-0.9.27/simple-patches $BUILDROOT/sysa/tcc-0.9.27
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../tcc-0.9.26/tcc-0.9.26.kaem.patch
patch --no-backup-if-mismatch -p1 < ../../tcc-0.9.27/tcc-0.9.27.kaem.patch
)

# Start by only building up to fiwix, then run the rest on Fiwix.
(
cd $BUILDROOT
cp sysa/run.kaem sysa/run-after-fiwix.kaem
patch --no-backup-if-mismatch -p0 < ../../sysa/run-after-fiwix.kaem.patch
patch --no-backup-if-mismatch -p1 < ../../sysa/run.kaem.patch
)
# This scripts takes over after fiwix boots.
cp sysa/after2.kaem $BUILDROOT/sysa/

# Add Fiwix related software
cp -rp fiwix-1.4.0-lb1 lwext4-1.0.0-lb1 kexec-fiwix $BUILDROOT/sysa/

# Patches needed for Fiwix due to lack of SYS_clone and SYS_set_thread_area
cp musl-1.1.24/patches/* $BUILDROOT/sysa/musl-1.1.24/patches
cp musl-1.1.24/patches/* $BUILDROOT/sysa/musl-1.1.24/patches-pass3
cp -rp musl-1.2.3/patches $BUILDROOT/sysa/musl-1.2.3
# Restore musl-1.2.3 tar file preserved before linux deletes distfiles
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../musl-1.2.3/musl-1.2.3.sh.patch
)

# Rebuild musl with proper thread support (no patches to disable it)
# Do not build curl in sysa - we don't have musl with thread support
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../sysa/run.sh.patch
)
# For curl, we only need to carry over source from sysa to sysc
rm -rf $BUILDROOT/sysa/curl-7.83.0/files
rm -rf $BUILDROOT/sysa/curl-7.83.0/patches
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../sysc/init.patch
)

# Build curl pass1 in sysc - using sysa tools
mv $BUILDROOT/sysa/curl-7.83.0/curl-7.83.0.sh $BUILDROOT/sysc/curl-7.83.0/curl-7.83.0-pass1.sh
mv $BUILDROOT/sysc/curl-7.83.0/curl-7.83.0.sh $BUILDROOT/sysc/curl-7.83.0/curl-7.83.0-pass2.sh
# sysc curl must use tar.gz for first pass, we don't have xz yet
cp $BUILDROOT/sysa/curl-7.83.0/sources $BUILDROOT/sysc/curl-7.83.0
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../sysc/run.sh.patch
patch --no-backup-if-mismatch -p1 < ../../sysc/run2.sh.patch
)

# Add support files for building builder-hex0 file system (srcfs)
mkdir $BUILDROOT/kernel-bootstrap
cp ../modules/builder-hex0/builder-hex0.hex0 $BUILDROOT/kernel-bootstrap/builder-hex0-x86.hex0

# Now patch the live-bootstrap launcher
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../rootfs.py.patch
patch --no-backup-if-mismatch -p1 < ../../sysa.py.patch
)

# new checksums
cp checksums/mes-0.24.2.checksums $BUILDROOT/sysa/mes-0.24.2
cp checksums/tcc-0.9.26.checksums $BUILDROOT/sysa/tcc-0.9.26
cp checksums/tcc-0.9.27.checksums $BUILDROOT/sysa/tcc-0.9.27
cp checksums/make-3.82.checksums $BUILDROOT/sysa/make-3.82
cp checksums/gzip-1.2.4.checksums $BUILDROOT/sysa/gzip-1.2.4
cp checksums/tar-1.12.checksums $BUILDROOT/sysa/tar-1.12
cp checksums/sed-4.0.9.checksums $BUILDROOT/sysa/sed-4.0.9
cp checksums/patch-2.5.9.checksums $BUILDROOT/sysa/patch-2.5.9
cp checksums/bzip2-1.0.8.checksums $BUILDROOT/sysa/bzip2-1.0.8
cp checksums/coreutils-5.0.checksums $BUILDROOT/sysa/coreutils-5.0
cp checksums/heirloom-devtools-070527.checksums $BUILDROOT/sysa/heirloom-devtools-070527
cp checksums/bash-2.05b.checksums $BUILDROOT/sysa/bash-2.05b
cp checksums/SHA256SUMS.pkgs $BUILDROOT/sysa

# Update documentation and licensing
(
cd $BUILDROOT
patch --no-backup-if-mismatch -p1 < ../../parts.rst.patch
patch --no-backup-if-mismatch -p1 < ../../DEVEL.md.patch
patch --no-backup-if-mismatch -p1 < ../../reuse.patch
)

echo "Patched live-bootstrap is in `pwd`/$BUILDROOT"
