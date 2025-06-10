CREATE TABLE `taxonomy_toc`(
    `tree_id` INT NOT NULL,
    `msl_release_num` INT,
    `comments` TEXT,
    UNIQUE INDEX `IX_taxonomy_toc_tree_id` (`tree_id`),
    UNIQUE INDEX `PK_taxonomy_toc` (`tree_id`, `msl_release_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_unicode_ci;