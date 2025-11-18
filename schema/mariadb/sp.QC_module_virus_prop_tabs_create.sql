/* ================================================================
   Stored procedure  : QC_module_virus_prop_tabs
   Converted from    : SQL-Server to MariaDB
   Preserves         : Original comments & behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_virus_prop_tabs $$
CREATE PROCEDURE QC_module_virus_prop_tabs
(
    IN p_filter VARCHAR(1000)     -- pass NULL ⇒ 'ERROR%'
)
BEGIN
    /* --------------------------------------------------------------
       Default filter, exactly like the T-SQL header
       -------------------------------------------------------------- */
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* --------------------------------------------------------------
       Emit QC rows
       -------------------------------------------------------------- */
    SELECT
        'QC_module_virus_prop_tabs'           AS qc_module,      -- OBJECT_NAME(@@PROCID)
        '[virus_prop]'                        AS table_name,
        vp.taxon                              AS taxon,
        /* prepend “ERROR:” when any TAB-issue was found               */
        CASE
            WHEN errs = ''  THEN 'OK'
            ELSE CONCAT('ERROR:', errs)
        END                                    AS qc_mesg
    FROM
    (
        /* ----------------------------------------------------------
           Underlying analysis: build an “errs” string by testing
           every column for CHAR(9) (tab) characters.
           ---------------------------------------------------------- */
        SELECT
            taxon,
            CONCAT(
                IF(taxon                LIKE CONCAT('%',CHAR(9),'%'),'TAB[taxon];', ''),
                IF(sub_taxon            LIKE CONCAT('%',CHAR(9),'%'),'TAB[sub_taxon];', ''),
                IF(molecule             LIKE CONCAT('%',CHAR(9),'%'),'TAB[molecule];', ''),
                IF(morphology           LIKE CONCAT('%',CHAR(9),'%'),'TAB[morphology];', ''),
                IF(virion_size          LIKE CONCAT('%',CHAR(9),'%'),'TAB[virion_size];', ''),
                IF(genome_segments      LIKE CONCAT('%',CHAR(9),'%'),'TAB[genome_segments];', ''),
                IF(genome_configuration LIKE CONCAT('%',CHAR(9),'%'),'TAB[genome_configuration];', ''),
                IF(genome_size          LIKE CONCAT('%',CHAR(9),'%'),'TAB[genome_size];', ''),
                IF(host                 LIKE CONCAT('%',CHAR(9),'%'),
                       CONCAT('TAB[host]=', REPLACE(host, CHAR(9), '[TAB]')),
                       '')
            ) AS errs
        FROM virus_prop
    ) AS vp
    /* --------------------------------------------------------------
       Apply caller’s filter (default 'ERROR%')
       -------------------------------------------------------------- */
    WHERE
        CASE
            WHEN errs = '' THEN 'OK'
            ELSE CONCAT('ERROR:', errs)
        END LIKE p_filter
    ORDER BY qc_mesg;
END$$
DELIMITER ;

-- /* show only rows with TAB problems (default) */
-- CALL QC_module_virus_prop_tabs();

-- /* show every row, including OK ones */
-- CALL QC_module_virus_prop_tabs('%');