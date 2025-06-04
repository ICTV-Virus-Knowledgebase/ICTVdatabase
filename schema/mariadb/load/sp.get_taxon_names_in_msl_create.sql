/* ================================================================
   Stored procedure  : get_taxon_names_in_msl   (MariaDB version)
   Converted from    : SQL-Server table-valued function
   Behaviour         : Identical result-set
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS get_taxon_names_in_msl $$
CREATE PROCEDURE get_taxon_names_in_msl
(
    IN  p_name NVARCHAR(250),
    IN  p_msl  INT
)
BEGIN
    /* original query starts here ------------------------------------ */
    SELECT sd.old_msl,
           sd.old_name,
           sd.new_count,
           dest.name
    FROM (
        SELECT
               /* TOP 1 … ORDER BY  →  LIMIT 1 */
               src.msl_release_num           AS old_msl,
               src.name                      AS old_name,
               src.ictv_id                   AS old_ictv_id,
               dest.msl_release_num          AS new_msl,
               COUNT(DISTINCT dest.name)     AS new_count,
               CASE WHEN COUNT(DISTINCT dest.name) > 1
                        THEN 'multiple'
                    ELSE MAX(dest.name)
               END                           AS new_name
        FROM taxonomy_node             AS src
        JOIN taxonomy_node_merge_split AS ms
              ON ms.prev_ictv_id = src.ictv_id
        JOIN taxonomy_node             AS dest
              ON dest.ictv_id  = ms.next_ictv_id
        WHERE src.name = p_name
          AND dest.msl_release_num = p_msl
          AND ms.rev_count = 0
        GROUP BY
              src.msl_release_num,
              src.name,
              src.ictv_id,
              dest.msl_release_num
        ORDER BY new_msl DESC,
                 old_msl DESC
        LIMIT 1                                       -- << replaces TOP 1
    ) AS sd
    JOIN taxonomy_node_merge_split AS ms
          ON ms.prev_ictv_id = sd.old_ictv_id
    JOIN taxonomy_node             AS dest
          ON dest.ictv_id = ms.next_ictv_id
         AND ms.rev_count = 0
         AND dest.msl_release_num = sd.new_msl;
END$$
DELIMITER ;

-- Testing:

-- CALL get_taxon_names_in_msl('Bovine enterovirus', 38)
-- CALL get_taxon_names_in_msl('Bovine enterovirus', 8)