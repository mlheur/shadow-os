grep : src/mbr/*.S /dev/null | awk -F : '{print $2}' | egrep -e '^[_a-zA-Z0-9]+$' 2>/dev/null | sed -e 's/^/            "break *0x7c00+/' -e 's/$/",/'
grep : src/krn/*.S /dev/null | awk -F : '{print $2}' | egrep -e '^[_a-zA-Z0-9]+$' 2>/dev/null | sed -e 's/^/            "break *0x10200+/' -e 's/$/",/'
