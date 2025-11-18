DELIMITER $$

DROP FUNCTION IF EXISTS vgd_strrchr $$

CREATE FUNCTION vgd_strrchr(
    targets VARBINARY(255), -- characters to look for
    str VARBINARY(255)      -- string to look in
)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE cur_pos INT DEFAULT LENGTH(str);
    DECLARE c VARBINARY(1);
    IF str IS NULL OR targets IS NULL THEN
        RETURN 0;
    END IF;
    WHILE cur_pos > 0 DO
        SET c = SUBSTRING(str, cur_pos, 1);
        -- Use binary comparison
        IF LOCATE(c, targets) > 0 THEN
            RETURN cur_pos;
        END IF;
        SET cur_pos = cur_pos - 1;
    END WHILE;
    RETURN 0;
END $$

DELIMITER ;


-- Test 

-- SELECT vgd_strrchr(' ', 'hello world') AS result;   -- Returns 6
-- SELECT vgd_strrchr(' w', 'hello world') AS result;  -- Returns 7
-- SELECT vgd_strrchr('xy', 'hello world') AS result;  -- Returns 0
