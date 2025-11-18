DROP VIEW IF EXISTS `taxonomy_node_changes`;

CREATE VIEW `taxonomy_node_changes` AS
SELECT
    bone.ictv_id,
    bone.msl,
    nt.next_tag,
    nt.next_tag_ct,
    n.left_idx,
    n.taxnode_id,
    n.rank,
    n.name,
    pt.prev_tag,
    pt.prev_tag_ct
FROM
    (
        SELECT 
            ids.ictv_id,
            msl.msl
        FROM (
            SELECT ictv_id
            FROM taxonomy_node_names
            WHERE msl IS NOT NULL
            GROUP BY ictv_id
        ) AS ids
        CROSS JOIN (
            SELECT msl_release_num AS msl
            FROM taxonomy_toc
            WHERE msl_release_num IS NOT NULL
            GROUP BY msl_release_num
        ) AS msl
    ) AS bone
LEFT OUTER JOIN taxonomy_node_names n 
    ON n.msl_release_num = bone.msl 
    AND n.ictv_id = bone.ictv_id
LEFT JOIN (
    SELECT
        sub.prev_taxid AS taxnode_id,
        GROUP_CONCAT(sub.ct_tag ORDER BY sub.tag_csv_min SEPARATOR '|') AS next_tag,
        SUM(sub.cnt) AS next_tag_ct
    FROM (
        SELECT
            d.prev_taxid,
            d.tag_csv_min,
            COUNT(*) AS cnt,
            CONCAT(
                LEFT(d.tag_csv_min, CASE WHEN d.tag_csv_min = '' THEN 1 ELSE LENGTH(d.tag_csv_min) - 1 END),
                CASE WHEN COUNT(*) > 1 THEN CONCAT('(N=', COUNT(*), ')') ELSE '' END
            ) AS ct_tag
        FROM taxonomy_node_delta d
        GROUP BY d.prev_taxid, d.tag_csv_min
    ) sub
    GROUP BY sub.prev_taxid
) AS nt ON nt.taxnode_id = n.taxnode_id
LEFT JOIN (
    SELECT
        sub.new_taxid AS taxnode_id,
        REPLACE(
            GROUP_CONCAT(sub.ct_tag ORDER BY sub.tag_csv_min SEPARATOR '|'),
            ',(',
            '('
        ) AS prev_tag,
        SUM(sub.cnt) AS prev_tag_ct
    FROM (
        SELECT
            d.new_taxid,
            d.tag_csv_min,
            COUNT(*) AS cnt,
            CONCAT(
                LEFT(d.tag_csv_min, CASE WHEN d.tag_csv_min = '' THEN 1 ELSE LENGTH(d.tag_csv_min) - 1 END),
                CASE WHEN COUNT(*) > 1 THEN CONCAT('(N=', COUNT(*), ')') ELSE '' END
            ) AS ct_tag
        FROM taxonomy_node_delta d
        GROUP BY d.new_taxid, d.tag_csv_min
    ) sub
    GROUP BY sub.new_taxid
) AS pt ON pt.taxnode_id = n.taxnode_id;

-- Query the view in SQL Server the same way as it is shown by defualt in MariaDB:

-- SELECT TOP 1000 *
-- FROM taxonomy_node_changes
-- ORDER BY ictv_id, msl;