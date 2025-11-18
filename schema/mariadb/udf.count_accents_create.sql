DELIMITER $$

DROP FUNCTION IF EXISTS count_accents $$

CREATE FUNCTION count_accents(in_string VARCHAR(1000) CHARACTER SET utf8mb4)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE cur_pos INT DEFAULT 1;
    DECLARE char_count INT DEFAULT 0;
    DECLARE str_length INT;

    SET str_length = CHAR_LENGTH(in_string);

    WHILE cur_pos <= str_length DO
        IF ORD(SUBSTRING(in_string, cur_pos, 1)) > 127 THEN
            SET char_count = char_count + 1;
        END IF;
        SET cur_pos = cur_pos + 1;
    END WHILE;

    RETURN char_count;
END $$

DELIMITER ;