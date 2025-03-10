
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[getVirusIsolates]
	@mslRelease AS INT,
	@onlyUnassigned AS BIT,
	@searchTaxon AS NVARCHAR(100)

AS
BEGIN
/*
-- IVK-276 re-schema VMR
-- 
-- update [getVirusIsolates] to use [species_isolates] table 
-- instead of [virus_isolates] view of [vmr] table

-- TEST
exec [getVirusIsolates] 39, 0, 'Jingchuvirales'
exec [getSpeciesIsolates] 39, 0, 'Jingchuvirales'

DECLARE @searchTaxon as nvarchar(14); SET @searchTaxon=N'Jingchuvirales'
EXEC dbo.getVirusIsolates @mslRelease = 39, @onlyUnassigned = 0, @searchTaxon = @searchTaxon


exec [getVirusIsolates] 39, 0, 'Aliusviridae'
exec [getSpeciesIsolates] 39, 0, 'Aliusviridae'

*/

	SET XACT_ABORT, NOCOUNT ON

	-- A constant error code to use when throwing exceptions.
	DECLARE @errorCode AS INT = 50000

	BEGIN TRY

		-- Validate the search taxon parameter.
		IF @searchTaxon IS NULL OR LEN(@searchTaxon) < 1 THROW @errorCode, 'Invalid searchTaxonName parameter', 1

		-- Clean up the MSL release parameter.
		-- DECLARE @mslRelease as varchar(30)
		IF @mslRelease IS NULL OR @mslRelease < 1 SET @mslRelease = (SELECT MAX(msl_release_num) FROM taxonomy_toc)
		
		DECLARE @targetLeftIndex AS INT = NULL
		DECLARE @targetLevelID AS INT = NULL
		DECLARE @targetRightIndex AS INT = NULL
		DECLARE @targetTaxNodeID AS INT = NULL

		-- The search taxon's taxonomy node
		SELECT TOP 1
			@targetLeftIndex = target.left_idx,
			@targetLevelID = target.level_id,
			@targetRightIndex = target.right_idx,
			@targetTaxNodeID = target.taxnode_id
		FROM taxonomy_node target 
		WHERE target.name = @searchTaxon
		AND target.msl_release_num = @mslRelease
	
		-- Validate the target columns
		IF @targetLeftIndex IS NULL OR @targetLevelID IS NULL OR @targetRightIndex IS NULL OR @targetTaxNodeID IS NULL THROW @errorCode, 'Invalid target node values', 1

		-- Get the species level ID
		DECLARE @speciesLevelID AS INT = (SELECT TOP 1 id FROM taxonomy_level WHERE name = 'species')

		
		-- Get the virus isolate data
		SELECT 
			isolate_id = si.isolate_id,
			abbrev = ISNULL(si.isolate_abbrevs, ''), 
			accession_number = ISNULL(si.genbank_accessions, ''), 
			alternative_name_csv = ISNULL(si.isolate_names,''),
			available_sequence = ISNULL(si.[genome_coverage], ''), 
			exemplar = si.isolate_type,
			isolate = ISNULL(si.[isolate_designation], ''), 
			refseq_accession = ISNULL(si.refseq_accessions, ''), 
			taxnode_id = species.taxnode_id,

			-- Lineage names
			subrealm = ISNULL(subrealm.name, ''),
			kingdom = ISNULL(kingdom.name, ''),
			subkingdom = ISNULL(subkingdom.name, ''),
			phylum = ISNULL(phylum.name, ''),
			class = ISNULL(class.name, ''),
			subclass = ISNULL(subclass.name, ''),
			[order] = ISNULL([order].name, ''),
			suborder = ISNULL(suborder.name, ''),
			family = ISNULL(family.name,''),
			subfamily = ISNULL(subfamily.name, ''),
			genus = ISNULL(genus.name,''),
			subgenus = ISNULL(subgenus.name, ''),
			species = species.name 

		FROM taxonomy_node species
		JOIN species_isolates si ON si.taxnode_id = species.taxnode_id 

		-- Subrealm
		LEFT JOIN taxonomy_node subrealm ON (
			species.subrealm_id IS NOT NULL
			AND subrealm.taxnode_id = species.subrealm_id
			AND subrealm.level_id > @targetLevelID
		)

		-- Kingdom
		LEFT JOIN taxonomy_node kingdom ON (
			species.kingdom_id IS NOT NULL
			AND kingdom.taxnode_id = species.kingdom_id
			AND kingdom.level_id > @targetLevelID
		)

		-- Subkingdom
		LEFT JOIN taxonomy_node subkingdom ON (
			species.subkingdom_id IS NOT NULL
			AND subkingdom.taxnode_id = species.subkingdom_id
			AND subkingdom.level_id > @targetLevelID
		)

		-- Phylum
		LEFT JOIN taxonomy_node phylum ON (
			species.phylum_id IS NOT NULL
			AND phylum.taxnode_id = species.phylum_id
			AND phylum.level_id > @targetLevelID
		)

		-- Subphylum
		LEFT JOIN taxonomy_node subphylum ON (
			species.subphylum_id IS NOT NULL
			AND subphylum.taxnode_id = species.subphylum_id
			AND subphylum.level_id > @targetLevelID
		)
		-- Class
		LEFT JOIN taxonomy_node class ON (
			species.class_id IS NOT NULL
			AND class.taxnode_id = species.class_id
			AND class.level_id > @targetLevelID
		)

		-- Subclass
		LEFT JOIN taxonomy_node subclass ON (
			species.subclass_id IS NOT NULL
			AND subclass.taxnode_id = species.subclass_id
			AND subclass.level_id > @targetLevelID
		)

		-- Order
		LEFT JOIN taxonomy_node [order] ON (
			species.order_id IS NOT NULL
			AND [order].taxnode_id = species.order_id
			AND [order].level_id > @targetLevelID
		)

		-- Suborder
		LEFT JOIN taxonomy_node suborder ON (
			species.suborder_id IS NOT NULL
			AND suborder.taxnode_id = species.suborder_id
			AND suborder.level_id > @targetLevelID
		)

		-- Family
		LEFT JOIN taxonomy_node family ON (
			species.family_id IS NOT NULL
			AND family.taxnode_id = species.family_id
			AND family.level_id > @targetLevelID
		)

		-- Subfamily
		LEFT JOIN taxonomy_node subfamily ON (
			species.subfamily_id IS NOT NULL
			AND subfamily.taxnode_id = species.subfamily_id
			AND subfamily.level_id > @targetLevelID
		)

		-- Genus
		LEFT JOIN taxonomy_node genus ON genus.taxnode_id = species.genus_id

		-- Subgenus
		LEFT JOIN taxonomy_node subgenus ON (
			species.subgenus_id IS NOT NULL
			AND subgenus.taxnode_id = species.subgenus_id
			AND subgenus.level_id > @targetLevelID
		)

		WHERE species.left_idx BETWEEN @targetLeftIndex AND @targetRightIndex
		AND species.msl_release_num = @mslRelease
		AND species.is_deleted = 0 
		AND species.is_hidden = 0 
		AND species.is_obsolete = 0 
		AND species.level_id = @speciesLevelID
		AND (@onlyUnassigned = 0
			OR (@onlyUnassigned = 1 
				AND (genus.name = 'unassigned' OR (species.genus_id IS NULL AND species.subgenus_id IS NULL)) 
				AND species.parent_id = @targetTaxNodeID
			) 
		) 
		ORDER BY species.left_idx, si.isolate_sort 

	END TRY
	BEGIN CATCH
		DECLARE @errorMsg AS VARCHAR(200) = ERROR_MESSAGE()
		RAISERROR(@errorMsg, 18, 1)
	END CATCH 
END
GO

