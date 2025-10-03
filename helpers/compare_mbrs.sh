SRCDIR=`dirname $0`/..
BINDIR="${SRCDIR}/bin"
DUMPDIR="${SRCDIR}/dumps"


for MBR in "${BINDIR}/"*mbr; do
    OUTF=`basename "${MBR}"`
    hexdump -C "${MBR}" | head -32 > "${DUMPDIR}/${OUTF}.hexdump"
done