#!/bin/sh

cd /mnt/code || exit
if [ "$1" = "+valgrind" ]; then
    eval "$(luarocks path)" && luarocks install busted --deps-mode none && luarocks build --deps-mode none && valgrind --trace-children=yes --track-origins=yes --leak-check=full luarocks test
else
    eval "$(luarocks path)" && luarocks install busted --deps-mode none && luarocks build --deps-mode none && luarocks test
fi
