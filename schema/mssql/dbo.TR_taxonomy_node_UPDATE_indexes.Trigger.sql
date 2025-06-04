USE [ICTVonline40]
GO

/****** Object:  Trigger [dbo].[TR_taxonomy_node_UPDATE_indexes]    Script Date: 6/4/2025 7:21:03 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================================================================
-- trigger

CREATE
--CREATE --DROP
TRIGGER [dbo].[TR_taxonomy_node_UPDATE_indexes] ON [dbo].[taxonomy_node]
AFTER INSERT, UPDATE, DELETE
AS
-- This trigger recomputes the left_idx and right_idx for all
-- rows in the table whenever there are changes to the taxonomy
-- topology:
--	INSERT: all
-- 	DELETE: all
-- 	UPDATE: parent_taxnode_id changes only
--
-- AUTHOR: Curtis Hendrickson (curtish) 2007-Dec-28
-- 20210502 add child count output params to call of [taxonomy_node_compute_indexes]
--          that SP was update on 20200422 to "Add kid/descendant taxa-by-rank counts to taxonomy_node"

SET NOCOUNT ON
--RAISERROR ('TR_taxonomy_node_update_indexes', 1, 1)

--
-- figure out which operation
--
SET NOCOUNT ON

DECLARE @DEL VARCHAR(10)
DECLARE @INS  VARCHAR(10) 
DECLARE @ID_MSG as VARCHAR(100)
-- 
SELECT @DEL=rtrim(count(*)) FROM DELETED
SELECT @INS=rtrim(count(*)) FROM INSERTED
SET @ID_MSG ='TR_taxonomy_node_update_indexes: ROWS: DEL='+@DEL+', INS='+@INS

RAISERROR (@ID_MSG, 1, 1)
-- 
-- IF      @INS = 1 AND @DEL = 1 SET @ACTION = 'UPDATE'
-- ELSE IF @INS = 1 AND @DEL = 0 SET @ACTION = 'INSERT'
-- ELSE IF @INS = 0 AND @DEL = 1 SET @ACTION = 'DELETE'
-- ELSE RETURN

-- if name changed, recompute start_num_sort
IF UPDATE(name)
BEGIN
	SET NOCOUNT ON 
	-- insure correct alpha/num sorting - detect trailing decimals
	RAISERROR ('TR_taxonomy_node_update_indexes: UPDATE(name): [update start_num_sort]', 1, 1)
	UPDATE taxonomy_node 
	SET start_num_sort = len(name)-
		case
			-- last 4 chars are numeric
			when charindex(right(name,1),'1234567890')
				*charindex(left(right(name,2),1),'1234567890')
				*charindex(left(right(name,3),1),'1234567890')
				*charindex(left(right(name,4),1),'1234567890') 
				> 0
			then 4
			-- last 3 chars are numeric
			when charindex(right(name,1),'1234567890')
				*charindex(left(right(name,2),1),'1234567890')
				*charindex(left(right(name,3),1),'1234567890')
				> 0
			then 3
			-- last 2 chars are numeric
			when charindex(right(name,1),'1234567890')
				*charindex(left(right(name,2),1),'1234567890') 
				> 0
			then 2
			-- last 1 chars are numeric
			when charindex(right(name,1),'1234567890') > 0
			then 1
			-- no trailing numerics
			else NULL
		end
	--WHERE charindex(right(name,1),'1234567890') > 0 -- last 1 chars are numeric
	select @ID_MSG = 'TR_taxonomy_node_update_indexes: UPDATE(name): [update start_num_sort] name='+name+', start_num_sort='+isnull(rtrim(start_num_sort),'NULL') from taxonomy_node;
	RAISERROR (@ID_MSG, 1, 1)
END 
--
-- if topology changed - recompute!
-- 
IF UPDATE(parent_id) OR UPDATE(level_id) or UPDATE(tree_id) -- INSERT or UPDATE
   --OR EXISTS(SELECT * FROM INSERTED i WHERE i.taxnode_id NOT IN (SELECT d.taxnode_id FROM DELETED d))
   --OR EXISTS(SELECT * FROM DELETED d WHERE d.taxnode_id NOT IN (SELECT i.taxnode_id FROM INSERTED i))
BEGIN
	-- 
	-- re-index the whole tree - the structure changed
	--
	RAISERROR ('TR_taxonomy_node_update_indexes: called.', 1, 1)
	IF UPDATE(parent_id) RAISERROR ('TR_taxonomy_node_update_indexes: UPDATE(parent_id).', 1, 1)
	IF UPDATE(level_id) RAISERROR ('TR_taxonomy_node_update_indexes: UPDATE(level_id).', 1, 1)
	IF UPDATE(tree_id) RAISERROR ('TR_taxonomy_node_update_indexes: UPDATE(tree_id).', 1, 1)
	--IF EXISTS(SELECT * FROM INSERTED i WHERE i.taxnode_id NOT IN (SELECT d.taxnode_id FROM DELETED d)) RAISERROR ('TR_taxonomy_node_update_indexes: INSERT new taxnode_id.', 1, 1)
	--IF EXISTS(SELECT * FROM DELETED d WHERE d.taxnode_id NOT IN (SELECT i.taxnode_id FROM INSERTED i)) RAISERROR ('TR_taxonomy_node_update_indexes: DELETE existing taxnode_id.', 1, 1)
	DECLARE @tree_id int
	DECLARE @mesg varchar(200)
	SET NOCOUNT ON 

	-- CURSOR
	DECLARE [CUR_TREES] SCROLL CURSOR FOR 
		select tree_id from DELETED i group by tree_id
		union 
		select tree_id from INSERTED i group by tree_id
	OPEN [CUR_TREES]
	FETCH NEXT FROM [CUR_TREES] INTO @tree_id
	WHILE @@FETCH_STATUS = 0 BEGIN
  		-- DO WORK HERE
		exec [taxonomy_node_compute_indexes] @tree_id
		SET @mesg = 'TR_taxonomy_node_update_indexes: tree['+rtrim(@tree_id)+'] re-indexed';
		RAISERROR (@mesg, 1, 1)
		--print 'synced gene_id='+rtrim(@family_id)+'.'+rtrim(@gene_id)
   		-- NEXT
		FETCH NEXT FROM [CUR_TREES] INTO @tree_id
	END; CLOSE [CUR_TREES]; DEALLOCATE [CUR_TREES]

	SET NOCOUNT OFF
 
END
ELSE IF UPDATE(name) or UPDATE(molecule_id) 
BEGIN
	SET NOCOUNT ON 

	-- re-index this node's parent's substree - the name changed and that affects the (computed) lineage field
	IF UPDATE(name) RAISERROR ('TR_taxonomy_node_update_indexes: UPDATE(name): [subtree index]', 1, 1)
	IF UPDATE(molecule_id) RAISERROR ('TR_taxonomy_node_update_indexes: UPDATE(molecule_id): [subtree index].', 1, 1)
	DECLARE @taxnode_id int
	DECLARE @left_idx  int
	DECLARE @right_idx int
	DECLARE @node_depth     int
	-- start taxa
	DECLARE @realm_id int = NULL
	DECLARE @subrealm_id int = NULL
	DECLARE @kingdom_id int = NULL
	DECLARE @subkingdom_id int = NULL
	DECLARE @phylum_id int = NULL
	DECLARE @subphylum_id int = NULL
	DECLARE @class_id int = NULL
	DECLARE @subclass_id int = NULL
	DECLARE @order_id int = NULL
	DECLARE @suborder_id int = NULL
	DECLARE @family_id int = NULL
	DECLARE @subfamily_id int = NULL
	DECLARE @genus_id int = NULL
	DECLARE @subgenus_id int = NULL
	DECLARE @species_id int = NULL
	-- end taxa
	-- start descendant counts
	DECLARE @realm_desc_ct int = 0
    DECLARE @subrealm_desc_ct int = 0
    DECLARE @kingdom_desc_ct int = 0
    DECLARE @subkingdom_desc_ct int = 0
    DECLARE @phylum_desc_ct int = 0
    DECLARE @subphylum_desc_ct int = 0
    DECLARE @class_desc_ct int = 0
    DECLARE @subclass_desc_ct int = 0
    DECLARE @order_desc_ct int = 0
    DECLARE @suborder_desc_ct int = 0
    DECLARE @family_desc_ct int = 0 
    DECLARE @subfamily_desc_ct int = 0
    DECLARE @genus_desc_ct int = 0
    DECLARE @subgenus_desc_ct int = 0
    DECLARE @species_desc_ct int = 0
	-- end descendant counts
	DECLARE @inher_molecule_id int
	DECLARE @lineage varchar(1000)
	-- CURSOR
	DECLARE [CUR_NODES] SCROLL CURSOR FOR 
		select distinct
			parent.taxnode_id,
			parent.left_idx,
			parent.right_idx,
			parent.node_depth,
			-- start taxa
			parent.[realm_id],
			parent.[subrealm_id],
			parent.[kingdom_id],
			parent.[subkingdom_id],
			parent.[phylum_id],
			parent.[subphylum_id],
			parent.[class_id],
			parent.[subclass_id],
			parent.[order_id],
			parent.[suborder_id],
			parent.[family_id],
			parent.[subfamily_id],
			parent.[genus_id],
			parent.[subgenus_id],
			parent.[species_id],
			-- end taxa
			parent.inher_molecule_id,
			-- starter lineage is NULL for top node of tree
			case when parent.taxnode_id = parent.parent_id or gparent.taxnode_id=gparent.parent_id then null else gparent.lineage end
		from INSERTED i
		join taxonomy_node parent on parent.taxnode_id = i.parent_id
		left outer join taxonomy_node gparent on gparent.taxnode_id = parent.parent_id
	OPEN [CUR_NODES]
	FETCH NEXT FROM [CUR_NODES] INTO @taxnode_id,@left_idx,@right_idx,@node_depth,@realm_id,@subrealm_id,@kingdom_id,@subkingdom_id,@phylum_id,@subphylum_id,@class_id,@subclass_id,@order_id,@suborder_id,@family_id,@subfamily_id,@genus_id,@subgenus_id,@species_id,@inher_molecule_id,@lineage
	WHILE @@FETCH_STATUS = 0 BEGIN
  		-- DO WORK HERE
		--/*DEBUG*/print('exec [taxonomy_node_compute_indexes] '+isnull(rtrim(@taxnode_id),'NULL')+','+isnull(rtrim(@left_idx),'NULL')+','+isnull(rtrim(@right_idx),'NULL')+','+isnull(rtrim(@node_depth),'NULL')+','+isnull(rtrim(@realm_id),'NULL')+','+isnull(rtrim(@subrealm_id),'NULL')+','+isnull(rtrim(@kingdom_id),'NULL')+','+isnull(rtrim(@subkingdom_id),'NULL')+','+isnull(rtrim(@phylum_id),'NULL')+','+isnull(rtrim(@subphylum_id),'NULL')+','+isnull(rtrim(@class_id),'NULL')+','+isnull(rtrim(@subclass_id),'NULL')+','+isnull(rtrim(@order_id),'NULL')+','+isnull(rtrim(@suborder_id),'NULL')+','+isnull(rtrim(@family_id),'NULL')+','+isnull(rtrim(@subfamily_id),'NULL')+','+isnull(rtrim(@genus_id),'NULL')+','+isnull(rtrim(@subgenus_id),'NULL')+','+isnull(rtrim(@species_id),'NULL')+','+isnull(rtrim(@inher_molecule_id),'NULL')+','+isnull(@lineage,'NULL'))
		exec [taxonomy_node_compute_indexes]  
			@taxnode_id,
			@left_idx,
			@right_idx,
			@node_depth,
			-- start taxa
			@realm_id,
			@subrealm_id,
			@kingdom_id,
			@subkingdom_id,
			@phylum_id,
			@subphylum_id,
			@class_id,
			@subclass_id,
			@order_id,
			@suborder_id,
			@family_id,
			@subfamily_id,
			@genus_id,
			@subgenus_id,
			@species_id,
			-- end taxa, start child counts
			-- start descendant counts
			@realm_desc_ct,
			@subrealm_desc_ct,
			@kingdom_desc_ct,
			@subkingdom_desc_ct,
			@phylum_desc_ct,
			@subphylum_desc_ct,
			@class_desc_ct,
			@subclass_desc_ct,
			@order_desc_ct,
			@suborder_desc_ct,
			@family_desc_ct,
			@subfamily_desc_ct,
			@genus_desc_ct,
			@subgenus_desc_ct,
			@species_desc_ct,
			--end descendant counts 
			@inher_molecule_id,
			@lineage
		SET @mesg = 'TR_taxonomy_node_update_indexes: node['+rtrim(@taxnode_id)+'] re-indexed';
		RAISERROR (@mesg, 1, 1)
		--print 'synced gene_id='+rtrim(@family_id)+'.'+rtrim(@gene_id)
   		-- NEXT
		FETCH NEXT FROM [CUR_NODES] INTO @taxnode_id,@left_idx,@right_idx,@node_depth,@realm_id,@subrealm_id,@kingdom_id,@subkingdom_id,@phylum_id,@subphylum_id,@class_id,@subclass_id,@order_id,@suborder_id,@family_id,@subfamily_id,@genus_id,@subgenus_id,@species_id,@inher_molecule_id,@lineage
	END; CLOSE [CUR_NODES]; DEALLOCATE [CUR_NODES]

	SET NOCOUNT OFF
 END
GO

ALTER TABLE [dbo].[taxonomy_node] ENABLE TRIGGER [TR_taxonomy_node_UPDATE_indexes]
GO


