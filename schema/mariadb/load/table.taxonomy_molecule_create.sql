CREATE TABLE `taxonomy_molecule` (
  `id` INT NOT NULL,
  `abbrev` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `balt_group` INT,
  `balt_roman` VARCHAR(5),
  `description` TEXT,
  `left_idx` INT,
  `right_idx` INT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;