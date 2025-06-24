/* ================================================================
   Stored procedure  : GetTaxonHistory  (MariaDB version)
   Converted from    : SQL-Server
   Used by			 : get-taxon-details service
   Notes			 : This SP was created by Don to replace the
   					   getTaxonReleaseHistory SP
   ================================================================ */

DROP PROCEDURE IF EXISTS `GetTaxonHistory`;


DELIMITER //

CREATE PROCEDURE GetTaxonHistory(
	
   -- The current MSL release number.
   IN `currentMSL` INT,

   -- The ICTV ID of the taxon to query.
   IN `ictvID` INT,

   -- The MSL associated with the ICTV ID parameter (optional).
   IN `MSL` INT,

   -- The taxnode ID of the taxon to query.
   IN `taxNodeID` INT,

   -- The taxon name to query.
   IN `taxonName` VARCHAR(300),

   -- The VMR / isolate ID.
   IN `vmrID` INT
)
BEGIN

   -- Pre-process the input parameters to arrive at a taxnode_id.
   SET taxonName = TRIM(taxonName);

	-- If taxnode_id wasn't provided, use one of the other parameters to lookup an associated taxnode_id. 
	-- Prioritize parameters as follows: taxnode_id, ictv_iv, vmr_id, taxon_name.
	IF taxNodeID IS NULL OR taxNodeID < 1 THEN
		IF ictvID IS NOT NULL AND ictvID > 0 THEN

         -- Find the most recent taxnode_id associated with the ictv_id.
         SELECT tn.taxnode_id INTO taxNodeID
         FROM taxonomy_node_names tn
         WHERE tn.ictv_id = ictvID
         AND (msl IS NULL OR (msl IS NOT NULL AND tn.msl_release_num = msl))
         ORDER BY tn.msl_release_num DESC
         LIMIT 1;

		ELSEIF vmrID IS NOT NULL AND vmrID > 0 THEN

         -- Find the most appropriate taxnode_id associated with the VMR ID.
         SELECT si.taxnode_id INTO taxNodeID
         FROM species_isolates si
         WHERE si.isolate_id = vmrID
         ORDER BY si.isolate_sort ASC
         LIMIT 1;

		ELSEIF taxonName IS NOT NULL AND LENGTH(taxonName) > 0 THEN

         -- Find the most recent taxnode_id associated with the taxon_name.
         SELECT tn.taxnode_id INTO taxNodeID
         FROM taxonomy_node_names tn
         WHERE tn.name = taxonName
         ORDER BY tn.msl_release_num DESC
         LIMIT 1;

		ELSE 
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Either taxnode_id, ictv_id, vmr_id, or taxon_name must be provided';
      END IF;
	END IF;

	-- Did we get a valid taxnode_id?
	IF taxNodeID IS NULL OR taxNodeID < 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unable to determine taxnode_id';
   END IF;

   WITH taxaChanges AS (
      SELECT
         ictv_id,
         MAX(is_deleted) AS is_deleted,
         MAX(is_demoted) AS is_demoted,
         MAX(is_lineage_updated) AS is_lineage_updated,
         MAX(is_merged) AS is_merged,
         MAX(is_moved) AS is_moved,
         MAX(is_new) AS is_new,
         MAX(is_promoted) AS is_promoted,
         MAX(is_renamed) AS is_renamed,
         MAX(is_split) AS is_split,
         left_idx,
         level_id,
         lineage_ids,
         lineage_names,
         lineage_ranks,
         IFNULL(modifications,0) AS modifications,
         CASE
            WHEN MAX(is_deleted) = 1 THEN taxaAndPrevs.msl_release_num + 1
            ELSE taxaAndPrevs.msl_release_num
         END AS msl_release_num,
         name,
         MAX(prev_notes) AS prev_notes,
         MAX(prev_proposal) AS prev_proposal,
         taxnode_id,
         tree_id 

      FROM (
         SELECT 
            node.ictv_id,
            prev_delta.is_deleted,
            prev_delta.is_demoted,
            prev_delta.is_lineage_updated,
            prev_delta.is_merged,
            prev_delta.is_moved,
            prev_delta.is_new,
            prev_delta.is_promoted,
            prev_delta.is_renamed,
            prev_delta.is_split,
            node.left_idx,
            node.level_id,
            CONCAT(
               CASE WHEN node.realm_id IS NOT NULL THEN CONCAT(CAST(node.realm_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subrealm_id IS NOT NULL THEN CONCAT(CAST(node.subrealm_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.kingdom_id IS NOT NULL THEN CONCAT(CAST(node.kingdom_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subkingdom_id IS NOT NULL THEN CONCAT(CAST(node.subkingdom_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.phylum_id IS NOT NULL THEN CONCAT(CAST(node.phylum_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subphylum_id IS NOT NULL THEN CONCAT(CAST(node.subphylum_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.class_id IS NOT NULL THEN CONCAT(CAST(node.class_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subclass_id IS NOT NULL THEN CONCAT(CAST(node.subclass_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.order_id IS NOT NULL THEN CONCAT(CAST(node.order_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.suborder_id IS NOT NULL THEN CONCAT(CAST(node.suborder_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.family_id IS NOT NULL THEN CONCAT(CAST(node.family_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subfamily_id IS NOT NULL THEN CONCAT(CAST(node.subfamily_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.genus_id IS NOT NULL THEN CONCAT(CAST(node.genus_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subgenus_id IS NOT NULL THEN CONCAT(CAST(node.subgenus_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.species_id IS NOT NULL THEN CONCAT(CAST(node.species_id AS CHAR(12)), ';') ELSE '' END	
            ) AS lineage_ids,
            node.lineage AS lineage_names,
            CONCAT(
               CASE WHEN node.realm_id IS NOT NULL THEN 'Realm;' ELSE '' END, 
               CASE WHEN node.subrealm_id IS NOT NULL THEN 'Subrealm;' ELSE '' END, 
               CASE WHEN node.kingdom_id IS NOT NULL THEN 'Kingdom;' ELSE '' END, 
               CASE WHEN node.subkingdom_id IS NOT NULL THEN 'Subkingdom;' ELSE '' END, 
               CASE WHEN node.phylum_id IS NOT NULL THEN 'Phylum;' ELSE '' END, 
               CASE WHEN node.subphylum_id IS NOT NULL THEN 'Subphylum;' ELSE '' END, 
               CASE WHEN node.class_id IS NOT NULL THEN 'Class;' ELSE '' END, 
               CASE WHEN node.subclass_id IS NOT NULL THEN 'Subclass;' ELSE '' END, 
               CASE WHEN node.order_id IS NOT NULL THEN 'Order;' ELSE '' END, 
               CASE WHEN node.suborder_id IS NOT NULL THEN 'Suborder;' ELSE '' END, 
               CASE WHEN node.family_id IS NOT NULL THEN 'Family;' ELSE '' END, 
               CASE WHEN node.subfamily_id IS NOT NULL THEN 'Subfamily;' ELSE '' END, 
               CASE WHEN node.genus_id IS NOT NULL THEN 'Genus;' ELSE '' END, 
               CASE WHEN node.subgenus_id IS NOT NULL THEN 'Subgenus;' ELSE '' END, 
               CASE WHEN node.species_id IS NOT NULL THEN 'Species;' ELSE '' END 
            ) AS lineage_ranks,
            ( 
               prev_delta.is_deleted |
               prev_delta.is_demoted |
               prev_delta.is_lineage_updated |
               prev_delta.is_merged |
               prev_delta.is_moved |
               prev_delta.is_new |
               prev_delta.is_promoted |   
               prev_delta.is_renamed |   
               prev_delta.is_split
            ) AS modifications,
            node.msl_release_num,
            node.name,
            prev_delta.notes AS prev_notes, 
            prev_delta.proposal AS prev_proposal,  
            node.taxnode_id AS taxnode_id,  
            node.tree_id AS tree_id

         FROM taxonomy_node_x AS node  
         LEFT JOIN taxonomy_node_delta AS prev_delta ON prev_delta.new_taxid = node.taxnode_id
         WHERE node.tree_id >= 19000000
         AND node.msl_release_num <= currentMSL 
         AND node.target_taxnode_id = taxNodeID

         UNION ALL

         -- Any taxon in this subquery has been abolished (see the constraints below).
         SELECT 
            node.ictv_id,
            prev_delta.is_deleted,
            prev_delta.is_demoted,
            prev_delta.is_lineage_updated,
            prev_delta.is_merged,
            prev_delta.is_moved,
            prev_delta.is_new,
            prev_delta.is_promoted,
            prev_delta.is_renamed,
            prev_delta.is_split,
            node.left_idx,
            node.level_id,
            CONCAT(
               CASE WHEN node.realm_id IS NOT NULL THEN CONCAT(CAST(node.realm_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subrealm_id IS NOT NULL THEN CONCAT(CAST(node.subrealm_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.kingdom_id IS NOT NULL THEN CONCAT(CAST(node.kingdom_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subkingdom_id IS NOT NULL THEN CONCAT(CAST(node.subkingdom_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.phylum_id IS NOT NULL THEN CONCAT(CAST(node.phylum_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subphylum_id IS NOT NULL THEN CONCAT(CAST(node.subphylum_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.class_id IS NOT NULL THEN CONCAT(CAST(node.class_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subclass_id IS NOT NULL THEN CONCAT(CAST(node.subclass_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.order_id IS NOT NULL THEN CONCAT(CAST(node.order_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.suborder_id IS NOT NULL THEN CONCAT(CAST(node.suborder_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.family_id IS NOT NULL THEN CONCAT(CAST(node.family_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subfamily_id IS NOT NULL THEN CONCAT(CAST(node.subfamily_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.genus_id IS NOT NULL THEN CONCAT(CAST(node.genus_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.subgenus_id IS NOT NULL THEN CONCAT(CAST(node.subgenus_id AS CHAR(12)), ';') ELSE '' END, 
               CASE WHEN node.species_id IS NOT NULL THEN CONCAT(CAST(node.species_id AS CHAR(12)), ';') ELSE '' END	
            ) AS lineage_ids,
            node.lineage AS lineage_names,
            CONCAT(
               CASE WHEN node.realm_id IS NOT NULL THEN 'Realm;' ELSE '' END, 
               CASE WHEN node.subrealm_id IS NOT NULL THEN 'Subrealm;' ELSE '' END, 
               CASE WHEN node.kingdom_id IS NOT NULL THEN 'Kingdom;' ELSE '' END, 
               CASE WHEN node.subkingdom_id IS NOT NULL THEN 'Subkingdom;' ELSE '' END, 
               CASE WHEN node.phylum_id IS NOT NULL THEN 'Phylum;' ELSE '' END, 
               CASE WHEN node.subphylum_id IS NOT NULL THEN 'Subphylum;' ELSE '' END, 
               CASE WHEN node.class_id IS NOT NULL THEN 'Class;' ELSE '' END, 
               CASE WHEN node.subclass_id IS NOT NULL THEN 'Subclass;' ELSE '' END, 
               CASE WHEN node.order_id IS NOT NULL THEN 'Order;' ELSE '' END, 
               CASE WHEN node.suborder_id IS NOT NULL THEN 'Suborder;' ELSE '' END, 
               CASE WHEN node.family_id IS NOT NULL THEN 'Family;' ELSE '' END, 
               CASE WHEN node.subfamily_id IS NOT NULL THEN 'Subfamily;' ELSE '' END, 
               CASE WHEN node.genus_id IS NOT NULL THEN 'Genus;' ELSE '' END, 
               CASE WHEN node.subgenus_id IS NOT NULL THEN 'Subgenus;' ELSE '' END, 
               CASE WHEN node.species_id IS NOT NULL THEN 'Species;' ELSE '' END 
            ) AS lineage_ranks,
            prev_delta.is_deleted AS modifications,
            node.msl_release_num + 1 AS msl_release_num,
            node.name,
            prev_delta.notes AS prev_notes, 
            prev_delta.proposal AS prev_proposal,
            node.taxnode_id AS taxnode_id,  
            toc.tree_id

         FROM taxonomy_node_x AS node  
         JOIN taxonomy_node_delta AS prev_delta ON (
            prev_delta.is_deleted = 1 
            AND prev_delta.prev_taxid = node.taxnode_id
         )
         JOIN taxonomy_toc toc ON toc.msl_release_num = node.msl_release_num + 1
         WHERE node.tree_id >= 19000000
         AND node.msl_release_num <= currentMSL 
         AND node.target_taxnode_id = taxNodeID
      ) taxaAndPrevs

      GROUP BY taxaAndPrevs.msl_release_num, taxaAndPrevs.taxnode_id, taxaAndPrevs.tree_id, taxaAndPrevs.name, taxaAndPrevs.ictv_id, 
         taxaAndPrevs.is_deleted, taxaAndPrevs.is_demoted, taxaAndPrevs.is_lineage_updated, taxaAndPrevs.is_merged, 
         taxaAndPrevs.is_moved, taxaAndPrevs.is_new, taxaAndPrevs.is_promoted, taxaAndPrevs.is_renamed, taxaAndPrevs.is_split,
         taxaAndPrevs.left_idx, taxaAndPrevs.lineage_ids, taxaAndPrevs.lineage_names, taxaAndPrevs.modifications, taxaAndPrevs.msl_release_num, 
         taxaAndPrevs.name, taxaAndPrevs.prev_notes, taxaAndPrevs.prev_proposal
   )

   SELECT
      filteredTaxa.ictv_id,
      filteredTaxa.is_deleted,
      filteredTaxa.is_demoted,
      filteredTaxa.is_lineage_updated,
      filteredTaxa.is_merged,
      filteredTaxa.is_moved,
      filteredTaxa.is_new,
      filteredTaxa.is_promoted,
      filteredTaxa.is_renamed,
      CASE
         WHEN filteredTaxa.taxnode_id = taxNodeID THEN 1 ELSE 0
      END AS is_selected,
      filteredTaxa.is_split,
      filteredTaxa.lineage_ids,
      filteredTaxa.lineage_names,
      filteredTaxa.lineage_ranks,
      filteredTaxa.msl_release_num,
      filteredTaxa.name,
      
      -- The lineage of the previous version of the taxon.
      prev_tn.lineage AS prev_lineage_names,
      CONCAT(
         CASE WHEN prev_tn.realm_id IS NOT NULL THEN 'Realm;' ELSE '' END, 
         CASE WHEN prev_tn.subrealm_id IS NOT NULL THEN 'Subrealm;' ELSE '' END, 
         CASE WHEN prev_tn.kingdom_id IS NOT NULL THEN 'Kingdom;' ELSE '' END, 
         CASE WHEN prev_tn.subkingdom_id IS NOT NULL THEN 'Subkingdom;' ELSE '' END, 
         CASE WHEN prev_tn.phylum_id IS NOT NULL THEN 'Phylum;' ELSE '' END, 
         CASE WHEN prev_tn.subphylum_id IS NOT NULL THEN 'Subphylum;' ELSE '' END, 
         CASE WHEN prev_tn.class_id IS NOT NULL THEN 'Class;' ELSE '' END, 
         CASE WHEN prev_tn.subclass_id IS NOT NULL THEN 'Subclass;' ELSE '' END, 
         CASE WHEN prev_tn.order_id IS NOT NULL THEN 'Order;' ELSE '' END, 
         CASE WHEN prev_tn.suborder_id IS NOT NULL THEN 'Suborder;' ELSE '' END, 
         CASE WHEN prev_tn.family_id IS NOT NULL THEN 'Family;' ELSE '' END, 
         CASE WHEN prev_tn.subfamily_id IS NOT NULL THEN 'Subfamily;' ELSE '' END, 
         CASE WHEN prev_tn.genus_id IS NOT NULL THEN 'Genus;' ELSE '' END, 
         CASE WHEN prev_tn.subgenus_id IS NOT NULL THEN 'Subgenus;' ELSE '' END, 
         CASE WHEN prev_tn.species_id IS NOT NULL THEN 'Species;' ELSE '' END 
      ) AS prev_lineage_ranks,
      
      -- Names of this taxon's antecedents from the previous release.
      CASE
         WHEN filteredTaxa.is_deleted = 0 AND (filteredTaxa.is_merged = 1 OR filteredTaxa.is_renamed = 1 OR filteredTaxa.is_split = 1) THEN

            -- Format the previous names as a comma-delimited list.
            (SELECT GROUP_CONCAT(tn_previous.name ORDER BY tn_previous.left_idx SEPARATOR ', ')
            FROM taxonomy_node tn_changed
            JOIN taxonomy_node_merge_split ms_changed ON ms_changed.prev_ictv_id = tn_changed.ictv_id
            JOIN taxonomy_node tn_previous ON tn_previous.ictv_id = ms_changed.next_ictv_id
            JOIN taxonomy_node_delta delta_previous ON (
               delta_previous.new_taxid = tn_changed.taxnode_id
               AND delta_previous.prev_taxid = tn_previous.taxnode_id
            )
            WHERE tn_changed.taxnode_id = filteredTaxa.taxnode_id
            AND tn_previous.msl_release_num = (filteredTaxa.msl_release_num - 1)
            )
         ELSE NULL
      END AS prev_names,
      filteredTaxa.prev_notes,
      filteredTaxa.prev_proposal,
      tl.name AS rank_name,
      filteredTaxa.taxnode_id,
      filteredTaxa.tree_id,

      -- Release columns
      filteredTaxa.release_is_current,
      filteredTaxa.release_is_visible,
      filteredTaxa.release_number,
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
         CASE WHEN msl.species > 0 THEN 'species' ELSE '' END  
      ) AS release_rank_names,
      SUBSTRING(msl.notes, 1, 255) AS release_title,  
      msl.year AS release_year

   FROM (
      SELECT
         ictv_id,
         is_deleted,
         is_demoted,
         is_lineage_updated,
         is_merged,
         is_moved,
         is_new,
         is_promoted,
         is_renamed,
         is_split,
         left_idx,
         level_id,
         lineage_ids,
         lineage_names,
         lineage_ranks,
         tc1.msl_release_num,
         name,
         prev_notes,
         prev_proposal,
         taxnode_id,
         tree_id,

         -- Release columns
         releases.is_current AS release_is_current,
         CASE 
            WHEN releases.is_current = 1 OR releases.mods > 0 THEN 1 ELSE 0
         END AS release_is_visible,
         releases.msl_release_num AS release_number

      FROM taxaChanges tc1

      -- Releases that are current, associated with the selected taxon, or have at least one modification.
      JOIN (
         SELECT
            CASE 
	         	WHEN 0 < SUM(CASE WHEN tc2.taxnode_id = taxNodeID THEN 1 ELSE 0 END) THEN 1 ELSE 0 
	         END AS has_selected_taxon,
            CASE WHEN tc2.msl_release_num = currentMSL THEN 1 ELSE 0 END AS is_current,
            SUM(tc2.modifications) AS mods,
            tc2.msl_release_num
         FROM taxaChanges tc2
         GROUP BY tc2.msl_release_num
      ) releases ON (
     	   releases.msl_release_num = tc1.msl_release_num
     	   AND (releases.is_current = 1 
            OR releases.mods > 0 
            OR (releases.has_selected_taxon = 1 AND tc1.taxnode_id = taxNodeID)
     	   )
      )
   ) filteredTaxa

   -- The taxon's rank
   JOIN taxonomy_level tl ON tl.id = filteredTaxa.level_id

   -- Include the previous version for demoted, lineage updated, moved, and promoted taxa.
   LEFT JOIN taxonomy_node prev_tn ON (
      (is_demoted = 1 OR is_lineage_updated = 1 OR is_moved = 1 OR is_promoted = 1)
      AND prev_tn.ictv_id = filteredTaxa.ictv_id
      AND prev_tn.msl_release_num = filteredTaxa.msl_release_num - 1
   )

   -- MSL releases
   JOIN view_taxa_level_counts_by_release msl ON msl.msl_release_num = filteredTaxa.msl_release_num

   ORDER BY 

      -- Sort by release
      filteredTaxa.msl_release_num DESC,

      -- Sort the name alphabetically
      filteredTaxa.left_idx ASC,

      -- The order of changes is New, Abolished, Promoted, Demoted, Merged, Split, Moved, Lineage updated, Renamed, and Unchanged.
      is_new DESC,
      filteredTaxa.is_deleted DESC,
      is_promoted DESC,
      is_demoted DESC,
      is_merged DESC,
      is_split DESC,
      is_moved DESC, 
      is_lineage_updated DESC,
      is_renamed DESC;

END//
DELIMITER ;