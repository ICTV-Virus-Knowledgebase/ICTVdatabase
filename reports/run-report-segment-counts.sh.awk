#!/usr/bin/env awk
#
# Data must be sorted on KEY and SEGCT columns
#
# This assumes all columns 1:KEY change value only when KEY changes value
# It then creates a semi-colon seperated list of all observed values of SEGCT column
# for each unique value of 1:KEY.
#
# Used for reporting on ICTV VMR virus segment counts
# 
BEGIN{
    OFS=FS
    debug=0
}
# skip header
(NR==1){print;next}
# init at 1st data line
(NR==2){
    # store the 1:SEGCT columns in a string to output later
    prow=$1; for(i=2;i<SEGCT;i++) prow=prow FS $i
    # init prev key/values
    pkey=$KEY; pval=$SEGCT;
    # init output string for last row
    last=$SEGCT;
    if(debg) {print "#["NR"] prow="prow;}
    next
}
# filter out lines wiht seg_ct=-1 
($SEGCT<1) {
    if(debug){print "#["NR"] ct<1: "$SEGCT};
    next}
# process all other data lines
{
	key=$KEY
	val=$SEGCT
	if(key==pkey){
	    if(debhug) {print "#["NR"] key==pkey ("key")"}
		if(val!=pval) {
			      last=last";"val
			      pval=val
		}
	} else {
	       print prow,last
	       # store the 1:SEGCT columns in a string to output later
	       prow=$1; for(i=2;i<SEGCT;i++) prow=prow FS $i
	       # reset prev key/values and final output string
	       pkey=key
	       pval=val
	       last=val
	}
}

END{
    # if last row print what's buffered.
    if(NR){
	 print prow,last
    }
}
