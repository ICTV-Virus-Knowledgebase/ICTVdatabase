CREATE TABLE `taxonomy_node_delta`(
    `prev_taxid` INT NULL DEFAULT NULL,
    `new_taxid` INT NULL DEFAULT NULL,
    `proposal` VARCHAR(255) NULL DEFAULT NULL,
    `notes` TEXT NULL,
    `is_merged` INT NOT NULL DEFAULT 0,
    `is_split` INT NOT NULL DEFAULT 0,
    `is_moved` INT NOT NULL DEFAULT 0,
    `is_promoted` INT NOT NULL DEFAULT 0,
    `is_demoted` INT NOT NULL DEFAULT 0,
    `is_renamed` INT NOT NULL DEFAULT 0,
    `is_new` INT NOT NULL DEFAULT 0,
    `is_deleted` INT NOT NULL DEFAULT 0,
    `is_now_type` INT NOT NULL DEFAULT 0,
    `tag_csv` TEXT AS (CONCAT(
        IF(`is_merged`=1, 'Merged,', ''),
        IF(`is_split`=1, 'Split,', ''),
        IF(`is_renamed`=1, 'Renamed,', ''),
        IF(`is_new`=1, 'New,', ''),
        IF(`is_deleted`=1, 'Abolished,', ''),
        IF(`is_moved`=1, 'Moved,', ''),
        IF(`is_promoted`=1, 'Promoted,', ''),
        IF(`is_demoted`=1, 'Demoted,', ''),
        IF(`is_now_type`=1, 'Assigned as Type Species,', IF(`is_now_type`=-1, 'Removed as Type Species,', ''))
    )),
    `is_lineage_updated` INT NOT NULL DEFAULT 0,
    `msl` INT NOT NULL,
    `tag_csv2` TEXT AS (CONCAT(
        IF(`is_merged`=1, 'Merged,', ''),
        IF(`is_split`=1, 'Split,', ''),
        IF(`is_renamed`=1, 'Renamed,', ''),
        IF(`is_new`=1, 'New,', ''),
        IF(`is_deleted`=1, 'Abolished,', ''),
        IF(`is_moved`=1, 'Moved,', ''),
        IF(`is_promoted`=1, 'Promoted,', ''),
        IF(`is_demoted`=1, 'Demoted,', ''),
        IF(`is_now_type`=1, 'Assigned as Type Species,', IF(`is_now_type`=-1, 'Removed as Type Species,', '')),
        IF(`is_lineage_updated`=1, 'LineageUpdated,', '')
    )) PERSISTENT,
    `tag_csv_min` TEXT AS (CONCAT(
        IF(`is_merged`=1, 'Merged,', ''),
        IF(`is_split`=1, 'Split,', ''),
        IF(`is_renamed`=1, 'Renamed,', ''),
        IF(`is_new`=1, 'New,', ''),
        IF(`is_deleted`=1, 'Abolished,', ''),
        IF(`is_moved`=1, 'Moved,', ''),
        IF(`is_promoted`=1, 'Promoted,', ''),
        IF(`is_demoted`=1, 'Demoted,', '')
    )) PERSISTENT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Adding CHECK constraints (to enforce valid values)
ALTER TABLE `taxonomy_node_delta`
    ADD CONSTRAINT `CK_taxonomy_node_delta_is_deleted` CHECK (`is_deleted` IN (0,1)),
    ADD CONSTRAINT `CK_taxonomy_node_delta_is_merged` CHECK (`is_merged` IN (0,1)),
    ADD CONSTRAINT `CK_taxonomy_node_delta_is_moved` CHECK (`is_moved` IN (0,1)),
    ADD CONSTRAINT `CK_taxonomy_node_delta_is_new` CHECK (`is_new` IN (0,1)),
    ADD CONSTRAINT `CK_taxonomy_node_delta_is_now_type` CHECK (`is_now_type` IN (1, 0, -1)),
    ADD CONSTRAINT `CK_taxonomy_node_delta_is_renamed` CHECK (`is_renamed` IN (0,1));
