DELIMITER //

CREATE OR REPLACE FUNCTION VMR_accessionsStripPrefixesAndConvertToCSV(
  inputString TEXT
)
RETURNS TEXT
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE s TEXT;
  DECLARE token TEXT;
  DECLARE outStr TEXT DEFAULT '';
  DECLARE sepPos INT;
  DECLARE colonPos INT;
  DECLARE parenPos INT;

  -- Match T-SQL behavior: if input is NULL, result ends up ''.
  IF inputString IS NULL THEN
    RETURN '';
  END IF;

  -- Remove all spaces
  SET s = REPLACE(inputString, ' ', '');

  -- Loop over semicolon-separated parts
  loop_parts: LOOP
    SET sepPos = LOCATE(';', s);

    IF sepPos = 0 THEN
      -- Last (or only) token is whatever remains
      SET token = s;
      SET s = '';  -- consume all
    ELSE
      SET token = LEFT(s, sepPos - 1);
      SET s = SUBSTRING(s, sepPos + 1);
    END IF;

    -- Strip prefix up to colon, if present
    SET colonPos = LOCATE(':', token);
    IF colonPos > 0 THEN
      SET token = SUBSTRING(token, colonPos + 1);
    END IF;

    -- Strip location part starting at '(' if present
    SET parenPos = LOCATE('(', token);
    IF parenPos > 0 THEN
      SET token = LEFT(token, parenPos - 1);
    END IF;

    -- Append if non-empty
    IF LENGTH(token) > 0 THEN
      SET outStr = CONCAT(outStr, token, ',');
    END IF;

    -- Exit when we’ve consumed the string
    IF s = '' THEN
      LEAVE loop_parts;
    END IF;
  END LOOP loop_parts;

  -- Trim trailing comma
  IF outStr <> '' THEN
    SET outStr = LEFT(outStr, LENGTH(outStr) - 1);
  END IF;

  RETURN outStr;
END//

DELIMITER ;
