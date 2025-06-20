-- LRM (06202025): This is the old SP that get_taxon_history serviced used. 
-- The new SP is called: GetTaxonHistory.

USE ICTVonline39;

DELIMITER $$

CREATE PROCEDURE getTaxonReleaseHistory(
    IN currentMSL INT,
    IN taxNodeID INT
)
BEGIN
    -- Declare variables
    DECLARE currentTreeID INT;
    DECLARE abolishedTreeID INT DEFAULT NULL;
    DECLARE lastTreeID INT DEFAULT NULL;
    
    -- Drop and recreate temporary table
    DROP TEMPORARY TABLE IF EXISTS treeIDs;
    CREATE TEMPORARY TABLE treeIDs (id INT);

    -- Query 1: Get currentTreeID
    SELECT tree_id INTO currentTreeID
    FROM taxonomy_toc
    WHERE msl_release_num = currentMSL
    ORDER BY tree_id
    LIMIT 1;

    -- Query 1: Get taxon info
    SELECT 
        tn_selected.lineage,
        tn_selected.msl_release_num,
        tl_selected.name AS rank_name, 
        CONCAT(
            CASE WHEN tn_selected.realm_id IS NOT NULL THEN 'Realm;' ELSE '' END,
            CASE WHEN tn_selected.subrealm_id IS NOT NULL THEN 'Subrealm;' ELSE '' END,
            CASE WHEN tn_selected.kingdom_id IS NOT NULL THEN 'Kingdom;' ELSE '' END,
            CASE WHEN tn_selected.subkingdom_id IS NOT NULL THEN 'Subkingdom;' ELSE '' END,
            CASE WHEN tn_selected.phylum_id IS NOT NULL THEN 'Phylum;' ELSE '' END,
            CASE WHEN tn_selected.subphylum_id IS NOT NULL THEN 'Subphylum;' ELSE '' END, 
            CASE WHEN tn_selected.class_id IS NOT NULL THEN 'Class;' ELSE '' END, 
            CASE WHEN tn_selected.subclass_id IS NOT NULL THEN 'Subclass;' ELSE '' END, 
            CASE WHEN tn_selected.order_id IS NOT NULL THEN 'Order;' ELSE '' END,
            CASE WHEN tn_selected.suborder_id IS NOT NULL THEN 'Suborder;' ELSE '' END, 
            CASE WHEN tn_selected.family_id IS NOT NULL THEN 'Family;' ELSE '' END, 
            CASE WHEN tn_selected.subfamily_id IS NOT NULL THEN 'Subfamily;' ELSE '' END, 
            CASE WHEN tn_selected.genus_id IS NOT NULL THEN 'Genus;' ELSE '' END, 
            CASE WHEN tn_selected.subgenus_id IS NOT NULL THEN 'Subgenus;' ELSE '' END, 
            CASE WHEN tn_selected.species_id IS NOT NULL THEN 'Species;' ELSE '' END
        ) AS rank_names,
        tn_selected.taxnode_id, 
        tn_selected.name AS taxon_name,
        tn_selected.tree_id
    FROM taxonomy_node tn_selected 
    JOIN taxonomy_level tl_selected ON tl_selected.id = tn_selected.level_id 
    WHERE tn_selected.taxnode_id = taxNodeID
    LIMIT 1;

    -- Query 1a: If taxon abolished
    SELECT toc.tree_id, node.tree_id
    INTO abolishedTreeID, lastTreeID
    FROM taxonomy_node_x AS node
    JOIN taxonomy_toc toc ON toc.msl_release_num = node.msl_release_num + 1
    JOIN taxonomy_node_delta next_delta ON next_delta.prev_taxid = node.taxnode_id
    WHERE node.tree_id >= 19000000
      AND node.tree_id <= currentTreeID
      AND node.is_deleted = 0 
      AND node.is_hidden = 0
      AND node.target_taxnode_id = taxNodeID
      AND next_delta.is_deleted = 1
    LIMIT 1;

    -- Query 1b: Populate treeIDs
    INSERT INTO treeIDs
    SELECT DISTINCT tree_id
    FROM (
        SELECT  
            SUM(
                IFNULL(prev_delta.is_deleted,0) +
                IFNULL(prev_delta.is_demoted,0) +
                IFNULL(prev_delta.is_lineage_updated,0) +
                IFNULL(prev_delta.is_merged,0) +
                IFNULL(prev_delta.is_moved,0) +
                IFNULL(prev_delta.is_new,0) +
                ABS(IFNULL(prev_delta.is_now_type,0)) +
                IFNULL(prev_delta.is_promoted,0) +
                IFNULL(prev_delta.is_renamed,0) +
                IFNULL(prev_delta.is_split,0)
            ) AS modifications,  
            node.tree_id
        FROM taxonomy_node_x AS node
        LEFT JOIN taxonomy_node_delta AS prev_delta ON prev_delta.new_taxid = node.taxnode_id
        WHERE node.tree_id >= 19000000
          AND node.tree_id <= currentTreeID
          AND node.is_deleted = 0 
          AND node.is_hidden = 0   
          AND node.target_taxnode_id = taxNodeID
        GROUP BY node.tree_id

        UNION ALL
        SELECT
            CASE 
              WHEN abolishedTreeID IS NULL THEN 0 ELSE 1 
            END AS modifications,
            abolishedTreeID AS tree_id
        FROM DUAL
    ) releases
    WHERE modifications > 0
    ORDER BY tree_id DESC;

    -- Query 2: MSL releases where change occurred
    SELECT 
        CONCAT(
            CASE WHEN realms > 0 THEN 'realm,' ELSE '' END,
            CASE WHEN subrealms > 0 THEN 'subrealm,' ELSE '' END,
            CASE WHEN kingdoms > 0 THEN 'kingdom,' ELSE '' END,
            CASE WHEN subkingdoms > 0 THEN 'subkingdom,' ELSE '' END,
            CASE WHEN phyla > 0 THEN 'phylum,' ELSE '' END,
            CASE WHEN subphyla > 0 THEN 'subphylum,' ELSE '' END,
            CASE WHEN classes > 0 THEN 'class,' ELSE '' END,
            CASE WHEN subclasses > 0 THEN 'subclass,' ELSE '' END,
            CASE WHEN orders > 0 THEN 'order,' ELSE '' END,
            CASE WHEN suborders > 0 THEN 'suborder,' ELSE '' END,
            CASE WHEN families > 0 THEN 'family,' ELSE '' END,
            CASE WHEN subfamilies > 0 THEN 'subfamily,' ELSE '' END,
            CASE WHEN genera > 0 THEN 'genus,' ELSE '' END,
            CASE WHEN subgenera > 0 THEN 'subgenus,' ELSE '' END,
            CASE WHEN species > 0 THEN 'species' ELSE '' END
        ) AS rank_names,
        msl.msl_release_num AS release_number,
        SUBSTRING(msl.notes,1,255) AS release_title,
        tree_id,
        msl.year
    FROM view_taxa_level_counts_by_release msl
    WHERE tree_id IN (SELECT id FROM treeIDs)
    ORDER BY tree_id DESC;

    -- Query 3: All taxon modifications by MSL release
    SELECT 
        current_lineage,
        current_is_type,
        ictv_id,
        prev_notes,
        prev_proposal,
        prev_tag_csv,
        (
          SELECT CONCAT(
            CASE WHEN ranks_tn.realm_id IS NOT NULL THEN 'Realm;' ELSE '' END,
            CASE WHEN ranks_tn.subrealm_id IS NOT NULL THEN 'Subrealm;' ELSE '' END,
            CASE WHEN ranks_tn.kingdom_id IS NOT NULL THEN 'Kingdom;' ELSE '' END,
            CASE WHEN ranks_tn.subkingdom_id IS NOT NULL THEN 'Subkingdom;' ELSE '' END,
            CASE WHEN ranks_tn.phylum_id IS NOT NULL THEN 'Phylum;' ELSE '' END,
            CASE WHEN ranks_tn.subphylum_id IS NOT NULL THEN 'Subphylum;' ELSE '' END,
            CASE WHEN ranks_tn.class_id IS NOT NULL THEN 'Class;' ELSE '' END,
            CASE WHEN ranks_tn.subclass_id IS NOT NULL THEN 'Subclass;' ELSE '' END,
            CASE WHEN ranks_tn.order_id IS NOT NULL THEN 'Order;' ELSE '' END,
            CASE WHEN ranks_tn.suborder_id IS NOT NULL THEN 'Suborder;' ELSE '' END,
            CASE WHEN ranks_tn.family_id IS NOT NULL THEN 'Family;' ELSE '' END,
            CASE WHEN ranks_tn.subfamily_id IS NOT NULL THEN 'Subfamily;' ELSE '' END,
            CASE WHEN ranks_tn.genus_id IS NOT NULL THEN 'Genus;' ELSE '' END,
            CASE WHEN ranks_tn.subgenus_id IS NOT NULL THEN 'Subgenus;' ELSE '' END,
            CASE WHEN ranks_tn.species_id IS NOT NULL THEN 'Species;' ELSE '' END
          )
          FROM taxonomy_node ranks_tn
          WHERE ranks_tn.taxnode_id = releaseNodes.taxnode_id
        ) AS rank_names,
        taxnode_id,
        tree_id
    FROM (
        SELECT
            node.is_ref AS current_is_type,
            node.lineage AS current_lineage,
            node.ictv_id,
            node.left_idx,
            MAX(prev_delta.notes) AS prev_notes,
            (
                SELECT dx.prev_proposal
                FROM taxonomy_node_dx dx
                JOIN taxonomy_node t ON dx.left_idx <= t.left_idx 
                                    AND dx.right_idx >= t.right_idx 
                                    AND dx.tree_id = t.tree_id 
                                    AND dx.level_id > 100
                WHERE t.taxnode_id = node.taxnode_id
                  AND dx.prev_proposal IS NOT NULL 
                  AND dx.prev_proposal <> ''
                ORDER BY dx.level_id DESC
                LIMIT 1
            ) AS prev_proposal,
            CONCAT(
                CASE WHEN MAX(prev_delta.is_deleted)=1 THEN 'Abolished,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_demoted)=1 THEN 'Demoted,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_lineage_updated)=1 THEN 'Higher rank lineage updated,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_merged)=1 THEN 'Merged,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_moved)=1 THEN 'Moved,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_new)=1 THEN 'New,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_promoted)=1 THEN 'Promoted,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_renamed)=1 THEN 'Renamed,' ELSE '' END,
                CASE WHEN MAX(prev_delta.is_split)=1 THEN 'Split,' ELSE '' END,
                CASE 
                  WHEN MIN(prev_delta.is_now_type)=1 THEN 'Assigned as Type Species,' 
                  WHEN MIN(prev_delta.is_now_type)=-1 THEN 'Removed as Type Species,' 
                  ELSE '' 
                END
            ) AS prev_tag_csv,
            node.taxnode_id,
            node.tree_id
        FROM taxonomy_node_x AS node
        LEFT JOIN taxonomy_node_delta AS prev_delta ON prev_delta.new_taxid = node.taxnode_id
        WHERE node.tree_id IN (SELECT id FROM treeIDs)
          AND node.is_deleted = 0 
          AND node.is_hidden = 0 
          AND node.target_taxnode_id = taxNodeID
        GROUP BY node.taxnode_id, node.tree_id, node.ictv_id, node.lineage, node.is_ref, node.left_idx

        UNION ALL
        SELECT
            0 AS current_is_type,
            lastNode.lineage AS current_lineage,
            lastNode.ictv_id,
            lastNode.left_idx,
            MAX(next_delta.notes) AS prev_notes,
            (
                SELECT dx.next_proposal
                FROM taxonomy_node_dx dx
                JOIN taxonomy_node t ON dx.left_idx <= t.left_idx 
                                    AND dx.right_idx >= t.right_idx
                                    AND dx.tree_id = t.tree_id 
                                    AND dx.level_id > 100
                WHERE t.taxnode_id = lastNode.taxnode_id
                  AND dx.next_proposal IS NOT NULL
                  AND dx.next_proposal <> ''
                ORDER BY dx.level_id DESC
                LIMIT 1
            ) AS prev_proposal,
            CASE WHEN MAX(next_delta.is_deleted)=1 THEN 'Abolished,' ELSE '' END AS prev_tag_csv,
            lastNode.taxnode_id,
            abolishedTreeID AS tree_id
        FROM taxonomy_node_x AS lastNode
        LEFT JOIN taxonomy_node_delta next_delta ON next_delta.prev_taxid = lastNode.taxnode_id
        WHERE abolishedTreeID IS NOT NULL
          AND lastNode.tree_id >= 19000000
          AND lastNode.tree_id <= currentTreeID
          AND lastNode.is_deleted = 0
          AND lastNode.is_hidden = 0
          AND lastNode.target_taxnode_id = taxNodeID
          AND lastNode.tree_id = lastTreeID
          AND next_delta.is_deleted = 1
        GROUP BY lastNode.taxnode_id, lastNode.tree_id, lastNode.ictv_id, lastNode.lineage, lastNode.is_ref, lastNode.left_idx
    ) releaseNodes
    ORDER BY tree_id DESC, left_idx ASC;

    -- Optional: drop the temporary table
    -- DROP TEMPORARY TABLE IF EXISTS treeIDs;

END$$

DELIMITER ;