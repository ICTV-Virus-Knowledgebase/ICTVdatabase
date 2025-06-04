/* ================================================================
   Stored procedure  : taxonomy_node_compute_indexes
   Converted from    : SQL-Server to MariaDB
   Preserves         : All original comments and behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS taxonomy_node_compute_indexes $$
CREATE PROCEDURE taxonomy_node_compute_indexes
(
    /* ---------------- input / output ---------------- */
    IN  p_taxnode_id        INT,
    IN  p_left_idx          INT,
    OUT p_right_idx         INT,
    IN  p_node_depth        INT,

    /* --------------- running “ancestor cache” --------------- */
    INOUT p_realm_id        INT,
    INOUT p_subrealm_id     INT,
    INOUT p_kingdom_id      INT,
    INOUT p_subkingdom_id   INT,
    INOUT p_phylum_id       INT,
    INOUT p_subphylum_id    INT,
    INOUT p_class_id        INT,
    INOUT p_subclass_id     INT,
    INOUT p_order_id        INT,
    INOUT p_suborder_id     INT,
    INOUT p_family_id       INT,
    INOUT p_subfamily_id    INT,
    INOUT p_genus_id        INT,
    INOUT p_subgenus_id     INT,
    INOUT p_species_id      INT,

    /* --------------- descendant-count OUTPUTS --------------- */
    INOUT p_realm_desc_ct       INT,
    INOUT p_subrealm_desc_ct    INT,
    INOUT p_kingdom_desc_ct     INT,
    INOUT p_subkingdom_desc_ct  INT,
    INOUT p_phylum_desc_ct      INT,
    INOUT p_subphylum_desc_ct   INT,
    INOUT p_class_desc_ct       INT,
    INOUT p_subclass_desc_ct    INT,
    INOUT p_order_desc_ct       INT,
    INOUT p_suborder_desc_ct    INT,
    INOUT p_family_desc_ct      INT,
    INOUT p_subfamily_desc_ct   INT,
    INOUT p_genus_desc_ct       INT,
    INOUT p_subgenus_desc_ct    INT,
    INOUT p_species_desc_ct     INT,

    /* other running values */
    INOUT p_inher_molecule_id   INT,
    INOUT p_lineage             VARCHAR(1000)
)
BEGIN
    /* -----------------------------------------------------------------
       Local variables – same names & semantics as in the SQL-Server SP
       ----------------------------------------------------------------- */
    DECLARE v_hidden_as_unassigned   TINYINT  DEFAULT 1;
    DECLARE v_use_my_lineage         TINYINT;
    DECLARE v_my_lineage             VARCHAR(1000);

    /* direct-kid counters (initialised to 0) */
    DECLARE v_realm_kid_ct,      v_subrealm_kid_ct,  v_kingdom_kid_ct,
            v_subkingdom_kid_ct, v_phylum_kid_ct,    v_subphylum_kid_ct,
            v_class_kid_ct,      v_subclass_kid_ct,  v_order_kid_ct,
            v_suborder_kid_ct,   v_family_kid_ct,    v_subfamily_kid_ct,
            v_genus_kid_ct,      v_subgenus_kid_ct,  v_species_kid_ct  INT DEFAULT 0;

    /* working vars for the child loop */
    DECLARE v_child_taxnode_id   INT;
    DECLARE v_child_rank         VARCHAR(50);
    DECLARE v_child_is_hidden    TINYINT;
    DECLARE v_child_depth        INT;

    /* descendant counts returned from recursive calls */
    DECLARE k_realm_desc_ct,      k_subrealm_desc_ct,  k_kingdom_desc_ct,
            k_subkingdom_desc_ct, k_phylum_desc_ct,    k_subphylum_desc_ct,
            k_class_desc_ct,      k_subclass_desc_ct,  k_order_desc_ct,
            k_suborder_desc_ct,   k_family_desc_ct,    k_subfamily_desc_ct,
            k_genus_desc_ct,      k_subgenus_desc_ct,  k_species_desc_ct  INT;
    
    /* -----------------------------------------------------------------
    MariaDB does not like defaults in parameter list
    Supply defaults the old header used to give
     ----------------------------------------------------------------- */
	IF p_left_idx   IS NULL THEN SET p_left_idx   := 1; END IF;
    IF p_node_depth IS NULL THEN SET p_node_depth := 1; END IF;

    /* -----------------------------------------------------------------
       Read this node once (rank, flags, etc.)
       ----------------------------------------------------------------- */
    SELECT
          /* ---- update cached ancestor IDs if this node IS that rank --- */
          IFNULL(p_realm_id      , CASE WHEN l.name='realm'       THEN n.taxnode_id END),
          IFNULL(p_subrealm_id   , CASE WHEN l.name='subrealm'    THEN n.taxnode_id END),
          IFNULL(p_kingdom_id    , CASE WHEN l.name='kingdom'     THEN n.taxnode_id END),
          IFNULL(p_subkingdom_id , CASE WHEN l.name='subkingdom'  THEN n.taxnode_id END),
          IFNULL(p_phylum_id     , CASE WHEN l.name='phylum'      THEN n.taxnode_id END),
          IFNULL(p_subphylum_id  , CASE WHEN l.name='subphylum'   THEN n.taxnode_id END),
          IFNULL(p_class_id      , CASE WHEN l.name='class'       THEN n.taxnode_id END),
          IFNULL(p_subclass_id   , CASE WHEN l.name='subclass'    THEN n.taxnode_id END),
          IFNULL(p_order_id      , CASE WHEN l.name='order'       THEN n.taxnode_id END),
          IFNULL(p_suborder_id   , CASE WHEN l.name='suborder'    THEN n.taxnode_id END),
          IFNULL(p_family_id     , CASE WHEN l.name='family'      THEN n.taxnode_id END),
          IFNULL(p_subfamily_id  , CASE WHEN l.name='subfamily'   THEN n.taxnode_id END),
          IFNULL(p_genus_id      , CASE WHEN l.name='genus'       THEN n.taxnode_id END),
          IFNULL(p_subgenus_id   , CASE WHEN l.name='subgenus'    THEN n.taxnode_id END),
          IFNULL(p_species_id    , CASE WHEN l.name='species'     THEN n.taxnode_id END),

          /* inherit molecule */
          COALESCE(n.molecule_id , p_inher_molecule_id),

          /* decide whether this node’s name belongs in children’s lineage */
          CASE 
              WHEN n.taxnode_id = n.tree_id THEN 0
              WHEN v_hidden_as_unassigned   = 1 THEN 1
              WHEN n.is_hidden = 1 OR n.name IS NULL THEN 0
              ELSE 1
          END                                                AS use_my_lineage,

          /* build lineage string for this node */
          CONCAT_WS('',
                    IFNULL(p_lineage,''),
                    IF(LENGTH(IFNULL(p_lineage,''))>0, ';', ''),
                    IF(n.is_hidden = 1 AND v_hidden_as_unassigned = 0, '[', ''),
                    IFNULL(n.name,
                           IF(v_hidden_as_unassigned = 1,'Unassigned','- unnamed -')
                    ),
                    IF(n.is_hidden = 1 AND v_hidden_as_unassigned = 0, ']', '')
          )                                                 AS my_lineage
     INTO  p_realm_id,   p_subrealm_id,  p_kingdom_id, p_subkingdom_id,
          p_phylum_id,   p_subphylum_id, p_class_id,   p_subclass_id,
          p_order_id,    p_suborder_id,  p_family_id,  p_subfamily_id,
          p_genus_id,    p_subgenus_id,  p_species_id,
          p_inher_molecule_id,
          v_use_my_lineage,
          v_my_lineage
     FROM  taxonomy_node  AS n
     JOIN  taxonomy_level AS l  ON l.id = n.level_id
     WHERE n.taxnode_id = p_taxnode_id;

    /* -----------------------------------------------------------------
       Write LEFT index + depth (+ cached ancestor IDs) back to this node
       Only perform UPDATE when something really changed (same logic as T-SQL)
       ----------------------------------------------------------------- */
    UPDATE taxonomy_node SET
          left_idx        = p_left_idx,
          node_depth      = p_node_depth,
          /* cached ancestor IDs */
          realm_id        = p_realm_id,
          subrealm_id     = p_subrealm_id,
          kingdom_id      = p_kingdom_id,
          subkingdom_id   = p_subkingdom_id,
          phylum_id       = p_phylum_id,
          subphylum_id    = p_subphylum_id,
          class_id        = p_class_id,
          subclass_id     = p_subclass_id,
          order_id        = p_order_id,
          suborder_id     = p_suborder_id,
          family_id       = p_family_id,
          subfamily_id    = p_subfamily_id,
          genus_id        = p_genus_id,
          subgenus_id     = p_subgenus_id,
          species_id      = p_species_id,
          inher_molecule_id = p_inher_molecule_id,
          lineage         = v_my_lineage
    WHERE taxnode_id = p_taxnode_id
      AND (
              left_idx          <> p_left_idx        OR left_idx        IS NULL
           OR node_depth        <> p_node_depth      OR node_depth      IS NULL
           OR realm_id          <> p_realm_id        OR (realm_id       IS NULL AND p_realm_id       IS NOT NULL)
           OR subrealm_id       <> p_subrealm_id     OR (subrealm_id    IS NULL AND p_subrealm_id    IS NOT NULL)
           OR kingdom_id        <> p_kingdom_id      OR (kingdom_id     IS NULL AND p_kingdom_id     IS NOT NULL)
           OR subkingdom_id     <> p_subkingdom_id   OR (subkingdom_id  IS NULL AND p_subkingdom_id  IS NOT NULL)
           OR phylum_id         <> p_phylum_id       OR (phylum_id      IS NULL AND p_phylum_id      IS NOT NULL)
           OR subphylum_id      <> p_subphylum_id    OR (subphylum_id   IS NULL AND p_subphylum_id   IS NOT NULL)
           OR class_id          <> p_class_id        OR (class_id       IS NULL AND p_class_id       IS NOT NULL)
           OR subclass_id       <> p_subclass_id     OR (subclass_id    IS NULL AND p_subclass_id    IS NOT NULL)
           OR order_id          <> p_order_id        OR (order_id       IS NULL AND p_order_id       IS NOT NULL)
           OR suborder_id       <> p_suborder_id     OR (suborder_id    IS NULL AND p_suborder_id    IS NOT NULL)
           OR family_id         <> p_family_id       OR (family_id      IS NULL AND p_family_id      IS NOT NULL)
           OR subfamily_id      <> p_subfamily_id    OR (subfamily_id   IS NULL AND p_subfamily_id   IS NOT NULL)
           OR genus_id          <> p_genus_id        OR (genus_id       IS NULL AND p_genus_id       IS NOT NULL)
           OR subgenus_id       <> p_subgenus_id     OR (subgenus_id    IS NULL AND p_subgenus_id    IS NOT NULL)
           OR species_id        <> p_species_id      OR (species_id     IS NULL AND p_species_id     IS NOT NULL)
           OR inher_molecule_id <> p_inher_molecule_id OR (inher_molecule_id IS NULL AND p_inher_molecule_id IS NOT NULL)
           OR lineage           <> v_my_lineage      OR (lineage        IS NULL AND v_my_lineage     IS NOT NULL)
      );

    /* -----------------------------------------------------------------
       Decide whether children should inherit the lineage string
       ----------------------------------------------------------------- */
    IF v_use_my_lineage = 1 THEN
        SET p_lineage = v_my_lineage;
    END IF;

    /* -----------------------------------------------------------------
       Walk children (recursion).  Re-implements the T-SQL loop that
       repeatedly “SELECT TOP 1 … WHERE left_idx IS NULL … ORDER BY …”
       ----------------------------------------------------------------- */
    SET p_right_idx = p_left_idx + 1;
    SET v_child_depth = p_node_depth + 1;

    child_loop: LOOP
        /* -------- get next child that still has NULL left_idx -------- */
        SELECT n.taxnode_id,
               n.is_hidden,
               l.name
          INTO v_child_taxnode_id,
               v_child_is_hidden,
               v_child_rank
          FROM taxonomy_node AS n
          JOIN taxonomy_level AS l  ON l.id = n.level_id
         WHERE n.parent_id   = p_taxnode_id
           AND n.taxnode_id <> p_taxnode_id
           AND n.left_idx   IS NULL
         ORDER BY n.level_id,
                  CASE
                       WHEN n.start_num_sort IS NULL
                              THEN IFNULL(n.name,'ZZZZ')
                       ELSE LEFT(n.name, n.start_num_sort)
                  END,
                  CASE
                       WHEN n.start_num_sort IS NULL
                              THEN NULL
                       ELSE CAST(
                       			TRIM(LEADING ' '
                       				FROM SUBSTRING(n.name, n.start_num_sort + 1)
                       ) AS UNSIGNED)
                  END
         LIMIT 1;

        /* ---------- no more children? then leave the loop ------------ */
        IF v_child_taxnode_id IS NULL THEN
            LEAVE child_loop;
        END IF;

        /* -------- recursive call : initialise child descendant vars --- */
        SET k_realm_desc_ct      = 0;
        SET k_subrealm_desc_ct   = 0;
        SET k_kingdom_desc_ct    = 0;
        SET k_subkingdom_desc_ct = 0;
        SET k_phylum_desc_ct     = 0;
        SET k_subphylum_desc_ct  = 0;
        SET k_class_desc_ct      = 0;
        SET k_subclass_desc_ct   = 0;
        SET k_order_desc_ct      = 0;
        SET k_suborder_desc_ct   = 0;
        SET k_family_desc_ct     = 0;
        SET k_subfamily_desc_ct  = 0;
        SET k_genus_desc_ct      = 0;
        SET k_subgenus_desc_ct   = 0;
        SET k_species_desc_ct    = 0;

        CALL taxonomy_node_compute_indexes
        (
            v_child_taxnode_id,
            p_right_idx,
            p_right_idx,          -- OUT param comes back with updated value
            v_child_depth,

            /* ancestor IDs */
            p_realm_id, p_subrealm_id, p_kingdom_id, p_subkingdom_id,
            p_phylum_id, p_subphylum_id, p_class_id, p_subclass_id,
            p_order_id, p_suborder_id, p_family_id, p_subfamily_id,
            p_genus_id, p_subgenus_id, p_species_id,

            /* descendant counts OUT */
            k_realm_desc_ct,      k_subrealm_desc_ct,   k_kingdom_desc_ct,
            k_subkingdom_desc_ct, k_phylum_desc_ct,     k_subphylum_desc_ct,
            k_class_desc_ct,      k_subclass_desc_ct,   k_order_desc_ct,
            k_suborder_desc_ct,   k_family_desc_ct,     k_subfamily_desc_ct,
            k_genus_desc_ct,      k_subgenus_desc_ct,   k_species_desc_ct,

            /* molecule & lineage */
            p_inher_molecule_id,
            p_lineage
        );
            

        /* -------- update direct kid counters (only if not hidden) ----- */
        IF v_child_is_hidden = 0 THEN
            IF v_child_rank = 'realm'      THEN SET v_realm_kid_ct       = v_realm_kid_ct       + 1;
            ELSEIF v_child_rank = 'subrealm'   THEN SET v_subrealm_kid_ct    = v_subrealm_kid_ct    + 1;
            ELSEIF v_child_rank = 'kingdom'    THEN SET v_kingdom_kid_ct     = v_kingdom_kid_ct     + 1;
            ELSEIF v_child_rank = 'subkingdom' THEN SET v_subkingdom_kid_ct  = v_subkingdom_kid_ct  + 1;
            ELSEIF v_child_rank = 'phylum'     THEN SET v_phylum_kid_ct      = v_phylum_kid_ct      + 1;
            ELSEIF v_child_rank = 'subphylum'  THEN SET v_subphylum_kid_ct   = v_subphylum_kid_ct   + 1;
            ELSEIF v_child_rank = 'class'      THEN SET v_class_kid_ct       = v_class_kid_ct       + 1;
            ELSEIF v_child_rank = 'subclass'   THEN SET v_subclass_kid_ct    = v_subclass_kid_ct    + 1;
            ELSEIF v_child_rank = 'order'      THEN SET v_order_kid_ct       = v_order_kid_ct       + 1;
            ELSEIF v_child_rank = 'suborder'   THEN SET v_suborder_kid_ct    = v_suborder_kid_ct    + 1;
            ELSEIF v_child_rank = 'family'     THEN SET v_family_kid_ct      = v_family_kid_ct      + 1;
            ELSEIF v_child_rank = 'subfamily'  THEN SET v_subfamily_kid_ct   = v_subfamily_kid_ct   + 1;
            ELSEIF v_child_rank = 'genus'      THEN SET v_genus_kid_ct       = v_genus_kid_ct       + 1;
            ELSEIF v_child_rank = 'subgenus'   THEN SET v_subgenus_kid_ct    = v_subgenus_kid_ct    + 1;
            ELSEIF v_child_rank = 'species'    THEN SET v_species_kid_ct     = v_species_kid_ct     + 1;
        	END IF;
        END IF;

