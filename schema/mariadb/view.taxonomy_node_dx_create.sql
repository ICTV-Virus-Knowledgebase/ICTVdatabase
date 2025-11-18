DROP VIEW IF EXISTS `taxonomy_node_dx`;

CREATE VIEW `taxonomy_node_dx` AS
SELECT 
    pt.level_id AS prev_level, 
    pd.prev_taxid AS prev_id, 
    pt.ictv_id AS prev_ictv_id, 
    pd.tag_csv AS prev_tags, 
    pt.name AS prev_name, 
    pt.lineage AS prev_lineage, 
    pd.proposal AS prev_proposal,
    
    nt.level_id AS next_level, 
    nd.new_taxid AS next_id, 
    nt.ictv_id AS next_ictv_id, 
    nd.tag_csv AS next_tags, 
    nt.name AS next_name, 
    nt.lineage AS next_lineage, 
    nd.proposal AS next_proposal,
    
    t.*
FROM taxonomy_node t
LEFT OUTER JOIN taxonomy_node_delta pd 
    ON pd.new_taxid = t.taxnode_id
LEFT OUTER JOIN taxonomy_node pt 
    ON pt.taxnode_id = pd.prev_taxid
LEFT OUTER JOIN taxonomy_node_delta nd 
    ON nd.prev_taxid = t.taxnode_id
LEFT OUTER JOIN taxonomy_node nt 
    ON nt.taxnode_id = nd.new_taxid;
