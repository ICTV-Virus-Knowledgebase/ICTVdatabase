# Orthoflavivirus mediterranense: split to new species

Run [orthoflavivirus_mediterranense_fix.sql](orthoflavivirus_mediterranense_fix.sql) against the reconciled MSL41 database. It corrects species taxnode/ICTV ID `202523330` without adding a database note or history record describing the mistake.

The patch:

- Sets `taxonomy_node.in_change` to `new` and clears `in_target`.
- Sets the species' VMR rows to `update_change = 'created'`, `update_prev_species = 'created'`, and `update_prev_taxnode_id = NULL`. The literal `created` predecessor label follows `VMR_update_from_new_MSL`'s convention for newly created species; it is not a previous species name.
- Calls `rebuild_delta_nodes(41, NULL, NULL)` to regenerate release 41. The corrected delta has no predecessor, `is_new = 1`, and all other change flags zero, including `is_split` and `is_moved`.
- Calls `rebuild_node_merge_split()` to remove the false forward, reverse and transitive relationships. Only the species' identity mapping remains.

The valid splits from `Orthoflavivirus encephalitidis` (`202403114`, ICTV ID `19790934`) to `Orthoflavivirus zilberi` (`202523328`) and `Orthoflavivirus neudoerflense` (`202523329`) remain intact. The patch checks both delta rows before and after rebuilding. Their taxonomy and VMR rows are not updated. False relationship links between those species and mediterranense are necessarily removed.

## Evidence and scope

In `2025.007S.Orthoflavivirus_2nsp_1spren.xlsx`, `Orthoflavivirus mediterranense` was incorrectly coded as a `split` instead of `create new`.

The `DQ235151` section of [MSL41.v1_VMR_species_splits_patch.sql](../MSL41.v1_VMR_species_splits_patch.sql) copies the newly generated exemplar into existing isolate `1012799`, sets `update_change = 'split'`, and leaves the destination's predecessor fields unchanged. This explains how `Orthoflavivirus loupingi` / `202403096` can remain in the VMR even though the erroneous taxonomy split points to encephalitidis. The correction preserves isolate identity, accession, proposal, biological fields and existing editor notes.

`taxonomy_node_dx`, `species_historic_name_lut`, MSL export views and `vmr_export` derive their history from the corrected tables; they do not need separate updates. The checked schema has no additional persistent change-history table requiring this correction. Names, hierarchy, lineage, IDs and VMR sort inputs do not change, so tree/JSON rebuilding and `species_isolates_update_sorts()` are unnecessary.

## Running

Use the repository versions of both rebuild procedures. The patch is intended for the supplied MSL41 state and rejects additional release nodes for mediterranense so that later history is not silently reclassified. It also requires exactly one reconciled VMR exemplar for the species. It accepts either the original or corrected source classification and can be rerun.

Run with a backup available, during a maintenance window, in a fresh connection with no pending transaction. Both rebuilds have a wider scope than the source correction: the delta procedure replaces all release-41 deltas, and the relationship procedure replaces the entire relationship table. Do not use the delta procedure's debug taxon argument: it deletes the full release before inserting filtered rows.

From the repository root, substituting the intended connection options and database name:

```sh
mariadb --database=YOUR_DATABASE < schema/mariadb/patches/orthoflavivirus_mediterranense_fix_20261013/orthoflavivirus_mediterranense_fix.sql
```

Do not use `--force`. The anonymous compound statement needs no permanent helper procedure. An SQL error in the source/VMR/delta phase rolls that phase back. The relationship rebuild runs **after commit**, because its `TRUNCATE` implicitly commits. If it fails, the source correction is already committed and the relationship table may be incomplete. Resolve the reported error and rerun this patch to complete the rebuild. A final relationship assertion also reports an error if unexpected history remains.

Run [verify.sql](verify.sql) afterward to inspect the corrected source, deltas, relationship entries and VMR metadata.

## Validation

Full repository data was loaded into an isolated MariaDB instance. Rebuilding after the source correction changed only the mediterranense delta and removed exactly 24 non-identity relationship entries involving its ICTV ID. Every other delta and relationship entry matched the original data, including the two valid sibling splits.

The complete SQL patch was then run against the restored input data. It changed exactly one taxonomy row, one VMR row and one delta row, and removed the same 24 relationships. A second execution produced identical contents in all four tables. A separate test injected a delta-rebuild failure after deleting deltas; the patch raised the error, rolled back the source/VMR/delta changes, and left relationships untouched.

The local MariaDB version is 11.6.2. For testing only, the three parameter defaults were omitted from the temporary copy of `rebuild_delta_nodes` because that server does not support the repository's newer parameter-default syntax. The procedure body was unchanged, and the patch passes all three arguments explicitly. No repository procedure was modified.
