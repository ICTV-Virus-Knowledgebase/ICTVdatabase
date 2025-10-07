DROP VIEW IF EXISTS `view_taxonomy_stats`;

CREATE VIEW `view_taxonomy_stats` AS
SELECT 
    (SELECT notes
     FROM taxonomy_node AS t
     WHERE t.level_id = 100 AND t.taxnode_id = n.tree_id) AS notes, 
    n.msl_release_num,
    (SELECT name
     FROM taxonomy_node AS t
     WHERE t.level_id = 100 AND t.taxnode_id = n.tree_id) AS year, 
    COUNT(order_level.id) AS orders, 
    COUNT(family_level.id) AS families, 
    COUNT(subfamily_level.id) AS subfamilies, 
    COUNT(genus_level.id) AS genera, 
    COUNT(species_level.id) AS species
FROM 
    taxonomy_node AS n 
    LEFT JOIN taxonomy_level AS order_level ON order_level.id = n.level_id AND order_level.id = 200 
    LEFT JOIN taxonomy_level AS family_level ON family_level.id = n.level_id AND family_level.id = 300 
    LEFT JOIN taxonomy_level AS subfamily_level ON subfamily_level.id = n.level_id AND subfamily_level.id = 400 
    LEFT JOIN taxonomy_level AS genus_level ON genus_level.id = n.level_id AND genus_level.id = 500 
    LEFT JOIN taxonomy_level AS species_level ON species_level.id = n.level_id AND species_level.id = 600
WHERE 
    n.is_hidden = 0 
    AND n.msl_release_num IS NOT NULL 
    AND n.name NOT LIKE 'unassigned' 
    AND n.tree_id > 10090000
GROUP BY 
    n.tree_id, 
    n.msl_release_num;
