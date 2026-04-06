#!/usr/bin/env bash
#
# tabulate segment counts for each SPECIES
#
IN_VMR_TSV=../data/vmr_export.utf8.txt
echo IN_VMR_TSV=$IN_VMR_TSV
RAW_CT_FILE=vmr_export.isolate_seg_counts.tsv
echo RAW_CT_FILE=$RAW_CT_FILE

OUT_SPECIES_CTS=vmr-species-seg-counts.tsv
OUT_SPECIES_CTS_VAR=vmr-species-seg-counts.var.tsv
OUT_GENUS_CTS=vmr-genus_seg-counts.tsv
OUT_GENUS_CTS_VAR=vmr-genus_seg-counts.var.tsv
OUT_FAMILY_CTS=vmr-family-seg-counts.tsv
OUT_FAMILY_CTS_VAR=vmr-family-seg-counts.var.tsv

# count segments per isolate

# extract 
#     species_sort (depth first taxonomy traversal order)
#     Lineage
#     ICTV species links
#     number of segments
# this will have one row per isolate. 
echo "Reading $(wc -l $IN_VMR_TSV)"

cut -f 2-3,4-18,19,20,24,25 $IN_VMR_TSV | \
	  awk -F'\t' -v ACC=20 -v STATUS=21 'BEGIN{OFS="\t"} (NR==1){$ACC="segment_count";print;next}($ACC~/partial/||tolower($STATUS)~/no entry/||tolower($STATUS)~/partial/){$ACC="-1";print;next}{n=split($ACC,a,/;/); $ACC=n;print}' \
	 > $RAW_CT_FILE

echo "Wrote $(wc -l $RAW_CT_FILE)"

# RAW CT columns
# head -1 vmr_export.isolate_seg_counts.txt  | sed 's/\t/\n/g' | grep -n .  
#    1:Species Sort
#    2:Isolate Sort
#    3:Realm
#    4:Subrealm
#    5:Kingdom
#    6:Subkingdom
#    7:Phylum
#    8:Subphylum
#    9:Class
#    10:Subclass
#    11:Order
#    12:Suborder
#    13:Family
#    14:Subfamily
#    15:Genus
#    16:Subgenus
#    17:Species
#    18:ICTV_ID
#    19:Exemplar or additional isolate
#    20:segment_count
#    21:Genome coverage

#
# roll up reports
#
SPECIES_SORT=1
ISOLATE_SORT=2
FAMILY=13
GENUS=15
SUBGENUS=16
SPECIES=17
ICTV_ID=18
EXEMPLAR=19
SEG_CT=20
COV=21

echo "--------------- TEST RAW -----------"   
cut -f $SPECIES_SORT,$FAMILY,$GENUS,$SPECIES,$ICTV_ID,$SEG_CT $RAW_CT_FILE \
| egrep -C 10 "(Species|Begomovirus sidavariatialagoense)"|egrep -v "^--" \
| sort -k1,1n -k6,6n  \

echo "--------------- TEST SPECIES -----------"   
cut -f $SPECIES_SORT,$FAMILY,$GENUS,$SPECIES,$ICTV_ID,$SEG_CT $RAW_CT_FILE \
| egrep -C 10 "(Species|Begomovirus sidavariatialagoense)"|egrep -v "^--" \
| sort -k1,1n -k6,6n  \
| awk -F'\t' -v SEGCT=6 -v KEY=4 -f $0.awk


echo "--------------- FAMILY  -----------"   
FAMILY_COLS=$SPECIES_SORT,$FAMILY,$ICTV_ID,$SEG_CT
head -1 $RAW_CT_FILE | cut -f $FAMILY_COLS | head -1 > $OUT_FAMILY_CTS
cut -f $FAMILY_COLS $RAW_CT_FILE \
| tail -n +2 \
| sort -k2,2 -k4,4n  \
| awk -F'\t' -v SEGCT=4 -v KEY=2 -f $0.awk \
>> $OUT_FAMILY_CTS
# filter
egrep "(segment_count|;)" $OUT_FAMILY_CTS > $OUT_FAMILY_CTS_VAR
# report
echo "Wrote:"
wc -l $OUT_FAMILY_CTS $OUT_FAMILY_CTS_VAR

echo "--------------- GENUS  -----------"   
GENUS_COLS=$SPECIES_SORT,$FAMILY,$GENUS,$ICTV_ID,$SEG_CT
# header
head -1 $RAW_CT_FILE | cut -f $GENUS_COLS | head -1 > $OUT_GENUS_CTS
# data
cut -f $GENUS_COLS $RAW_CT_FILE \
| tail -n +2 \
| sort -k2,2 -k3,3 -k5,5n  \
| awk -F'\t' -v SEGCT=5 -v KEY=3 -f $0.awk \
>> $OUT_GENUS_CTS
# filter
egrep "(segment_count|;)" $OUT_GENUS_CTS > $OUT_GENUS_CTS_VAR
# report
echo "Wrote:"
wc -l $OUT_GENUS_CTS $OUT_GENUS_CTS_VAR

echo "--------------- SPECIES  -----------"   
SPECIES_COLS=$SPECIES_SORT,$FAMILY,$GENUS,$SPECIES,$ICTV_ID,$SEG_CT
# header
head -1 $RAW_CT_FILE | cut -f $SPECIES_COLS | head -1 > $OUT_SPECIES_CTS
# data
cut -f $SPECIES_SORT,$FAMILY,$GENUS,$SPECIES,$ICTV_ID,$SEG_CT $RAW_CT_FILE \
| tail -n +2 \
| sort -k1,1n -k6,6n  \
| awk -F'\t' -v SEGCT=6 -v KEY=4 -f $0.awk \
      >> $OUT_SPECIES_CTS
# filter
egrep "(segment_count|;)" $OUT_SPECIES_CTS > $OUT_SPECIES_CTS_VAR
# report
echo "Wrote:"
wc -l $OUT_SPECIES_CTS $OUT_SPECIES_CTS_VAR






