#!/bin/sh

cd /mnt/code || exit
if [ "$1" = "+valgrind" ]; then
    eval "$(luarocks path)" && luarocks install busted && luarocks build CFLAGS="-O2 -fPIC -g" && valgrind --trace-children=yes --track-origins=yes --leak-check=full luarocks test
else
    eval "$(luarocks path)" && luarocks install busted && luarocks build CFLAGS="-O2 -fPIC -g" && luarocks test
fi
