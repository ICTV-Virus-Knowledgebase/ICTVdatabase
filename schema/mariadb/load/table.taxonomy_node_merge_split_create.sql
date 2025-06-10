CREATE TABLE `taxonomy_node_merge_split`(
    `prev_ictv_id` INT NOT NULL,
    `next_ictv_id` INT NOT NULL,
    `is_merged` INT NOT NULL,
    `is_split` INT NOT NULL,
    `dist` INT NOT NULL,
    `rev_count` INT NOT NULL,
    PRIMARY KEY (`prev_ictv_id`, `next_ictv_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_unicode_ci;