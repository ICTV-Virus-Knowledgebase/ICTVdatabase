DELIMITER $$

DROP PROCEDURE IF EXISTS species_isolates_update_sorts $$
CREATE PROCEDURE species_isolates_update_sorts()
BEGIN
  UPDATE species_isolates si
  JOIN (
    SELECT
      vmr.isolate_id,
      DENSE_RANK() OVER (ORDER BY tn.left_idx) AS species_sort,
      ROW_NUMBER() OVER (
        PARTITION BY vmr.species_name
        ORDER BY
          vmr.isolate_type DESC,
          COALESCE(vmr._isolate_name_alpha,'') COLLATE utf8mb4_general_ci,
          COALESCE(vmr._isolate_name_num1,
                   vmr._isolate_name_num2,
                   18446744073709551615),
          vmr.isolate_id
      ) AS isolate_sort
    FROM species_isolates_alpha_num1_num2 AS vmr
    JOIN taxonomy_node AS tn
      ON tn.taxnode_id = vmr.taxnode_id
  ) AS x
    ON x.isolate_id = si.isolate_id
  SET
    si.species_sort = x.species_sort,
    si.isolate_sort = x.isolate_sort;
END $$
DELIMITER ;