#!/bin/bash
#
# cleanup linkout file downloaded from WINDOWS MSSQL 
# 
#   convert '|' to \n
#   remove  '\r' 
#

# parse args
if [[ -z "$1" ]]; then 
    SRC="ncbi_linkout_msl37.ft.txt"
    DEST=$(basename $SRC .txt)
    echo "SRC defaulting to $SRC"
else 
    SRC=$1; shift; DEST="ictv.ft"
    echo "SRC=$SRC"
fi

echo " "
echo "# cleaning $SRC into $DEST" 
echo sed -e "'s/|/\n/g;s/\r//g;'" $SRC ">" $DEST
sed -e 's/|/\n/g;s/\r//g;' $SRC > $DEST

echo " "
echo "# strip Windows UTF-8 (BOM)"
dos2unix $DEST

echo " "
echo "# verify" 
file $DEST

echo " "
echo "# now upload to ictv@ftp-private.ncbi.nlm.nih.gov/holdings"
echo " "

