DELIMITER $$

DROP PROCEDURE IF EXISTS searchTaxonomy $$

CREATE PROCEDURE searchTaxonomy(
    IN currentMslRelease INT,
    IN includeAllReleases BOOLEAN,
    IN searchText NVARCHAR(100),
    IN selectedMslRelease INT
)
BEGIN
    -- Declare variables
    DECLARE filteredSearchText VARCHAR(100);
    DECLARE trimmedSearchText NVARCHAR(100);

    -- Validate the current MSL release
    IF currentMslRelease IS NULL OR currentMslRelease < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Please enter a valid current MSL release';
    END IF;

    -- Validate the search text
    SET trimmedSearchText = TRIM(searchText);
    IF trimmedSearchText IS NULL OR CHAR_LENGTH(trimmedSearchText) < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Please enter non-empty search text';
    END IF;

    -- Replace the same characters that were replaced in the cleaned_name column.
    SET filteredSearchText = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        trimmedSearchText,
        'í','i'),'é','e'),'ó','o'),'ú','u'),'á','a'),'ì','i'),'è','e'),'ò','o'),'ù','u'),'à','a'),'î','i'),'ê','e'),'ô','o'),'û','u'),'â','a'),'ü','u'),'ö','o'),'ï','i'),'ë','e'),'ä','a'),'ç','c'),'ñ','n'),'‘',''''),'’',''''),'`',' '),'  ',' '),'ā','a'),'ī','i'),'ĭ','i'),'ǎ','a'),'ē','e'),'ō','o');

    -- Make sure "include all releases" isn't null.
    IF includeAllReleases IS NULL THEN
        SET includeAllReleases = FALSE;
    END IF;

    -- If we aren't including all releases and the MSL release number is null, default to the current release.
    IF includeAllReleases = FALSE AND selectedMslRelease IS NULL THEN
        SET selectedMslRelease = currentMslRelease;
    END IF;

    -- We need to replicate the logic for display_order. In SQL Server, it uses a subquery with DENSE_RANK
    -- on siblings, then picks the corresponding taxnode_id.
    -- In MariaDB, we can use a CTE or derived table. We'll use a CTE here.

    WITH base AS (
    SELECT
        tn.taxnode_id, tn.parent_id, tn.level_id, tn.left_idx, tn.tree_id,
        tn.ictv_id, tn.lineage, tn.msl_release_num,
        tl.name  AS rank_name,
        tree.name AS tree_name,
        CONCAT(
            tn.tree_id,
            IF(tn.realm_id      IS NOT NULL, CONCAT(',', tn.realm_id), ''),
            IF(tn.subrealm_id   IS NOT NULL, CONCAT(',', tn.subrealm_id), ''),
            IF(tn.kingdom_id    IS NOT NULL, CONCAT(',', tn.kingdom_id), ''),
            IF(tn.subkingdom_id IS NOT NULL, CONCAT(',', tn.subkingdom_id), ''),
            IF(tn.phylum_id     IS NOT NULL, CONCAT(',', tn.phylum_id), ''),
            IF(tn.subphylum_id  IS NOT NULL, CONCAT(',', tn.subphylum_id), ''),
            IF(tn.class_id      IS NOT NULL, CONCAT(',', tn.class_id), ''),
            IF(tn.subclass_id   IS NOT NULL, CONCAT(',', tn.subclass_id), ''),
            IF(tn.order_id      IS NOT NULL, CONCAT(',', tn.order_id), ''),
            IF(tn.suborder_id   IS NOT NULL, CONCAT(',', tn.suborder_id), ''),
            IF(tn.family_id     IS NOT NULL, CONCAT(',', tn.family_id), ''),
            IF(tn.subfamily_id  IS NOT NULL, CONCAT(',', tn.subfamily_id), ''),
            IF(tn.genus_id      IS NOT NULL, CONCAT(',', tn.genus_id), ''),
            IF(tn.subgenus_id   IS NOT NULL, CONCAT(',', tn.subgenus_id), ''),
            IF(tn.species_id    IS NOT NULL, CONCAT(',', tn.species_id), '')
        ) AS taxnode_lineage
    FROM taxonomy_node tn FORCE INDEX (idx_tn_allreleases_order)
    JOIN taxonomy_level tl  ON tl.id = tn.level_id
    JOIN taxonomy_node tree ON tree.taxnode_id = tn.tree_id
    WHERE
        tn.taxnode_id <> tn.tree_id
        AND tn.is_hidden = 0
        AND tn.is_deleted = 0
        AND tn.msl_release_num <= currentMslRelease
        AND (includeAllReleases OR tn.msl_release_num = COALESCE(selectedMslRelease, currentMslRelease))
        AND tn.cleaned_name LIKE CONCAT('%', filteredSearchText, '%')
    ),
    parents AS (
    SELECT DISTINCT parent_id, level_id
    FROM base
    ),
    sibs AS (
    SELECT
        n.taxnode_id,
        DENSE_RANK() OVER (
            PARTITION BY n.parent_id, n.level_id
            ORDER BY n.left_idx, n.taxnode_id
        ) AS display_order
    FROM taxonomy_node n
    JOIN parents p
        ON p.parent_id = n.parent_id
    AND p.level_id  = n.level_id
    WHERE
        n.taxnode_id <> n.tree_id
    )
    SELECT
    s.display_order,
    b.ictv_id,
    REPLACE(IFNULL(b.lineage,''), ';', '>') AS lineage,
    b.parent_id AS parent_taxnode_id,
    b.rank_name,
    b.msl_release_num AS release_number,
    searchText AS search_text,
    b.taxnode_id,
    b.taxnode_lineage,
    b.tree_id,
    b.tree_name
    FROM base b
    JOIN sibs s ON s.taxnode_id = b.taxnode_id
    ORDER BY b.tree_id DESC, b.left_idx;

END $$

DELIMITER ;