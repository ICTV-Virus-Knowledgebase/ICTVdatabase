#!/usr/bin/env bash
#
# tabulate segment counts and NAMES for each SPECIES
#
IN_VMR_TSV=../data/vmr_export.utf8.txt
echo IN_VMR_TSV=$IN_VMR_TSV

RAW_CT_FILE=vmr_export.isolate_segs.tsv
echo RAW_CT_FILE=$RAW_CT_FILE

CLEAN_CT_FILE=vmr_export.isolate_segs.clean.tsv
echo CLEAN_CT_FILE=$CLEAN_CT_FILE

EXTRACT_SCRIPT=$0.extract.awk
TABULATE_SCRIPT=$0.awk

OUT_FAMILY_SPECIES_ROLLUP=vmr-family-species-seg-rollup.tsv
OUT_FAMILY_SPECIES_ROLLUP_VAR=vmr-family-species-seg-rollup.var.tsv
OUT_REALM_SPECIES_ROLLUP=vmr-realm-species-seg-rollup.tsv
OUT_REALM_SPECIES_ROLLUP_VAR=vmr-realm-species-seg-rollup.var.tsv
OUT_REALM_SUBGENUS_ROLLUP=vmr-realm-subgenus-seg-rollup.tsv
OUT_REALM_SUBGENUS_ROLLUP_VAR=vmr-realm-subgenus-seg-rollup.var.tsv
OUT_REALM_GENUS_ROLLUP=vmr-realm-genus-seg-rollup.tsv
OUT_REALM_GENUS_ROLLUP_VAR=vmr-realm-genus-seg-rollup.var.tsv
OUT_REALM_SUBFAMILY_ROLLUP=vmr-realm-subfamily-seg-rollup.tsv
OUT_REALM_SUBFAMILY_ROLLUP_VAR=vmr-realm-subfamily-seg-rollup.var.tsv
OUT_REALM_FAMILY_ROLLUP=vmr-realm-family-seg-rollup.tsv
OUT_REALM_FAMILY_ROLLUP_VAR=vmr-realm-family-seg-rollup.var.tsv

# ----------------------------------------------------------------------
#
# parse VMR export to extract segments
#
# ----------------------------------------------------------------------
# look up column headers
#    head -1 vmr_export.utf8.txt | sed 's/\t/\n/g' | grep -n . 
#    1:Isolate ID
#    2:Species Sort
#    3:Isolate Sort
#    4:Realm
#    5:Subrealm
#    6:Kingdom
#    7:Subkingdom
#    8:Phylum
#    9:Subphylum
#    10:Class
#    11:Subclass
#    12:Order
#    13:Suborder
#    14:Family
#    15:Subfamily
#    16:Genus
#    17:Subgenus
#    18:Species
#    19:ICTV_ID
#    20:Exemplar or additional isolate
#    21:Virus name(s)
#    22:Virus name abbreviation(s)
#    23:Virus isolate designation
#    24:Virus GENBANK accession
#    25:Genome coverage
#    26:Genome
#    27:Host source
#    28:Accessions Link
#    29:Editor Notes
#    30:QC_status
#    31:QC_taxon_inher_molecule
#    32:QC_taxon_change
#    33:QC_taxon_proposal
# --- added segment info columns --
#    34: segment_count
#    35: segment_names

echo "Reading $(wc -l $IN_VMR_TSV)"

./vmr-add-segment-info.py --vmr $IN_VMR_TSV --unnamed-seg "-" --out $RAW_CT_FILE

echo "Wrote $(wc -l $RAW_CT_FILE)"

# remove isolates with -1 (no accessions, partial, etc)

awk -F $'\t' -v COL_NAME=segment_count -v FILT_VALUE=-1 \
    'BEGIN{OFS=FS} NR==1{for(i=1;i<=NF;i++) if($i==COL_NAME) c=i; if(!c){print "missing column: COL_NAME" > "/dev/stderr"; exit 1} print; next} $c!=FILT_VALUE' \
    $RAW_CT_FILE \
    > $CLEAN_CT_FILE
echo "Wrote $CLEAN_CT_FILE rows=$(wc -l $CLEAN_CT_FILE)"

# ----------------------------------------------------------------------
#
# roll up reports
#
# ----------------------------------------------------------------------
#
REALM_SUBORDER_RANKS="Realm,Subrealm,Kingdom,Subkingdom,Phylum,Subphylum,Class,Subclass,Order,Suborder"

echo "--------------- TEST RAW -----------"   
egrep -C 10 "(Species|Begomovirus sidavariatialagoense)" $RAW_CT_FILE \
|egrep -v "^--" \
| ./vmr-roll-up-segment-info.py | cut -f 2- | column -t
    
echo "--------------- SPECIES (FAMILY:SPECIES) -----------"   
./vmr-roll-up-segment-info.py \
    --in $CLEAN_CT_FILE \
    --group "Species Sort,ICTV_ID,Family,Subfamily,Genus,Subgenus,Species" \
    --out $OUT_FAMILY_SPECIES_ROLLUP

awk -F $'\t' -v COL_NAME=segments_consistent -v FILT_VALUE=yes \
    'BEGIN{OFS=FS} NR==1{for(i=1;i<=NF;i++) if($i==COL_NAME) c=i; if(!c){print "missing column: COL_NAME" > "/dev/stderr"; exit 1} print; next} $c!=FILT_VALUE' \
    $OUT_FAMILY_SPECIES_ROLLUP > $OUT_FAMILY_SPECIES_ROLLUP_VAR
