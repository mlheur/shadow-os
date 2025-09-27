grep : src/mbr/mbr.S | awk -F : '{print $1}' | egrep -e '^[_a-zA-Z0-9]+$' | sed -e 's/^/            "break *0x7c00+/' -e 's/$/",/'
