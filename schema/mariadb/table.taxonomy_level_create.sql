CREATE TABLE `taxonomy_level` (
  `id` INT NOT NULL,
  `parent_id` INT,
  `name` VARCHAR(255) NOT NULL,
  `plural` VARCHAR(50),
  `suffix` VARCHAR(50),
  `suffix_viroid` VARCHAR(50),
  `suffix_nuc_acid` VARCHAR(50),
  `suffix_viriform` VARCHAR(50),
  `notes` TEXT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;