--         /* -------- add descendant totals from child to this node -------- */
        SET p_realm_desc_ct       = p_realm_desc_ct       + k_realm_desc_ct;
        SET p_subrealm_desc_ct    = p_subrealm_desc_ct    + k_subrealm_desc_ct;
        SET p_kingdom_desc_ct     = p_kingdom_desc_ct     + k_kingdom_desc_ct;
        SET p_subkingdom_desc_ct  = p_subkingdom_desc_ct  + k_subkingdom_desc_ct;
        SET p_phylum_desc_ct      = p_phylum_desc_ct      + k_phylum_desc_ct;
        SET p_subphylum_desc_ct   = p_subphylum_desc_ct   + k_subphylum_desc_ct;
        SET p_class_desc_ct       = p_class_desc_ct       + k_class_desc_ct;
        SET p_subclass_desc_ct    = p_subclass_desc_ct    + k_subclass_desc_ct;
        SET p_order_desc_ct       = p_order_desc_ct       + k_order_desc_ct;
        SET p_suborder_desc_ct    = p_suborder_desc_ct    + k_suborder_desc_ct;
        SET p_family_desc_ct      = p_family_desc_ct      + k_family_desc_ct;
        SET p_subfamily_desc_ct   = p_subfamily_desc_ct   + k_subfamily_desc_ct;
        SET p_genus_desc_ct       = p_genus_desc_ct       + k_genus_desc_ct;
        SET p_subgenus_desc_ct    = p_subgenus_desc_ct    + k_subgenus_desc_ct;
        SET p_species_desc_ct     = p_species_desc_ct     + k_species_desc_ct;

        /* -------- move right-index forward ready for next sibling ------ */
        SET p_right_idx = p_right_idx + 1;
    END LOOP child_loop;

    /* -----------------------------------------------------------------
       Add direct-kid counts to descendant totals for this node
       ----------------------------------------------------------------- */
    SET p_realm_desc_ct       = p_realm_desc_ct       + v_realm_kid_ct;
    SET p_subrealm_desc_ct    = p_subrealm_desc_ct    + v_subrealm_kid_ct;
    SET p_kingdom_desc_ct     = p_kingdom_desc_ct     + v_kingdom_kid_ct;
    SET p_subkingdom_desc_ct  = p_subkingdom_desc_ct  + v_subkingdom_kid_ct;
    SET p_phylum_desc_ct      = p_phylum_desc_ct      + v_phylum_kid_ct;
    SET p_subphylum_desc_ct   = p_subphylum_desc_ct   + v_subphylum_kid_ct;
    SET p_class_desc_ct       = p_class_desc_ct       + v_class_kid_ct;
    SET p_subclass_desc_ct    = p_subclass_desc_ct    + v_subclass_kid_ct;
    SET p_order_desc_ct       = p_order_desc_ct       + v_order_kid_ct;
    SET p_suborder_desc_ct    = p_suborder_desc_ct    + v_suborder_kid_ct;
    SET p_family_desc_ct      = p_family_desc_ct      + v_family_kid_ct;
    SET p_subfamily_desc_ct   = p_subfamily_desc_ct   + v_subfamily_kid_ct;
    SET p_genus_desc_ct       = p_genus_desc_ct       + v_genus_kid_ct;
    SET p_subgenus_desc_ct    = p_subgenus_desc_ct    + v_subgenus_kid_ct;
    SET p_species_desc_ct     = p_species_desc_ct     + v_species_kid_ct;

    /* -----------------------------------------------------------------
       Final UPDATE that writes RIGHT index plus kid/desc counts / strings
       ----------------------------------------------------------------- */
    UPDATE taxonomy_node SET
          right_idx          = p_right_idx,

          realm_desc_ct      = p_realm_desc_ct      , realm_kid_ct      = v_realm_kid_ct,
          subrealm_desc_ct   = p_subrealm_desc_ct   , subrealm_kid_ct   = v_subrealm_kid_ct,
          kingdom_desc_ct    = p_kingdom_desc_ct    , kingdom_kid_ct    = v_kingdom_kid_ct,
          subkingdom_desc_ct = p_subkingdom_desc_ct , subkingdom_kid_ct = v_subkingdom_kid_ct,
          phylum_desc_ct     = p_phylum_desc_ct     , phylum_kid_ct     = v_phylum_kid_ct,
          subphylum_desc_ct  = p_subphylum_desc_ct  , subphylum_kid_ct  = v_subphylum_kid_ct,
          class_desc_ct      = p_class_desc_ct      , class_kid_ct      = v_class_kid_ct,
          subclass_desc_ct   = p_subclass_desc_ct   , subclass_kid_ct   = v_subclass_kid_ct,
          order_desc_ct      = p_order_desc_ct      , order_kid_ct      = v_order_kid_ct,
          suborder_desc_ct   = p_suborder_desc_ct   , suborder_kid_ct   = v_suborder_kid_ct,
          family_desc_ct     = p_family_desc_ct     , family_kid_ct     = v_family_kid_ct,
          subfamily_desc_ct  = p_subfamily_desc_ct  , subfamily_kid_ct  = v_subfamily_kid_ct,
          genus_desc_ct      = p_genus_desc_ct      , genus_kid_ct      = v_genus_kid_ct,
          subgenus_desc_ct   = p_subgenus_desc_ct   , subgenus_kid_ct   = v_subgenus_kid_ct,
          species_desc_ct    = p_species_desc_ct    , species_kid_ct    = v_species_kid_ct,

          /* stringified kid/desc counts (call your MariaDB version of the UDF) */
          taxa_kid_cts  = udf_rankCountsToStringWithPurals(
                              v_realm_kid_ct,      v_subrealm_kid_ct,
                              v_kingdom_kid_ct,    v_subkingdom_kid_ct,
                              v_phylum_kid_ct,     v_subphylum_kid_ct,
                              v_class_kid_ct,      v_subclass_kid_ct,
                              v_order_kid_ct,      v_suborder_kid_ct,
                              v_family_kid_ct,     v_subfamily_kid_ct,
                              v_genus_kid_ct,      v_subgenus_kid_ct,
                              v_species_kid_ct ),
          taxa_desc_cts = udf_rankCountsToStringWithPurals(
                              p_realm_desc_ct,      p_subrealm_desc_ct,
                              p_kingdom_desc_ct,    p_subkingdom_desc_ct,
                              p_phylum_desc_ct,     p_subphylum_desc_ct,
                              p_class_desc_ct,      p_subclass_desc_ct,
                              p_order_desc_ct,      p_suborder_desc_ct,
                              p_family_desc_ct,     p_subfamily_desc_ct,
                              p_genus_desc_ct,      p_subgenus_desc_ct,
                              p_species_desc_ct )
    WHERE taxnode_id = p_taxnode_id;
END$$
DELIMITER ;