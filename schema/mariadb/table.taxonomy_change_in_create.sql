-- SET foreign_key_checks = 0;
-- DROP TABLE IF EXISTS `taxonomy_change_in`;
-- SET foreign_key_checks = 1;

CREATE TABLE `taxonomy_change_in` (
  `change` VARCHAR(10) NOT NULL,
  `notes` TEXT,
  PRIMARY KEY (`change`)
) ENGINE=InnoDB DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;