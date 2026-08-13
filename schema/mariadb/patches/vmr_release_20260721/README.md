# VMR Release: MSL41.v1 20260721 

* This VMR release contained the wrong accession number for the isolate `Actinidia polerovirus`

* This patch changes it from 'BK069690' to 'BK068684'

## Important note about ictv_apps database

* This means we also have to update the searchable_taxon table inside the ictv_apps database

* Below is the SQL used to update the searchable_taxon table:

```
START TRANSACTION;

UPDATE searchable_taxon
SET name = 'BK068684',
    filtered_name = 'BK068684'
WHERE name = 'BK069690'
  AND filtered_name = 'BK069690';

COMMIT;
```