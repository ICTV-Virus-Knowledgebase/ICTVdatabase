/* ================================================================
   Stored procedure  : QC_module_taxonomy_node_ictv_resurrection
   Converted from    : SQL-Server to MariaDB
   Behaviour         : Same result-set, same default parameter
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_ictv_resurrection $$
CREATE PROCEDURE QC_module_taxonomy_node_ictv_resurrection
(
    IN p_filter VARCHAR(1000)        -- pass NULL ⇒ default 'ERROR%'
)
BEGIN
    DECLARE v_current_msl INT;
    /* -----------------------------------------------------------------
       SQL-Server allowed a default in the header.
       Give the same behaviour here.
       ----------------------------------------------------------------- */
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* -----------------------------------------------------------------
       Cache current MSL once – reused several times.
       ----------------------------------------------------------------- */
    SELECT MAX(msl_release_num) INTO v_current_msl
      FROM taxonomy_toc;

    /* -----------------------------------------------------------------
       Main query – structurally identical to T-SQL, adapted for MariaDB.
       ----------------------------------------------------------------- */
    SELECT
        'QC_module_taxonomy_node_ictv_resurrection'          AS qc_module,
        '[taxonomy_node]'                                    AS table_name,
        src.*                                                /* all original columns */
    FROM
    (
        /* -------------------------------------------------------------
           Add OK / ERROR class labels & look-ahead ICTV-ID block
           -------------------------------------------------------------*/
        SELECT
            a.*,

            /* ------ build ‘class’ column (same logic as T-SQL) ------- */
            CASE
                WHEN a.max_msl = v_current_msl
                     THEN 'CUR_MSL]]'
                WHEN nl.ictv_id IS NULL
                     THEN 'GAP>>'
                ELSE '>>ADJ>>'
            END                                             AS class,

            nl.ictv_id      AS next_ictv_id,
            nl.min_msl      AS next_min_msl,
            nl.max_msl      AS next_max_msl,
            nl.msl_ct       AS next_msl_ct
        FROM
        (
            /* =========================================================
               UNDERLYING ANALYSIS – identical grouping logic
               =========================================================*/
            SELECT
                /* constant message used in SQL-Server code */
                'ERROR: ressurection of taxon with new ICTV_ID'
                                                           AS qc_mesg,

                s.*,

                MIN(n.msl_release_num)  AS min_msl,
                MAX(n.msl_release_num)  AS max_msl,
                COUNT(n.ictv_id)        AS msl_ct
            FROM
            (
                /* ---------------------------------------------
                   Each (name, ictv_id) pair when the *name* is
                   shared by >1 distinct ICTV-IDs (“zombie” names)
                   ---------------------------------------------*/
                SELECT
                    z.name,
                    z.ictv_ct,
                    n.ictv_id
                FROM taxonomy_node AS n
                JOIN (
                        SELECT name,
                               COUNT(DISTINCT ictv_id) AS ictv_ct
                        FROM taxonomy_node
                        GROUP BY name
                        HAVING COUNT(DISTINCT ictv_id) > 1
                     ) AS z
                  ON z.name = n.name
                GROUP BY z.name, z.ictv_ct, n.ictv_id
            ) AS s
            JOIN taxonomy_node AS n
              ON n.ictv_id = s.ictv_id
            WHERE n.is_deleted = 0
              AND n.is_obsolete = 0
              AND n.msl_release_num IS NOT NULL
            GROUP BY
                  s.name, s.ictv_ct, s.ictv_id
        ) AS a

        /* -------- look-ahead (next life) block -----------------------*/
        LEFT JOIN
        (
            SELECT
                t.name,
                t.ictv_id,
                MIN(n.msl_release_num) AS min_msl,
                MAX(n.msl_release_num) AS max_msl,
                COUNT(*)               AS msl_ct
            FROM (
                    SELECT name, ictv_id
                    FROM taxonomy_node
                    GROUP BY name, ictv_id
                 ) AS t
            JOIN taxonomy_node AS n
              ON n.ictv_id = t.ictv_id
            GROUP BY t.name, t.ictv_id
        ) AS nl
          ON nl.name    = a.name
         AND nl.min_msl = a.max_msl + 1
    ) AS src
    /* -----------------------------------------------------------------
       Keep only rows matching caller’s filter (‘ERROR%’ by default)
       ----------------------------------------------------------------- */
    WHERE src.qc_mesg LIKE p_filter
    ORDER BY name, min_msl;
END$$
DELIMITER ;

-- /* default – show only rows whose qc_mesg starts with 'ERROR' */
-- CALL QC_module_taxonomy_node_ictv_resurrection();

-- /* list every row (pass '%' ) */
-- CALL QC_module_taxonomy_node_ictv_resurrection('%');

-- /* show only the “OK” rows (none, given this particular qc_mesg) */
-- CALL QC_module_taxonomy_node_ictv_resurrection('OK');