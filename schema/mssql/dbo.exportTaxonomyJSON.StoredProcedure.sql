
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[exportTaxonomyJSON]
	@treeID AS INT

AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

   --==========================================================================================================
	-- Create JSON for the "legend" (ordered rank data for this release).
   --==========================================================================================================
	DECLARE @legendJSON AS VARCHAR(MAX) = (
		SELECT STRING_AGG(rankJSON, '')
		FROM (
			SELECT TOP 100
				'{'+
				'"child_counts":null,'+
				'"has_assigned_siblings":false,'+
				'"has_species":false,'+
				'"is_assigned":false,'+
				'"has_unassigned_siblings":false,'+
				'"name":"Unassigned",'+
				'"parentDistance":1,'+
            '"parentTaxNodeID":null,'+
				'"rankIndex":'+CAST(tr.rank_index AS VARCHAR(2))+','+
				'"rankName":"'+tr.rank_name+'",' +
				'"taxNodeID":"legend",'+
				'"children":[' AS rankJSON

			FROM taxonomy_json_rank tr
			WHERE tr.tree_id = @treeID
			AND tr.rank_index > 0
			ORDER BY tr.rank_index
		) ranksJSON
	)

   --==========================================================================================================
	-- Append "]}" for every non-tree taxonomy rank.
   --==========================================================================================================
	SET @legendJSON = @legendJSON + (
		SELECT STRING_AGG(taxonEnd, '')
		FROM (
			SELECT ']}' AS taxonEnd
			FROM taxonomy_json_rank tr
			WHERE tr.tree_id = @treeID
			AND tr.rank_index > 0
		) taxonEnds
	)

   --==========================================================================================================
   -- Return the JSON result.
   --==========================================================================================================
	SELECT TOP 1 json_result = '{' +
		CAST(tj.json AS VARCHAR(MAX)) +
		'"children":['+@legendJSON+','+ISNULL(CAST(tj.child_json AS VARCHAR(MAX)), '')+']'+
		'}'
	FROM taxonomy_json tj
	WHERE tj.tree_id = @treeID
	AND tj.taxnode_id = @treeID

END
GO

