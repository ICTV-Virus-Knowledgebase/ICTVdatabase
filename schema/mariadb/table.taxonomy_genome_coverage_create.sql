CREATE TABLE `taxonomy_genome_coverage` (
  `genome_coverage` VARCHAR(50) NOT NULL,
  `name` VARCHAR(50),
  `priority` INT,
  PRIMARY KEY (`genome_coverage`)
) ENGINE=InnoDB DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;