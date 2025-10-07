DELIMITER $$

DROP FUNCTION IF EXISTS udf_rankCountsToStringWithPurals $$

CREATE FUNCTION udf_rankCountsToStringWithPurals(
    realm_ct INT,
    subrealm_ct INT,
    kingdom_ct INT,
    subkingdom_ct INT,

    phylum_ct INT,
    subphylum_ct INT,
    class_ct INT,
    subclass_ct INT,

    order_ct INT,
    suborder_ct INT,
    family_ct INT,
    subfamily_ct INT,

    genus_ct INT,
    subgenus_ct INT,

    species_ct INT
)
RETURNS VARCHAR(1000)
DETERMINISTIC
BEGIN
    DECLARE csv VARCHAR(1000);
    DECLARE str VARCHAR(100);

    -- For realm
    SET str = CASE realm_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 realm'
        ELSE CONCAT(realm_ct, ' realms')
    END;

    IF str IS NOT NULL THEN
        SET csv = str;
    ELSE
        SET csv = NULL;
    END IF;

    -- For subrealm
    SET str = CASE subrealm_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 subrealm'
        ELSE CONCAT(subrealm_ct, ' subrealms')
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For kingdom
    SET str = CASE kingdom_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 kingdom'
        ELSE CONCAT(kingdom_ct, ' kingdoms')
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For subkingdom
    SET str = CASE subkingdom_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 subkingdom'
        ELSE CONCAT(subkingdom_ct, ' subkingdoms')
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For phylum
    SET str = CASE phylum_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 phylum'
        ELSE CONCAT(phylum_ct, ' phyla')  -- Special plural form
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For subphylum
    SET str = CASE subphylum_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 subphylum'
        ELSE CONCAT(subphylum_ct, ' subphyla')  -- Special plural form
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For class
    SET str = CASE class_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 class'
        ELSE CONCAT(class_ct, ' classes')
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For subclass
    SET str = CASE subclass_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 subclass'
        ELSE CONCAT(subclass_ct, ' subclasses')
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For order
    SET str = CASE order_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 order'
        ELSE CONCAT(order_ct, ' orders')
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For suborder
    SET str = CASE suborder_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 suborder'
        ELSE CONCAT(suborder_ct, ' suborders')
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For family
    SET str = CASE family_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 family'
        ELSE CONCAT(family_ct, ' families')  -- Special plural form
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For subfamily
    SET str = CASE subfamily_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 subfamily'
        ELSE CONCAT(subfamily_ct, ' subfamilies')  -- Special plural form
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For genus
    SET str = CASE genus_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 genus'
        ELSE CONCAT(genus_ct, ' genera')  -- Special plural form
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For subgenus
    SET str = CASE subgenus_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 subgenus'
        ELSE CONCAT(subgenus_ct, ' subgenera')  -- Special plural form
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- For species
    SET str = CASE species_ct
        WHEN 0 THEN NULL
        WHEN 1 THEN '1 species'
        ELSE CONCAT(species_ct, ' species')  -- 'species' is same in singular and plural
    END;

    IF str IS NOT NULL THEN
        IF csv IS NOT NULL THEN
            SET csv = CONCAT(csv, ', ', str);
        ELSE
            SET csv = str;
        END IF;
    END IF;

    -- Return the result
    RETURN IFNULL(csv, '');
END $$

DELIMITER ;

-- Test
-- SELECT udf_rankCountsToStringWithPurals(1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1, 1) AS singular;
-- SELECT udf_rankCountsToStringWithPurals(2,2,2,2, 2,2,2,2, 2,2,2,2, 2,2, 2) AS plurals;
-- SELECT udf_rankCountsToStringWithPurals(0,1,2,3, 0,1,2,3, 0,1,2,3, 0,1, 2) AS mixed;

