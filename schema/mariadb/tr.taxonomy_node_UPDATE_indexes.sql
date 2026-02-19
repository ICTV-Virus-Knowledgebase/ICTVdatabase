/* ============================================================================
   taxonomy_node trigger conversion for MariaDB 11.8

   Why this is different from SQL Server:
   - SQL Server trigger was statement-level and directly updated taxonomy_node.
   - MariaDB triggers are row-level and cannot update the same table that fired
     the trigger (directly or via called procedures).

   Conversion strategy:
   1) BEFORE triggers keep start_num_sort in sync from NEW.name.
   2) AFTER triggers mark affected trees in taxonomy_toc.needs_reindex.
   ============================================================================ */

DELIMITER $$

/* remove legacy helper/event objects during deployment */
DROP PROCEDURE IF EXISTS sp_taxonomy_node_process_reindex_flags $$
DROP EVENT IF EXISTS ev_taxonomy_node_process_reindex_queue $$
DROP EVENT IF EXISTS ev_taxonomy_node_check_redindex $$

DROP TRIGGER IF EXISTS tr_taxonomy_node_bi_set_start_num_sort $$
CREATE TRIGGER tr_taxonomy_node_bi_set_start_num_sort
BEFORE INSERT ON taxonomy_node
FOR EACH ROW
BEGIN
    SET NEW.start_num_sort = CASE
        WHEN NEW.name IS NULL THEN NULL
        WHEN RIGHT(NEW.name, 4) REGEXP '^[0-9]{4}$' THEN CHAR_LENGTH(NEW.name) - 4
        WHEN RIGHT(NEW.name, 3) REGEXP '^[0-9]{3}$' THEN CHAR_LENGTH(NEW.name) - 3
        WHEN RIGHT(NEW.name, 2) REGEXP '^[0-9]{2}$' THEN CHAR_LENGTH(NEW.name) - 2
        WHEN RIGHT(NEW.name, 1) REGEXP '^[0-9]{1}$' THEN CHAR_LENGTH(NEW.name) - 1
        ELSE NULL
    END;
END $$

DROP TRIGGER IF EXISTS tr_taxonomy_node_bu_set_start_num_sort $$
CREATE TRIGGER tr_taxonomy_node_bu_set_start_num_sort
BEFORE UPDATE ON taxonomy_node
FOR EACH ROW
BEGIN
    IF NOT (OLD.name <=> NEW.name) THEN
        SET NEW.start_num_sort = CASE
            WHEN NEW.name IS NULL THEN NULL
            WHEN RIGHT(NEW.name, 4) REGEXP '^[0-9]{4}$' THEN CHAR_LENGTH(NEW.name) - 4
            WHEN RIGHT(NEW.name, 3) REGEXP '^[0-9]{3}$' THEN CHAR_LENGTH(NEW.name) - 3
            WHEN RIGHT(NEW.name, 2) REGEXP '^[0-9]{2}$' THEN CHAR_LENGTH(NEW.name) - 2
            WHEN RIGHT(NEW.name, 1) REGEXP '^[0-9]{1}$' THEN CHAR_LENGTH(NEW.name) - 1
            ELSE NULL
        END;
    END IF;
END $$

DROP TRIGGER IF EXISTS tr_taxonomy_node_ai_enqueue_reindex $$
CREATE TRIGGER tr_taxonomy_node_ai_enqueue_reindex
AFTER INSERT ON taxonomy_node
FOR EACH ROW
BEGIN
    IF IFNULL(@skip_taxonomy_node_reindex_flag, 0) = 0 THEN
        UPDATE taxonomy_toc
           SET needs_reindex = 1
        -- tree_id = taxonomy_toc tree_id,  NEW.tree_id = taxonomy_node tree_id being inserted
         WHERE tree_id = NEW.tree_id
           AND needs_reindex = 0;
    END IF;
END $$

DROP TRIGGER IF EXISTS tr_taxonomy_node_ad_enqueue_reindex $$
CREATE TRIGGER tr_taxonomy_node_ad_enqueue_reindex
AFTER DELETE ON taxonomy_node
FOR EACH ROW
BEGIN
    IF IFNULL(@skip_taxonomy_node_reindex_flag, 0) = 0 THEN
        UPDATE taxonomy_toc
           SET needs_reindex = 1
         WHERE tree_id = OLD.tree_id
           AND needs_reindex = 0;
    END IF;
END $$

DROP TRIGGER IF EXISTS tr_taxonomy_node_au_enqueue_reindex $$
CREATE TRIGGER tr_taxonomy_node_au_enqueue_reindex
AFTER UPDATE ON taxonomy_node
FOR EACH ROW
BEGIN
    IF IFNULL(@skip_taxonomy_node_reindex_flag, 0) = 0 THEN
        IF NOT (OLD.parent_id <=> NEW.parent_id)
           OR NOT (OLD.level_id <=> NEW.level_id)
           OR NOT (OLD.tree_id <=> NEW.tree_id)
           OR NOT (OLD.name <=> NEW.name)
           OR NOT (OLD.molecule_id <=> NEW.molecule_id) THEN
            UPDATE taxonomy_toc
               SET needs_reindex = 1
             WHERE (tree_id = OLD.tree_id OR tree_id = NEW.tree_id)
               AND needs_reindex = 0;
        END IF;
    END IF;
END $$

DELIMITER ;
