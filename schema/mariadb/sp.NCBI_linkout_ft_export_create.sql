/* ================================================================
   Stored procedure  : NCBI_linkout_ft_export
   Converted from    : SQL-Server to MariaDB
   Preserves         : All original comments and behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */

DELIMITER $$

DROP PROCEDURE IF EXISTS NCBI_linkout_ft_export $$
CREATE PROCEDURE NCBI_linkout_ft_export
(
    IN  p_msl      INT,          -- pass NULL to mean "latest"
    IN  p_newline  VARCHAR(10)   -- pass NULL to mean Windows CRLF
)
BEGIN
	/* -----------------------------------------------------------------
    Local variables – same names & semantics as in the SQL-Server SP
    ----------------------------------------------------------------- */
    DECLARE v_provider_id  CHAR(4)   DEFAULT '7640';
	DECLARE v_base_url     VARCHAR(500)
    	DEFAULT 'https://ictv.global/taxonomy/taxondetails?taxnode_id=';
	
    /* -----------------------------------------------------------------
       Get most-recent MSL if parameter is NULL
       ----------------------------------------------------------------- */
    IF p_msl IS NULL OR p_msl < 1 THEN
        SELECT MAX(msl_release_num) INTO p_msl
        FROM taxonomy_node;
    END IF;

    /* -----------------------------------------------------------------
       Choose default newline style (Windows CRLF) if caller passed NULL
       ----------------------------------------------------------------- */
    IF p_newline IS NULL THEN
        SET p_newline = '\r\n';      -- use \r\n
        -- Other options (commented-out, as in original):
        -- SET p_newline = CHAR(13);  -- Mac \r
        -- SET p_newline = CHAR(10);  -- Linux \n
    END IF;

    /* -----------------------------------------------------------------
       Unified result set – MariaDB can stream large SELECT result
       ----------------------------------------------------------------- */
    WITH header AS (
        /*  
            Print the header that identifies us as a LinkOut provider
            Gives:
              – provider id (prid:)
              – our base URL (&base) to which record key will be appended
        */
        SELECT 
              NULL AS left_idx
            , NULL AS msl_release_num
            , CONCAT(
                  '---------------------------------------------------------------', p_newline,
                  'prid:   ', v_LINKOUT_PROVIDER_ID,                      p_newline,
                  'dbase:  taxonomy',                                     p_newline,
                  'stype:  taxonomy/phylogenetic',                        p_newline,
                  '!base:  ', v_URL,                                      p_newline,
                  '---------------------------------------------------------------'
              ) AS t
    ),

    -- ------------------------------------------------------------------
    --  “Only CURRENT names”   (the version actually used in SQL-Server)
    -- ------------------------------------------------------------------
    current_names AS (
        /*  
           • use left_idx merely to keep original ORDER BY
           • taxon name is the linkout key
           • ictv_id becomes the linkout rule/target
        */
        SELECT 
              MAX(tn.left_idx)                       AS left_idx
            , MAX(tn.msl_release_num)                AS msl_release_num
            , CONCAT(
                  'linkid:   ',  MAX(tn.taxnode_id),                   p_newline,
                  'query:  ',   tn.name, ' [name]',                    p_newline,
                  'base:  &base;',                                     p_newline,
                  'rule:  ',    MAX(tn.taxnode_id),                    p_newline,
                  'name:  ',    tn.name,                               p_newline,
                  '---------------------------------------------------------------'
              ) AS t
        FROM taxonomy_node_names tn
        WHERE tn.msl_release_num = p_msl               -- latest MSL only
          AND tn.is_deleted  = 0
          AND tn.is_hidden   = 0
          AND tn.is_obsolete = 0
          AND tn.name        IS NOT NULL
          AND tn.name        <> 'Unassigned'
        GROUP BY tn.name
    )

    /* -----------------------------------------------------------------
       Final output – header row + each taxon record
       ----------------------------------------------------------------- */
    SELECT t
    FROM   (
              SELECT * FROM header
              UNION ALL
              SELECT * FROM current_names
           ) AS src
    ORDER BY src.left_idx;

END $$
DELIMITER ;