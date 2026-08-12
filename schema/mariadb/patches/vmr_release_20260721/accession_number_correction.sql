START TRANSACTION;

UPDATE species_isolates
SET genbank_accessions = 'BK068684'
WHERE genbank_accessions = 'BK069690';

COMMIT;
