DROP VIEW IF EXISTS species_isolates_alpha_num1_num2;

CREATE VIEW species_isolates_alpha_num1_num2 AS
SELECT
  t.isolate_id,
  t.taxnode_id,
  t.species_name,
  t.isolate_type,
  t.isolate_names,
  t.isolate_abbrevs,
  t.isolate_designation,
  t._isolate_name,

  /* alpha part already computed in subquery */
  t._isolate_name_alpha,

  /* CAST only when the *_str is non-empty digits */
  CASE
    WHEN t._isolate_name_num1_str REGEXP '^[0-9]+$' AND t._isolate_name_num1_str <> ''
      THEN CAST(t._isolate_name_num1_str AS UNSIGNED)
    ELSE NULL
  END AS _isolate_name_num1,

  CASE
    WHEN t._isolate_name_num2_str REGEXP '^[0-9]+$' AND t._isolate_name_num2_str <> ''
      THEN CAST(t._isolate_name_num2_str AS UNSIGNED)
    ELSE NULL
  END AS _isolate_name_num2

FROM (
  SELECT
    si.*,

    /* alpha = name with trailing numeric tail removed */
    TRIM(
      COALESCE(
        REGEXP_REPLACE(si._isolate_name,
                       '([._-]?[0-9]+(?:[._][0-9]+)?)$', -- strip trailing tail
                       ''),
        si._isolate_name
      )
    ) AS _isolate_name_alpha,

    /* grab entire trailing tail once (if present) */
    REGEXP_SUBSTR(si._isolate_name, '[._-]?[0-9]+(?:[._][0-9]+)?$') AS tail_any,
    REGEXP_SUBSTR(si._isolate_name, '[._-]?[0-9]+[._][0-9]+$')      AS tail_two,

    /* num1_str = first number from tail */
    REGEXP_REPLACE(
      REGEXP_SUBSTR(si._isolate_name, '[._-]?[0-9]+(?:[._][0-9]+)?$'),
      '^[._-]?([0-9]+)(?:[._][0-9]+)?$','\\1'
    ) AS _isolate_name_num1_str,

    /* num2_str = second number when tail has two numbers */
    REGEXP_REPLACE(
      REGEXP_SUBSTR(si._isolate_name, '[._-]?[0-9]+[._][0-9]+$'),
      '^[._-]?[0-9]+[._]([0-9]+)$','\\1'
    ) AS _isolate_name_num2_str

  FROM species_isolates AS si
) AS t;