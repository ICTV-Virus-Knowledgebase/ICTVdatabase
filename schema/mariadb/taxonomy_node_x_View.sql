CREATE VIEW `taxonomy_node_x` AS
-- 
-- test query for taxonomy_node_x
-- 

SELECT 
    node.*, 
    target.`taxnode_id` AS target_taxnode_id,
    target.`name` AS target_name,
    target.`lineage` AS target_lineage
FROM 
    `taxonomy_node_names` target
JOIN 
    `taxonomy_node_merge_split` ms 
    ON target.`ictv_id` IN (ms.`prev_ictv_id`)
JOIN 
    `taxonomy_node_names` node 
    ON node.`ictv_id` IN (ms.`next_ictv_id`);
