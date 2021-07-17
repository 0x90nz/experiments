#!/bin/sh

# quite possibly the most convoluted, unreliable and dangerous way to kill a
# process!
#
# in essence this works by finding the mappings of a process from /prov/$PID/map
# and then writing garbage into the stack area.
#
# at some point the process will encounter random data in the stack and either
# fail an internal consistency check or more likely try to return to a random
# address. either way it will raise a SIGSEV and the process will likely exit.
#
# obviously if the process implements some kind of handling for a SIGSEV signal
# this might not cause an immediate exit, but hopefully a completely garbled
# stack is sufficient to make even the most hardy software give up any hope
# recovery :)
#
# example:
# ./destroy.sh $(pidof vim)
#
# note: you need permissions to write to another processes address space, which
# is likely not allowed on normal proceses. you'll need to take whatever
# measures your system requires to allow this script to work.


if [ $# -ne 1 ]; then
	echo "Usage: $0 PID"
	exit 1
fi

TARGET_PID=$1

if [ ! -d /proc/$TARGET_PID ]; then
	echo "No program with PID $TARGET_PID"
	exit 1
fi

read -r STACK_START STACK_END <<EOF
$(cat /proc/$TARGET_PID/maps | awk -F'[ -]' '/stack/ { print "0x" $1 " 0x" $2 }')
EOF

PAGE_SIZE=$(getconf PAGE_SIZE)
PGOFFSET=$(($STACK_START / $PAGE_SIZE))
PGLEN=$((($STACK_END - $STACK_START) / $PAGE_SIZE))

echo "* destroying stack for PID $TARGET_PID from $STACK_START-$STACK_END"
echo "* starting at $PGOFFSET pages and destroying $PGLEN pages"

# actually do the destruction. we fill by page because it's faster (and also
# far more fun)
dd if=/dev/urandom of=/proc/$TARGET_PID/mem \
	seek=$PGOFFSET \
	count=$PGLEN \
	bs=$PAGE_SIZE \
	conv=notrunc >/dev/null 2>&1

# send a SIGCONT signal to the target process.
#
# this does /not/ terminate the process (or at least it won't for most
# processes), all it's here to do is force the program out of any blocked state
# it was in so we can revel in our destruction!!!!
kill -18 $TARGET_PID

