/* ------------------------------------------------------------------
    LRM(07302025): Re-port to MariaDB from SQL Server after 
    updates performed by Curtis.
   ------------------------------------------------------------------ */

/* ------------------------------------------------------------------
   taxonomy_node_merge_split
   – tracks merges / splits / resurrections between two ICTV taxa
   ------------------------------------------------------------------ */

DROP TABLE IF EXISTS taxonomy_node_merge_split;

CREATE TABLE taxonomy_node_merge_split (
    /* ----------------------------------------------------------------
       who-to-whom mapping
       ---------------------------------------------------------------- */
    prev_ictv_id   INT           NOT NULL ,      -- source taxon
    next_ictv_id   INT           NOT NULL ,      -- destination / child

    /* ----------------------------------------------------------------
       flags & counters
       ---------------------------------------------------------------- */
    is_merged      TINYINT(1)    NOT NULL DEFAULT 0 ,
    is_split       TINYINT(1)    NOT NULL DEFAULT 0 ,
    is_recreated   TINYINT(1)    NOT NULL DEFAULT 0 ,
    dist           INT UNSIGNED  NOT NULL DEFAULT 0 ,   -- hop distance
    rev_count      INT UNSIGNED  NOT NULL DEFAULT 0 ,   -- reversions

    /* ----------------------------------------------------------------
       keys & constraints
       ---------------------------------------------------------------- */
    PRIMARY KEY (prev_ictv_id, next_ictv_id),

    /*  InnoDB needs an *index* that starts with the FK column(s)
        referenced below.  Because the composite PK begins with
        prev_ictv_id, add a helper index on next_ictv_id.               */
    KEY idx_next_ictv_id (next_ictv_id),

    CONSTRAINT FK_taxonomy_node_merge_split_taxonomy_node1
      FOREIGN KEY (next_ictv_id)
      REFERENCES taxonomy_node (taxnode_id)
      ON UPDATE CASCADE
      ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE        = utf8mb4_general_ci;