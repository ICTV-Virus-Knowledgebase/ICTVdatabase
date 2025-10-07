DROP VIEW IF EXISTS `view_taxa_level_counts_by_release`;

CREATE VIEW `view_taxa_level_counts_by_release` AS
-- by Don Dempsey
SELECT 
    `release`.tree_id, 
    `release`.notes,
    `release`.msl_release_num,
    `release`.name AS `year`,

    IFNULL(realm, 0) AS realms, 
    IFNULL(subrealm, 0) AS subrealms,
    IFNULL(kingdom, 0) AS kingdoms,
    IFNULL(subkingdom, 0) AS subkingdoms,
    IFNULL(phylum, 0) AS phyla,
    IFNULL(subphylum, 0) AS subphyla, 
    IFNULL(class, 0) AS classes,
    IFNULL(subclass, 0) AS subclasses,
    IFNULL(`order`, 0) AS orders,  
    IFNULL(suborder, 0) AS suborders,  
    IFNULL(family, 0) AS families,  
    IFNULL(subfamily, 0) AS subfamilies,  
    IFNULL(genus, 0) AS genera,  
    IFNULL(subgenus, 0) AS subgenera,  
    IFNULL(species, 0) AS species

FROM (
    SELECT 
        tree_id, 
        MAX(CASE WHEN name = 'realm' THEN count_by_level END) AS realm,
        MAX(CASE WHEN name = 'subrealm' THEN count_by_level END) AS subrealm,
        MAX(CASE WHEN name = 'kingdom' THEN count_by_level END) AS kingdom,
        MAX(CASE WHEN name = 'subkingdom' THEN count_by_level END) AS subkingdom,
        MAX(CASE WHEN name = 'phylum' THEN count_by_level END) AS phylum,
        MAX(CASE WHEN name = 'subphylum' THEN count_by_level END) AS subphylum,
        MAX(CASE WHEN name = 'class' THEN count_by_level END) AS class,
        MAX(CASE WHEN name = 'subclass' THEN count_by_level END) AS subclass,
        MAX(CASE WHEN name = 'order' THEN count_by_level END) AS `order`,
        MAX(CASE WHEN name = 'suborder' THEN count_by_level END) AS suborder,
        MAX(CASE WHEN name = 'family' THEN count_by_level END) AS family,
        MAX(CASE WHEN name = 'subfamily' THEN count_by_level END) AS subfamily,
        MAX(CASE WHEN name = 'genus' THEN count_by_level END) AS genus,
        MAX(CASE WHEN name = 'subgenus' THEN count_by_level END) AS subgenus,
        MAX(CASE WHEN name = 'species' THEN count_by_level END) AS species
    FROM (
        SELECT 
            COUNT(tn.level_id) AS count_by_level,
            tl.name,
            tn.tree_id
        FROM taxonomy_node tn
        JOIN taxonomy_level tl ON tl.id = tn.level_id
        WHERE tn.is_hidden = 0
        AND tn.msl_release_num IS NOT NULL
        AND tn.name NOT LIKE 'unassigned'
        GROUP BY tn.tree_id, tl.name
    ) AS levelCounts
    GROUP BY tree_id
) AS pivotedData
JOIN taxonomy_node `release` ON (`release`.tree_id = pivotedData.tree_id AND `release`.level_id = 100)
WHERE `release`.msl_release_num IS NOT NULL
AND `release`.name NOT LIKE 'unassigned';
