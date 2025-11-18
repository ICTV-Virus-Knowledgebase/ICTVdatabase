DROP VIEW IF EXISTS `taxonomy_toc_dx`;

CREATE VIEW `taxonomy_toc_dx` AS
SELECT 
    t1.*, 
    (t1.`tree_id` - t2.`tree_id`) AS tree_id_delta,
    t2.`tree_id` AS prev_tree_id,
    t2.`msl_release_num` AS prev_msl
FROM 
    `taxonomy_toc` t1
JOIN 
    `taxonomy_toc` t2 
    ON t2.`msl_release_num` = t1.`msl_release_num` - 1;
