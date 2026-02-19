CREATE TABLE `taxonomy_toc`(
    `tree_id` INT NOT NULL,
    `msl_release_num` INT,
    `version_tag` VARCHAR(50) NULL,
    `needs_reindex` TINYINT(1) NOT NULL DEFAULT 0,
    `comments` TEXT,
    UNIQUE INDEX `IX_taxonomy_toc_tree_id` (`tree_id`),
    UNIQUE INDEX `PK_taxonomy_toc` (`tree_id`, `msl_release_num`)
) ENGINE=InnoDB DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_general_ci;
