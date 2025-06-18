
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE   
PROCEDURE [dbo].[taxonomy_node_compute_indexes] 
	@taxnode_id int,
	@left_idx  int = 1,
	@right_idx int = NULL OUTPUT,
	@node_depth     int = 1,
	-- start taxa
	@realm_id int = NULL,
	@subrealm_id int = NULL,
	@kingdom_id int = NULL,
	@subkingdom_id int = NULL,
	@phylum_id int = NULL,
	@subphylum_id int = NULL,
	@class_id int = NULL,
	@subclass_id int = NULL,
	@order_id int = NULL,
	@suborder_id int = NULL,
	@family_id int = NULL,
	@subfamily_id int = NULL,
	@genus_id int = NULL,
	@subgenus_id int = NULL,
	@species_id int = NULL,
	-- end taxa
	-- start descendant counts
	@realm_desc_ct int = 0 OUTPUT,
    @subrealm_desc_ct int = 0 OUTPUT,
    @kingdom_desc_ct int = 0 OUTPUT,
    @subkingdom_desc_ct int = 0 OUTPUT,
    @phylum_desc_ct int = 0 OUTPUT,
    @subphylum_desc_ct int = 0 OUTPUT,
    @class_desc_ct int = 0 OUTPUT,
    @subclass_desc_ct int = 0 OUTPUT,
    @order_desc_ct int = 0 OUTPUT,
    @suborder_desc_ct int = 0 OUTPUT,
    @family_desc_ct int = 0 OUTPUT,
    @subfamily_desc_ct int = 0 OUTPUT,
    @genus_desc_ct int = 0 OUTPUT,
    @subgenus_desc_ct int = 0 OUTPUT,
    @species_desc_ct int = 0 OUTPUT,
	-- end descendant counts
	@inher_molecule_id int = NULL,
	@lineage varchar(1000) = NULL
