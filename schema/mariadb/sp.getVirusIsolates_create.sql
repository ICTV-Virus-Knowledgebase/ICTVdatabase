DELIMITER //

CREATE OR REPLACE PROCEDURE getVirusIsolates(
   IN ictvID INT,
   IN isolateID INT,
   IN mslRelease INT,
   IN onlyUnassigned BOOLEAN,
   IN searchTaxon NVARCHAR(100),
   IN taxnodeID INT
)
main:BEGIN

   DECLARE speciesLevelID INT;
   DECLARE targetLeftIndex INT;
   DECLARE targetLevelID INT;
   DECLARE targetRightIndex INT;
   DECLARE targetTaxNodeID INT;
   DECLARE tempMslRelease INT;
   

   -- Normalize input parameters to simplify later processing.
   IF ictvID IS NOT NULL AND ictvID < 1 THEN
      SET ictvID = NULL;
   END IF;

   IF isolateID IS NOT NULL AND isolateID < 1 THEN
      SET isolateID = NULL;
   END IF;
	
   IF mslRelease IS NOT NULL AND mslRelease < 1 THEN
      SET mslRelease = NULL;
   END IF;

   SET searchTaxon = TRIM(searchTaxon);
	IF searchTaxon IS NOT NULL AND LENGTH(searchTaxon) < 1 THEN
		SET searchTaxon = NULL;
	END IF;

   IF taxnodeID IS NOT NULL AND taxnodeID < 1 THEN
      SET taxnodeID = NULL;
   END IF;


   -- If an ICTV ID was provided, use it to look up the target node.
   IF ictvID IS NOT NULL AND ictvID > 0 THEN

      SELECT 
         tn.left_idx, 
         tn.level_id,
         tn.msl_release_num,
         tn.right_idx,
         tn.taxnode_id
      INTO 
         targetLeftIndex,
         targetLevelID,
         mslRelease,
         targetRightIndex,
         targetTaxNodeID
         
      FROM taxonomy_node tn
      WHERE tn.ictv_id = ictvID
      AND (mslRelease IS NULL OR (mslRelease IS NOT NULL AND tn.msl_release_num = mslRelease))
      ORDER BY tn.msl_release_num DESC
      LIMIT 1;

   -- If an isolate ID was provided, use it to look up the target node.
   ELSEIF isolateID IS NOT NULL AND isolateID > 0 THEN

      SELECT 
         tn.left_idx, 
         tn.level_id,
         tn.msl_release_num,
         tn.right_idx,
         tn.taxnode_id
      INTO 
         targetLeftIndex,
         targetLevelID,
         tempMslRelease,
         targetRightIndex,
         targetTaxNodeID

      FROM species_isolates si
      JOIN taxonomy_node tn ON tn.taxnode_id = si.taxnode_id
      WHERE si.isolate_id = isolateID
      LIMIT 1;
   
      IF targetTaxNodeID IS NULL OR tempMslRelease IS NULL THEN
         SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 1644, MESSAGE_TEXT = 'Invalid isolateID parameter';
      END IF;

      SET mslRelease = tempMslRelease;

   -- If a search taxon was provided (but not a taxnodeID), use it to look up the target node.
   ELSEIF taxnodeID IS NULL AND searchTaxon IS NOT NULL THEN

      -- Default the MSL release number to the most recent if not provided.
      IF mslRelease IS NULL OR mslRelease < 1 THEN
         SELECT MAX(msl_release_num) INTO mslRelease FROM taxonomy_toc;
      END IF;

      -- Use the searchTaxon to look up the target node.
      SELECT 
         tn.left_idx, 
         tn.level_id,
         tn.right_idx,
         tn.taxnode_id
      INTO 
         targetLeftIndex,
         targetLevelID,
         targetRightIndex,
         targetTaxNodeID

      FROM taxonomy_node tn
      WHERE tn.name = searchTaxon
      AND tn.msl_release_num = mslRelease
      LIMIT 1;

      IF targetTaxNodeID IS NULL THEN
         SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 1644, MESSAGE_TEXT = 'No taxonomy node was found for the searchTaxon provided';
      END IF;

   ELSEIF taxnodeID IS NOT NULL THEN
   
      -- Use the taxnodeID to look up the target node.
      SELECT 
         tn.left_idx, 
         tn.level_id,
         tn.msl_release_num,
         tn.right_idx,
         tn.taxnode_id
      INTO 
         targetLeftIndex,
         targetLevelID,
         mslRelease,
         targetRightIndex,
         targetTaxNodeID
         
      FROM taxonomy_node tn
      WHERE tn.taxnode_id = taxnodeID
      LIMIT 1;

   ELSE
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 1644, MESSAGE_TEXT = 'Unable to identify the target taxonomy node';
   END IF;

   -- Validate the target node values.
   IF targetLeftIndex IS NULL OR targetLevelID IS NULL OR targetRightIndex IS NULL OR targetTaxNodeID IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 1644, MESSAGE_TEXT = 'Invalid target node values';
   END IF;

   -- Get species level ID
   SELECT id INTO speciesLevelID FROM taxonomy_level WHERE name = 'species' LIMIT 1;
   IF speciesLevelID IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 1644, MESSAGE_TEXT = 'Could not find species level ID';
   END IF;

   
   -- Return virus isolates for species under the target node.
   SELECT 
      si.isolate_id AS isolate_id,
      IFNULL(si.isolate_abbrevs, '') AS abbrev,
      IFNULL(si.genbank_accessions, '') AS accession_number,
      IFNULL(si.isolate_names, '') AS alternative_name_csv,
      IFNULL(si.genome_coverage, '') AS available_sequence,
      si.isolate_type AS exemplar,
      IFNULL(si.isolate_designation, '') AS isolate,
      IFNULL(si.refseq_accessions, '') AS refseq_accession,
      species.taxnode_id,

      IFNULL(subrealm.name, '') AS subrealm,
      IFNULL(kingdom.name, '') AS kingdom,
      IFNULL(subkingdom.name, '') AS subkingdom,
      IFNULL(phylum.name, '') AS phylum,
      IFNULL(class.name, '') AS `class`,
      IFNULL(subclass.name, '') AS subclass,
      IFNULL(`order`.name, '') AS `order`,
      IFNULL(suborder.name, '') AS suborder,
      IFNULL(family.name, '') AS family,
      IFNULL(subfamily.name, '') AS subfamily,
      IFNULL(genus.name, '') AS genus,
      IFNULL(subgenus.name, '') AS subgenus,
      species.name AS species

   FROM taxonomy_node species
   JOIN species_isolates si ON si.taxnode_id = species.taxnode_id

   LEFT JOIN taxonomy_node subrealm ON (
      species.subrealm_id IS NOT NULL
      AND subrealm.taxnode_id = species.subrealm_id
      AND subrealm.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node kingdom ON (
      species.kingdom_id IS NOT NULL
      AND kingdom.taxnode_id = species.kingdom_id
      AND kingdom.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node subkingdom ON (
      species.subkingdom_id IS NOT NULL
      AND subkingdom.taxnode_id = species.subkingdom_id
        AND subkingdom.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node phylum ON (
      species.phylum_id IS NOT NULL
      AND phylum.taxnode_id = species.phylum_id
      AND phylum.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node subphylum ON (
      species.subphylum_id IS NOT NULL
      AND subphylum.taxnode_id = species.subphylum_id
      AND subphylum.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node `class` ON (
      species.class_id IS NOT NULL
      AND `class`.taxnode_id = species.class_id
      AND `class`.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node subclass ON (
      species.subclass_id IS NOT NULL
      AND subclass.taxnode_id = species.subclass_id
      AND subclass.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node `order` ON (
      species.order_id IS NOT NULL
      AND `order`.taxnode_id = species.order_id
      AND `order`.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node suborder ON (
      species.suborder_id IS NOT NULL
      AND suborder.taxnode_id = species.suborder_id
      AND suborder.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node family ON (
      species.family_id IS NOT NULL
      AND family.taxnode_id = species.family_id
      AND family.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node subfamily ON (
      species.subfamily_id IS NOT NULL
      AND subfamily.taxnode_id = species.subfamily_id
      AND subfamily.level_id > targetLevelID
   )

   LEFT JOIN taxonomy_node genus ON genus.taxnode_id = species.genus_id

   LEFT JOIN taxonomy_node subgenus ON (
      species.subgenus_id IS NOT NULL
      AND subgenus.taxnode_id = species.subgenus_id
      AND subgenus.level_id > targetLevelID
   )

   WHERE species.left_idx BETWEEN targetLeftIndex AND targetRightIndex
   AND species.msl_release_num = mslRelease
   AND species.is_deleted = 0
   AND species.is_hidden = 0
   AND species.is_obsolete = 0
   AND species.level_id = speciesLevelID
   AND (
      onlyUnassigned = 0
      OR (onlyUnassigned = 1 
         AND (genus.name = 'unassigned' 
            OR (species.genus_id IS NULL AND species.subgenus_id IS NULL)
         )
         AND species.parent_id = targetTaxNodeID
      )
   )
   ORDER BY species.left_idx, si.isolate_sort;

END//

DELIMITER ;