echo "Wrote $OUT_FAMILY_SPECIES_ROLLUP_VAR rows=$(wc -l $OUT_FAMILY_SPECIES_ROLLUP_VAR)"

echo "--------------- SPECIES (REALM:SPECIES) -----------"   
./vmr-roll-up-segment-info.py \
    --in $CLEAN_CT_FILE \
    --group "Species Sort,ICTV_ID,$REALM_SUBORDER_RANKS,Family,Subfamily,Genus,Subgenus,Species" \
    --out $OUT_REALM_SPECIES_ROLLUP

awk -F $'\t' -v COL_NAME=segments_consistent -v FILT_VALUE=yes \
    'BEGIN{OFS=FS} NR==1{for(i=1;i<=NF;i++) if($i==COL_NAME) c=i; if(!c){print "missing column: COL_NAME" > "/dev/stderr"; exit 1} print; next} $c!=FILT_VALUE' \
    $OUT_REALM_SPECIES_ROLLUP > $OUT_REALM_SPECIES_ROLLUP_VAR
echo "Wrote $OUT_REALM_SPECIES_ROLLUP_VAR rows=$(wc -l $OUT_REALM_SPECIES_ROLLUP_VAR)"

echo "--------------- SUBGENUS (REALM:SUBGENUS) -----------"   
./vmr-roll-up-segment-info.py \
    --in $CLEAN_CT_FILE \
    --group "$REALM_SUBORDER_RANKS,Family,Subfamily,Genus,Subgenus" \
    --out $OUT_REALM_SUBGENUS_ROLLUP

awk -F $'\t' -v COL_NAME=segments_consistent -v FILT_VALUE=yes \
    'BEGIN{OFS=FS} NR==1{for(i=1;i<=NF;i++) if($i==COL_NAME) c=i; if(!c){print "missing column: COL_NAME" > "/dev/stderr"; exit 1} print; next} $c!=FILT_VALUE' \
    $OUT_REALM_SUBGENUS_ROLLUP > $OUT_REALM_SUBGENUS_ROLLUP_VAR
echo "Wrote $OUT_REALM_SUBGENUS_ROLLUP_VAR rows=$(wc -l $OUT_REALM_SUBGENUS_ROLLUP_VAR)"


echo "--------------- GENUS (REALM:GENUS) -----------"   
./vmr-roll-up-segment-info.py \
    --in $CLEAN_CT_FILE \
    --group "$REALM_SUBORDER_RANKS,Family,Subfamily,Genus" \
    --out $OUT_REALM_GENUS_ROLLUP

awk -F $'\t' -v COL_NAME=segments_consistent -v FILT_VALUE=yes \
    'BEGIN{OFS=FS} NR==1{for(i=1;i<=NF;i++) if($i==COL_NAME) c=i; if(!c){print "missing column: COL_NAME" > "/dev/stderr"; exit 1} print; next} $c!=FILT_VALUE' \
    $OUT_REALM_GENUS_ROLLUP > $OUT_REALM_GENUS_ROLLUP_VAR
echo "Wrote $OUT_REALM_GENUS_ROLLUP_VAR rows=$(wc -l $OUT_REALM_GENUS_ROLLUP_VAR)"


echo "--------------- SUBFAMILY (REALM:SUBFAMILY) -----------"   
./vmr-roll-up-segment-info.py \
    --in $CLEAN_CT_FILE \
    --group "$REALM_SUBORDER_RANKS,Family,Subfamily" \
    --out $OUT_REALM_SUBFAMILY_ROLLUP

awk -F $'\t' -v COL_NAME=segments_consistent -v FILT_VALUE=yes \
    'BEGIN{OFS=FS} NR==1{for(i=1;i<=NF;i++) if($i==COL_NAME) c=i; if(!c){print "missing column: COL_NAME" > "/dev/stderr"; exit 1} print; next} $c!=FILT_VALUE' \
    $OUT_REALM_SUBFAMILY_ROLLUP > $OUT_REALM_SUBFAMILY_ROLLUP_VAR
echo "Wrote $OUT_REALM_SUBFAMILY_ROLLUP_VAR rows=$(wc -l $OUT_REALM_SUBFAMILY_ROLLUP_VAR)"

echo "--------------- FAMILY (REALM:FAMILY) -----------"   
./vmr-roll-up-segment-info.py \
    --in $CLEAN_CT_FILE \
    --group "$REALM_SUBORDER_RANKS,Family" \
    --out $OUT_REALM_FAMILY_ROLLUP

awk -F $'\t' -v COL_NAME=segments_consistent -v FILT_VALUE=yes \
    'BEGIN{OFS=FS} NR==1{for(i=1;i<=NF;i++) if($i==COL_NAME) c=i; if(!c){print "missing column: COL_NAME" > "/dev/stderr"; exit 1} print; next} $c!=FILT_VALUE' \
    $OUT_REALM_FAMILY_ROLLUP > $OUT_REALM_FAMILY_ROLLUP_VAR
echo "Wrote $OUT_REALM_FAMILY_ROLLUP_VAR rows=$(wc -l $OUT_REALM_FAMILY_ROLLUP_VAR)"