AS	
	DECLARE @hidden_as_unassigned int; 
	DECLARE @use_my_lineage int; 
	DECLARE @my_lineage varchar(1000);
	-- start direct kid counts
    DECLARE @realm_kid_ct int; SET @realm_kid_ct = 0
    DECLARE @subrealm_kid_ct int; SET @subrealm_kid_ct = 0
    DECLARE @kingdom_kid_ct int; SET @kingdom_kid_ct = 0
    DECLARE @subkingdom_kid_ct int; SET @subkingdom_kid_ct = 0
    DECLARE @phylum_kid_ct int; SET @phylum_kid_ct = 0
    DECLARE @subphylum_kid_ct int; SET @subphylum_kid_ct = 0
    DECLARE @class_kid_ct int; SET @class_kid_ct = 0
    DECLARE @subclass_kid_ct int; SET @subclass_kid_ct = 0
    DECLARE @order_kid_ct int; SET @order_kid_ct = 0
    DECLARE @suborder_kid_ct int; SET @suborder_kid_ct = 0
    DECLARE @family_kid_ct int; SET @family_kid_ct = 0
    DECLARE @subfamily_kid_ct int; SET @subfamily_kid_ct = 0
    DECLARE @genus_kid_ct int; SET @genus_kid_ct = 0
    DECLARE @subgenus_kid_ct int; SET @subgenus_kid_ct = 0
    DECLARE @species_kid_ct int; SET @species_kid_ct = 0
	-- end direct kid counts

	-- 
	-- display hidden nodes (mostly subfamilies)
	-- as "Unassigned"
	-- 
	SET @hidden_as_unassigned = 1

	-- find the root, if it is not specified 
	-- REMOVED: can't function if multiple trees in db (w/o cursor)
	/*IF @taxnode_id IS NULL 
		SELECT TOP 1 @taxnode_id=taxnode_id 
		FROM taxonomy_node self
		JOIN taxonomy_level level on level.id = self.level_id
		WHERE level.name =  'tree'
	*/
	-- debug
	--print '[taxonomy_node_compute_indexes] '+str(@node_depth) + '==>' + str(@taxnode_id)

	--print '[taxonomy_node_compute_indexes] '+'-- update data for this node'
	SELECT 
		-- update computed cached levels, if not already set
		-- start taxa
		@realm_id = ISNULL(@realm_id, case when level.name='realm' then self.taxnode_id else NULL end)
		,@subrealm_id = ISNULL(@subrealm_id, case when level.name='subrealm' then self.taxnode_id else NULL end)
		,@kingdom_id = ISNULL(@kingdom_id, case when level.name='kingdom' then self.taxnode_id else NULL end)
		,@subkingdom_id = ISNULL(@subkingdom_id, case when level.name='subkingdom' then self.taxnode_id else NULL end)
		,@phylum_id = ISNULL(@phylum_id, case when level.name='phylum' then self.taxnode_id else NULL end)
		,@subphylum_id = ISNULL(@subphylum_id, case when level.name='subphylum' then self.taxnode_id else NULL end)
		,@class_id = ISNULL(@class_id, case when level.name='class' then self.taxnode_id else NULL end)
		,@subclass_id = ISNULL(@subclass_id, case when level.name='subclass' then self.taxnode_id else NULL end)
		,@order_id = ISNULL(@order_id, case when level.name='order' then self.taxnode_id else NULL end)
		,@suborder_id = ISNULL(@suborder_id, case when level.name='suborder' then self.taxnode_id else NULL end)
		,@family_id = ISNULL(@family_id, case when level.name='family' then self.taxnode_id else NULL end)
		,@subfamily_id = ISNULL(@subfamily_id, case when level.name='subfamily' then self.taxnode_id else NULL end)
		,@genus_id = ISNULL(@genus_id, case when level.name='genus' then self.taxnode_id else NULL end)
		,@subgenus_id = ISNULL(@subgenus_id, case when level.name='subgenus' then self.taxnode_id else NULL end)
		,@species_id = ISNULL(@species_id, case when level.name='species' then self.taxnode_id else NULL end)
		-- end taxa
		-- update molcule type, even if already set
		,@inher_molecule_id   = ISNULL(self.molecule_id,ISNULL(@inher_molecule_id,self.inher_molecule_id))
		-- update running lineage
		,@use_my_lineage = case 
				when self.taxnode_id = self.tree_id then 0 -- don't include tree name in lineage!
				when @hidden_as_unassigned=1 then 1
				when self.is_hidden=1 or self.name is null then 0 
				else 1 end
		,@my_lineage = 
			ISNULL(@lineage,'')
			+(case when len(@lineage)>0 then ';' else '' end)
			+(case when self.is_hidden=1 and @hidden_as_unassigned=0 then '[' else '' end)
			+ISNULL(self.name,(case when @hidden_as_unassigned=1 then 'Unassigned' else '- unnamed -' end) )
			+(case when self.is_hidden=1 and @hidden_as_unassigned=0 then ']' else '' end)
	FROM taxonomy_node self 
	LEFT OUTER JOIN taxonomy_level level on level.id = self.level_id
	WHERE	self.taxnode_id = @taxnode_id
	
	
	--print '[taxonomy_node_compute_indexes] '+'-- set our LEFT index & cached parent taxa'
	UPDATE taxonomy_node
	SET 
		left_idx=@left_idx
		, node_depth=@node_depth
		-- start taxa
		, [realm_id]=@realm_id
		, [subrealm_id]=@subrealm_id
		, [kingdom_id]=@kingdom_id
		, [subkingdom_id]=@subkingdom_id
		, [phylum_id]=@phylum_id
		, [subphylum_id]=@subphylum_id
		, [class_id]=@class_id
		, [subclass_id]=@subclass_id
		, [order_id]=@order_id
		, [suborder_id]=@suborder_id
		, [family_id]=@family_id
		, [subfamily_id]=@subfamily_id
		, [genus_id]=@genus_id
		, [subgenus_id]=@subgenus_id
		, [species_id]=@species_id
		-- end taxa
		, inher_molecule_id=@inher_molecule_id
		, lineage = @my_lineage
	WHERE taxnode_id = @taxnode_id
	and (
		-- don't update unchanged nodes
		(left_idx <> @left_idx or (left_idx is null and @left_idx is not null))
	or (node_depth <> @node_depth or (node_depth is null and @node_depth is not null))
	-- start taxa
	or ([realm_id] <> @realm_id or ([realm_id] is null and @realm_id is not null))
	or ([subrealm_id] <> @subrealm_id or ([subrealm_id] is null and @subrealm_id is not null))
	or ([kingdom_id] <> @kingdom_id or ([kingdom_id] is null and @kingdom_id is not null))
	or ([subkingdom_id] <> @subkingdom_id or ([subkingdom_id] is null and @subkingdom_id is not null))
	or ([phylum_id] <> @phylum_id or ([phylum_id] is null and @phylum_id is not null))
	or ([subphylum_id] <> @subphylum_id or ([subphylum_id] is null and @subphylum_id is not null))
	or ([class_id] <> @class_id or ([class_id] is null and @class_id is not null))
	or ([subclass_id] <> @subclass_id or ([subclass_id] is null and @subclass_id is not null))
	or ([order_id] <> @order_id or ([order_id] is null and @order_id is not null))
	or ([suborder_id] <> @suborder_id or ([suborder_id] is null and @suborder_id is not null))
	or ([family_id] <> @family_id or ([family_id] is null and @family_id is not null))
	or ([subfamily_id] <> @subfamily_id or ([subfamily_id] is null and @subfamily_id is not null))
	or ([genus_id] <> @genus_id or ([genus_id] is null and @genus_id is not null))
	or ([subgenus_id] <> @subgenus_id or ([subgenus_id] is null and @subgenus_id is not null))
	or ([species_id] <> @species_id or ([species_id] is null and @species_id is not null))
	-- end taxa
	or (inher_molecule_id <> @inher_molecule_id or (inher_molecule_id is null and @inher_molecule_id is not null))
	or (lineage <> @lineage or (lineage is null and @lineage is not null))
	)

	-- if we're NOT a hidden node, then include me in my children's lineage
	IF @use_my_lineage = 1 SET @lineage = @my_lineage

	--
	-- walk our children, recursing
	--
	
	-- tracking counts : direct kids, and descendants for each rank

	--print '[taxonomy_node_compute_indexes] '+'-- clear our childrens indexes'
	UPDATE taxonomy_node 
	SET left_idx=null, right_idx=null 
	WHERE parent_id = @taxnode_id AND taxnode_id <> @taxnode_id

	DECLARE @child_taxnode_id int
	DECLARE @child_rank varchar(50)
	DECLARE @child_is_hidden int
	
	DECLARE @child_depth int
	SET @child_depth = @node_depth + 1

	SET @right_idx = @left_idx + 1

	-- get next child (repeated inside loop)
	SET @child_taxnode_id = NULL
	SET @child_rank = NULL
	SET @child_is_hidden = NULL
	SELECT TOP 1
			@child_taxnode_id = n.taxnode_id
			, @child_is_hidden = n.is_hidden
			, @child_rank = rank.name
		FROM taxonomy_node n
		JOIN taxonomy_level rank on rank.id = n.level_id
		WHERE n.parent_id = @taxnode_id
		AND n.taxnode_id <> @taxnode_id
		AND n.left_idx IS NULL
		ORDER BY  -- rank, name
			n.level_id
			,case when n.start_num_sort is null then isnull(n.name,'ZZZZ') else left(n.name,n.start_num_sort) end -- alpha, force unassigned to bottom
			, case when n.start_num_sort is null then null else floor(ltrim(substring(n.name,n.start_num_sort+1,50))) end -- numeric


	WHILE @child_taxnode_id IS NOT NULL
	BEGIN
        -- start kids descendant counts
        DECLARE @kid_realm_desc_ct int; SET @kid_realm_desc_ct = 0
        DECLARE @kid_subrealm_desc_ct int; SET @kid_subrealm_desc_ct = 0
        DECLARE @kid_kingdom_desc_ct int; SET @kid_kingdom_desc_ct = 0
        DECLARE @kid_subkingdom_desc_ct int; SET @kid_subkingdom_desc_ct = 0
        DECLARE @kid_phylum_desc_ct int; SET @kid_phylum_desc_ct = 0
        DECLARE @kid_subphylum_desc_ct int; SET @kid_subphylum_desc_ct = 0
        DECLARE @kid_class_desc_ct int; SET @kid_class_desc_ct = 0
        DECLARE @kid_subclass_desc_ct int; SET @kid_subclass_desc_ct = 0
        DECLARE @kid_order_desc_ct int; SET @kid_order_desc_ct = 0
        DECLARE @kid_suborder_desc_ct int; SET @kid_suborder_desc_ct = 0
        DECLARE @kid_family_desc_ct int; SET @kid_family_desc_ct = 0
        DECLARE @kid_subfamily_desc_ct int; SET @kid_subfamily_desc_ct = 0
        DECLARE @kid_genus_desc_ct int; SET @kid_genus_desc_ct = 0
        DECLARE @kid_subgenus_desc_ct int; SET @kid_subgenus_desc_ct = 0
        DECLARE @kid_species_desc_ct int; SET @kid_species_desc_ct = 0
		-- end kid descendant counts

		--print '[taxonomy_node_compute_indexes] '+'-- recuse into child: @taxnode_id='+rtrim(@child_taxnode_id)+', lineage='+@lineage
		EXEC [taxonomy_node_compute_indexes] 
			@taxnode_id = @child_taxnode_id, 
			@left_idx   = @right_idx, 
			@right_idx  = @right_idx OUTPUT, 
			@node_depth = @child_depth,
			-- start taxa
			@realm_id=@realm_id,
			@subrealm_id=@subrealm_id,
			@kingdom_id=@kingdom_id,
			@subkingdom_id=@subkingdom_id,
			@phylum_id=@phylum_id,
			@subphylum_id=@subphylum_id,
			@class_id=@class_id,
			@subclass_id=@subclass_id,
			@order_id=@order_id,
			@suborder_id=@suborder_id,
			@family_id=@family_id,
			@subfamily_id=@subfamily_id,
			@genus_id=@genus_id,
			@subgenus_id=@subgenus_id,
			@species_id=@species_id,
			-- end taxa
			-- start kids/descendant counts
			@realm_desc_ct = @kid_realm_desc_ct OUTPUT,
			@subrealm_desc_ct = @kid_subrealm_desc_ct OUTPUT,
			@kingdom_desc_ct = @kid_kingdom_desc_ct OUTPUT,
			@subkingdom_desc_ct = @kid_subkingdom_desc_ct OUTPUT,
			@phylum_desc_ct = @kid_phylum_desc_ct OUTPUT,
			@subphylum_desc_ct = @kid_subphylum_desc_ct OUTPUT,
			@class_desc_ct = @kid_class_desc_ct OUTPUT,
			@subclass_desc_ct = @kid_subclass_desc_ct OUTPUT,
			@order_desc_ct = @kid_order_desc_ct OUTPUT,
			@suborder_desc_ct = @kid_suborder_desc_ct OUTPUT,
			@family_desc_ct = @kid_family_desc_ct OUTPUT,
			@subfamily_desc_ct = @kid_subfamily_desc_ct OUTPUT,
			@genus_desc_ct = @kid_genus_desc_ct OUTPUT,
			@subgenus_desc_ct = @kid_subgenus_desc_ct OUTPUT,
			@species_desc_ct = @kid_species_desc_ct OUTPUT,
			-- end kids/descendant counts
			@inher_molecule_id = @inher_molecule_id,
			@lineage = @lineage

		-- update direct child counts for un-hidden children
		if @child_is_hidden=0 BEGIN
			SET @realm_kid_ct		= @realm_kid_ct			+(case when @child_rank='realm' then 1 else 0 end)
			SET @subrealm_kid_ct	= @subrealm_kid_ct		+(case when @child_rank='subrealm' then 1 else 0 end)
			SET @kingdom_kid_ct		= @kingdom_kid_ct		+(case when @child_rank='kingdom' then 1 else 0 end)
			SET @subkingdom_kid_ct	= @subkingdom_kid_ct	+(case when @child_rank='subkingdom' then 1 else 0 end)
			SET @phylum_kid_ct		= @phylum_kid_ct		+(case when @child_rank='phylum' then 1 else 0 end)
			SET @subphylum_kid_ct	= @subphylum_kid_ct		+(case when @child_rank='subphylum' then 1 else 0 end)
			SET @class_kid_ct		= @class_kid_ct			+(case when @child_rank='class' then 1 else 0 end)
			SET @subclass_kid_ct	= @subclass_kid_ct		+(case when @child_rank='subclass' then 1 else 0 end)
			SET @order_kid_ct		= @order_kid_ct			+(case when @child_rank='order' then 1 else 0 end)
			SET @suborder_kid_ct	= @suborder_kid_ct		+(case when @child_rank='suborder' then 1 else 0 end)
			SET @family_kid_ct		= @family_kid_ct		+(case when @child_rank='family' then 1 else 0 end)
			SET @subfamily_kid_ct	= @subfamily_kid_ct		+(case when @child_rank='subfamily' then 1 else 0 end)
			SET @genus_kid_ct		= @genus_kid_ct			+(case when @child_rank='genus' then 1 else 0 end)
			SET @subgenus_kid_ct	= @subgenus_kid_ct		+(case when @child_rank='subgenus' then 1 else 0 end)
			SET @species_kid_ct		= @species_kid_ct		+(case when @child_rank='species' then 1 else 0 end)
		END
		-- update running descendant counts
        SET @realm_desc_ct       = @realm_desc_ct       + @kid_realm_desc_ct
        SET @subrealm_desc_ct    = @subrealm_desc_ct    + @kid_subrealm_desc_ct
        SET @kingdom_desc_ct     = @kingdom_desc_ct     + @kid_kingdom_desc_ct
        SET @subkingdom_desc_ct  = @subkingdom_desc_ct  + @kid_subkingdom_desc_ct
        SET @phylum_desc_ct      = @phylum_desc_ct      + @kid_phylum_desc_ct
        SET @subphylum_desc_ct   = @subphylum_desc_ct   + @kid_subphylum_desc_ct
        SET @class_desc_ct       = @class_desc_ct       + @kid_class_desc_ct
        SET @subclass_desc_ct    = @subclass_desc_ct    + @kid_subclass_desc_ct
        SET @order_desc_ct       = @order_desc_ct       + @kid_order_desc_ct
        SET @suborder_desc_ct    = @suborder_desc_ct    + @kid_suborder_desc_ct
        SET @family_desc_ct      = @family_desc_ct      + @kid_family_desc_ct
        SET @subfamily_desc_ct   = @subfamily_desc_ct   + @kid_subfamily_desc_ct
        SET @genus_desc_ct       = @genus_desc_ct       + @kid_genus_desc_ct
        SET @subgenus_desc_ct    = @subgenus_desc_ct    + @kid_subgenus_desc_ct
        SET @species_desc_ct     = @species_desc_ct     + @kid_species_desc_ct

		-- compute left_idx for next sibling
		SET @right_idx = @right_idx + 1

		-- get next child (repeated before loop)
		SET @child_taxnode_id = NULL
		SET @child_rank = NULL
		SET @child_is_hidden = NULL
		SELECT TOP 1
				@child_taxnode_id = n.taxnode_id
				, @child_is_hidden = n.is_hidden
				, @child_rank = rank.name
			FROM taxonomy_node n
			JOIN taxonomy_level rank on rank.id = n.level_id
			WHERE n.parent_id = @taxnode_id
			AND n.taxnode_id <> @taxnode_id
			AND n.left_idx IS NULL
			ORDER BY  -- rank, name
				n.level_id
				,case when n.start_num_sort is null then isnull(n.name,'ZZZZ') else left(n.name,n.start_num_sort) end -- alpha, force unassigned to bottom
				, case when n.start_num_sort is null then null else floor(ltrim(substring(n.name,n.start_num_sort+1,50))) end -- numeric

	END	

	-- output our total descendant counts
    SET @realm_desc_ct       = @realm_desc_ct       + @realm_kid_ct
    SET @subrealm_desc_ct    = @subrealm_desc_ct    + @subrealm_kid_ct
    SET @kingdom_desc_ct     = @kingdom_desc_ct     + @kingdom_kid_ct
    SET @subkingdom_desc_ct  = @subkingdom_desc_ct  + @subkingdom_kid_ct
    SET @phylum_desc_ct      = @phylum_desc_ct      + @phylum_kid_ct
    SET @subphylum_desc_ct   = @subphylum_desc_ct   + @subphylum_kid_ct
    SET @class_desc_ct       = @class_desc_ct       + @class_kid_ct
    SET @subclass_desc_ct    = @subclass_desc_ct    + @subclass_kid_ct
    SET @order_desc_ct       = @order_desc_ct       + @order_kid_ct
    SET @suborder_desc_ct    = @suborder_desc_ct    + @suborder_kid_ct
    SET @family_desc_ct      = @family_desc_ct      + @family_kid_ct
    SET @subfamily_desc_ct   = @subfamily_desc_ct   + @subfamily_kid_ct
    SET @genus_desc_ct       = @genus_desc_ct       + @genus_kid_ct
    SET @subgenus_desc_ct    = @subgenus_desc_ct    + @subgenus_kid_ct
    SET @species_desc_ct     = @species_desc_ct     + @species_kid_ct

	-- set our RIGHT index, KID cts and DESC cts
	UPDATE taxonomy_node SET 
		right_idx = @right_idx
        -- start kids/descendant counts
        , realm_desc_ct = @realm_desc_ct                , realm_kid_ct = @realm_kid_ct
        , subrealm_desc_ct = @subrealm_desc_ct          , subrealm_kid_ct = @subrealm_kid_ct
        , kingdom_desc_ct = @kingdom_desc_ct            , kingdom_kid_ct = @kingdom_kid_ct
        , subkingdom_desc_ct = @subkingdom_desc_ct      , subkingdom_kid_ct = @subkingdom_kid_ct
        , phylum_desc_ct = @phylum_desc_ct              , phylum_kid_ct = @phylum_kid_ct
        , subphylum_desc_ct = @subphylum_desc_ct        , subphylum_kid_ct = @subphylum_kid_ct
        , class_desc_ct = @class_desc_ct                , class_kid_ct = @class_kid_ct
        , subclass_desc_ct = @subclass_desc_ct          , subclass_kid_ct = @subclass_kid_ct
        , order_desc_ct = @order_desc_ct                , order_kid_ct = @order_kid_ct
        , suborder_desc_ct = @suborder_desc_ct          , suborder_kid_ct = @suborder_kid_ct
        , family_desc_ct = @family_desc_ct              , family_kid_ct = @family_kid_ct
        , subfamily_desc_ct = @subfamily_desc_ct        , subfamily_kid_ct = @subfamily_kid_ct
        , genus_desc_ct = @genus_desc_ct                , genus_kid_ct = @genus_kid_ct
        , subgenus_desc_ct = @subgenus_desc_ct          , subgenus_kid_ct = @subgenus_kid_ct
        , species_desc_ct = @species_desc_ct            , species_kid_ct = @species_kid_ct
	    -- start kids/descendant counts
		-- start kid/descendant strings
		, taxa_kid_cts = dbo.udf_rankCountsToStringWithPurals(
				@realm_kid_ct,         @subrealm_kid_ct,
				@kingdom_kid_ct,       @subkingdom_kid_ct,
				@phylum_kid_ct,        @subphylum_kid_ct,
				@class_kid_ct,         @subclass_kid_ct,
				@order_kid_ct,         @suborder_kid_ct,
				@family_kid_ct,        @subfamily_kid_ct,
				@genus_kid_ct,         @subgenus_kid_ct,
				@species_kid_ct
			)
		, taxa_desc_cts = dbo.udf_rankCountsToStringWithPurals(
				@realm_desc_ct,         @subrealm_desc_ct,
				@kingdom_desc_ct,       @subkingdom_desc_ct,
				@phylum_desc_ct,        @subphylum_desc_ct,
				@class_desc_ct,         @subclass_desc_ct,
				@order_desc_ct,         @suborder_desc_ct,
				@family_desc_ct,        @subfamily_desc_ct,
				@genus_desc_ct,         @subgenus_desc_ct,
				@species_desc_ct
			)
	WHERE taxnode_id = @taxnode_id


	-- debug
	--print str(@node_depth) + '<==' + str(@taxnode_id)
	
	-- test
	-- exec taxonomy_node_compute_indexes 20170000
	-- 
	-- build script to re-index all trees
	--select 'exec taxonomy_node_compute_indexes '+rtrim(taxnode_id) from taxonomy_node where level_id =100
GO


