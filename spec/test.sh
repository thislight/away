#!/bin/sh

cd /mnt/code || exit
if [ "$1" = "+valgrind" ]; then
    eval "$(luarocks path)" && luarocks install busted && luarocks build && valgrind --trace-children=yes --track-origins=yes --leak-check=full luarocks test
else
    eval "$(luarocks path)" && luarocks install busted && luarocks build && luarocks test
fi
