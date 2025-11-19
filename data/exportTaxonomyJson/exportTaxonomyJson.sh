#!/usr/bin/env bash
#
# Generate release.json and taxonomy_yyyy.json
#
# ./exportTaxonomyJson.sh -> Generate JSON files for all releases
# ./exportTaxonomyJson.sh 40 -> Generate JSON files for specific release

set -euo pipefail

# Database name
DBNAME="ictv_taxonomy"

# Flags
populateAll=0
populateByRelease=0

#-----------------------------------------------------------------------------------
# In case we need to populate taxonomy_json and taxonomy_json tables first
#-----------------------------------------------------------------------------------
populateTables(){

    local treeID=inputFromUser

    if [populateAll]; then
        mariadb -D "$DBNAME" --batch --skip-column-names --silent -e "CALL initializeTaxonomyJsonRanks();"
        and
        mariadb -D "$DBNAME" --batch --skip-column-names --silent -e "CALL populateTaxonomyJsonForAllReleases();"
    fi

    if [populateByRelease]; then
        mariadb -D "$DBNAME" --batch --skip-column-names --silent -e "CALL initializeTaxonomyJsonRanks();"
        and
        mariadb -D "$DBNAME" --batch --skip-column-names --silent -e "CALL populateTaxonomyJSON(${treeID});"
    fi
}

#-----------------------------------------------------------------------------------
# Export release data and save as releases.json.
#-----------------------------------------------------------------------------------
exportReleasesJSON() {

    # remove existing file if present
    if [ -e "releases.json" ]; then
        # try to remove; on failure run the error handler (echo to stderr + exit)
        rm -f "releases.json" || { echo "Failed to remove existing releases.json" >&2; exit 1; }
    fi

    mariadb -D "$DBNAME" --batch --skip-column-names --silent \
    -e "CALL exportReleasesJSON();" > "releases.json"

    # verify output was created and is not empty
    if [ ! -s "releases.json" ]; then
        echo "releases.json was not created or is empty" >&2
        exit 1
    fi
    
}

#-----------------------------------------------------------------------------------
# Export JSON files for non-species and species taxa.
#-----------------------------------------------------------------------------------
exportTaxonomyJSON() {

    local mslReleaseNum_="${1:-}"
    local treeSQL

    if [ -n "$mslReleaseNum_" ]; then

        # Return the tree ID that corresponds to this MSL release number.
        treeSQL=$(mariadb -D "$DBNAME" --batch --skip-column-names --silent \
          -e "SELECT toc.tree_id, tn.name 
              FROM taxonomy_toc toc 
              JOIN taxonomy_node tn ON tn.taxnode_id = toc.tree_id 
              WHERE toc.msl_release_num = ${mslReleaseNum_} LIMIT 1;")

    else

        # Return all tree IDs that have a valid MSL release number.
        treeSQL=$(mariadb -D "$DBNAME" --batch --skip-column-names --silent \
          -e "SELECT toc.tree_id, tn.name 
              FROM taxonomy_toc toc 
              JOIN taxonomy_node tn ON tn.taxnode_id = toc.tree_id 
              WHERE toc.msl_release_num IS NOT NULL ORDER BY toc.tree_id ASC;")
    fi
    
    # Iterate over all treeIDs and treeNames that are returned.
    while IFS=$'\t' read -r treeID treeName; do

        # Sanitize name to use part of filename.
        treeSlug=${treeName// /_}
        treeSlug=$(echo "$treeSlug" | tr -cd '[:alnum:]_-')

        # Choose filename.
        outFile="taxonomy_${treeSlug}.json"

        # Delete existing file if present.
        if [ -e "$outFile" ]; then
            rm -f "$outFile" || { echo "Failed to remove existing $outFile" >&2; exit 1; }
        fi

        # Call exportTaxonomyJSON SP and write the output.
        mariadb -D "$DBNAME" --batch --skip-column-names --silent \
        -e "CALL exportTaxonomyJSON(${treeID});" > "$outFile"

        # Verify output created
        if [ ! -s "$outFile" ]; then
            echo "$outFile was not created or is empty" >&2
            continue
        fi

        printf 'Wrote %s for tree %s\n' "$outFile" "$treeID"
    
    done <<< "$treeSQL"
}

# Call functions

exportReleasesJSON
exportTaxonomyJSON "${1:-}"
    