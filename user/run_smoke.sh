#!/usr/bin/env bash

CWD=$(pwd)
BIN="$CWD/debug"
SCRIPTS="$CWD/scripts"
DEV="/dev/pmem0"
KMOD="../kmod"
MPT="/mnt/famfs"
MOUNT_OPTS="-t famfs -o noatime -o dax=always "
TEST_ERRORS=1
TEST_ALL=1
SLEEP_TIME=2

# Check if we have password-less sudi, which is required
sudo -n true 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: password-less sudo capability is required to run smoke tests"
fi
# Make famfs is not mounted or loaded
if (( $(grep -c famfs /proc/mounts) > 0)); then
   echo "Error: famfs is mounted, and must be unmounted to run smoke tests; run scripts/teardown.sh"
   exit -1
fi
if (( $(lsmod | grep -c famfs) > 0)); then
    echo "Error: famfs kernel module must be unloaded to run smoke tests; run scripts/teardown.sh"
    exit -1
fi
TEST_FUNCS=$SCRIPTS/test_funcs.sh
if [ ! -f $TEST_FUNCS ]; then
    echo "Can't source $TEST_FUNCS"
    exit -1
fi

while (( $# > 0)); do
    flag="$1"
    shift
    case "$flag" in
	(-d|--device)
	    DEV=$1
	    shift;
	    ;;
	(-n|--noerrors)
	    TEST_ERRORS=0
	    ;;
	(-j|--justerrors)
	    TEST_ERRORS=1
	    TEST_ALL=0
	    ;;
	(-N|--nosleep)
	    SLEEP_TIME=0
	    ;;
	(-r|--release)
	    BIN="$CWD/release"
	    echo "hello release BIN=$BIN"
	    ;;
	(-c|--coverage)
	    BIN="$CWD/coverage"
	    echo "hello coverage BIN=$BIN"
	    ;;
	(-v|--valgrind)
	    echo "run_smoke: valgrind mode"
	    VGARG="--valgrind"
	    ;;
	*)
	    remainder="$flag $1";
	    shift;
	    while (( $# > 0)); do
		remainder="$remainder $1"
		shift
	    done
	    echo "ignoring commandline remainder: $remainder"
	    ;;
    esac
done

CLI="sudo $VG $BIN/famfs"

echo "CWD:         $CWD"
echo "BIN:         $BIN"
echo "SCRIPTS:     $SCRIPTS"
echo "TEST_ERRORS: $TEST_ERRORS"

#BIN=debug
if [ ! -d $BIN ]; then
    echo "Can't find executables"
    exit -1
fi
if [ ! -x "$BIN/famfs" ]; then
    echo "famfs cli missing or not built in subdir $BIN"
    exit -1
fi

source $TEST_FUNCS

if (($TEST_ALL > 0)); then
    ./smoke/test0.sh $VGARG -b $BIN -s $SCRIPTS -d $DEV -k $KMOD  || exit -1
    sleep "${SLEEP_TIME}"
    ./smoke/test1.sh $VGARG -b $BIN -s $SCRIPTS -d $DEV -k $KMOD  || exit -1
    sleep "${SLEEP_TIME}"
    ./smoke/test2.sh $VGARG -b $BIN -s $SCRIPTS -d $DEV -k $KMOD  || exit -1
    sleep "${SLEEP_TIME}"
    ./smoke/test3.sh $VGARG -b $BIN -s $SCRIPTS -d $DEV -k $KMOD  || exit -1
    sleep "${SLEEP_TIME}"
    ./smoke/test4.sh $VGARG -b $BIN -s $SCRIPTS -d $DEV -k $KMOD  || exit -1
fi
if (($TEST_ERRORS > 0)); then
    sleep "${SLEEP_TIME}"

    ./smoke/test_errors.sh  -b $BIN -s $SCRIPTS -d $DEV -k $KMOD  || exit -1
else
    echo "skipping test_errors.sh because -n|--noerrors was specified"
fi

#full_mount $DEV $MPT "${MOUNT_OPTS}" "run_smoke.sh remount"
${CLI} mount $DEV $MPT || fail "run_smoke: famfs mount"

exit 0
#sleep 4
#./scripts/teardown.sh
