# VMR_MSL40.v2_20251013

This data release requires so schema fixes:

 * View: vmr_export
 * UDF:  VMR_accessionsStripPrefixesAndConvertToCSV_create

Also, two tables [`taxonomy_genome_coverage`, `taxonomy_host_source`] can not easily be dropped and reloaded, due to FK constraints, so we provide the insert statements to add the needed rows, which must be done BEFORE loading the new data set into `species_isolates`: 

 * vmr_0_cv_inserts.sql

After that, `species_isolates` can be truncated or dropped and re-loaded from the [data/](../../data) directory

