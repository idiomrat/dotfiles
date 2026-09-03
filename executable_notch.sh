#!/bin/sh
# Restart the notch launcher without pkill matching its own invoking
# shell. This must be run AS A FILE (not inlined into a "Command" field
# as a single string) -- if the pkill/qs commands appear as literal text
# in the invoking process's own command line, `pkill -f` will match and
# kill that shell before it reaches the `qs` line, and the launcher will
# never (re)start, even when nothing was running yet.
pkill -f 'qs -c notch-launcher' 2>/dev/null
sleep 0.3
exec qs -c notch-launcher
