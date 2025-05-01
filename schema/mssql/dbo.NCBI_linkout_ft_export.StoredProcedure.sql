
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE procedure [dbo].[NCBI_linkout_ft_export]
 	 @msl int = NULL,
	 @newline varchar(10) ='|'
AS

/*
--
-- test
-- 
exec [NCBI_linkout_ft_export] 1
exec [NCBI_linkout_ft_export] 37, '|'

-- use NL/CR as column separator - this is how we do the actual export
DECLARE @nl varchar(10); SET @nl=char(13)+char(10)
exec [NCBI_linkout_ft_export] NULL, @nl

--
-- CHANGE LOG
--
-- 20250429 CurtisH switch from taxnode_id to ictv_id for linking
--
*/

-- debug DECLARES for args
-- declare @msl int; declare @newline varchar(10) 

DECLARE @URL varchar(500); 
DECLARE @LINKOUT_PROVIDER_ID varchar(10); 

-- constants for ICTV
SET @LINKOUT_PROVIDER_ID = '7640'
-- ictv_id= support is still in test, not prod (2025.04.30)
--SET @URL = 'https://ictv.global/taxonomy/taxondetails?ictv_id='
SET @URL = 'https://ictv.global/taxonomy/taxondetails?taxnode_id='

-- get most recent MSL, if not specified in args
set @msl = (select isnull(@msl,max(msl_release_num)) from taxonomy_node)

-- use WINDOWS line terminators, if not specified in args
-- The Mac, by default, uses a single carriage return (<CR>), represented as \r. 
-- Unix, on the other hand, uses a single linefeed (<LF>), \n. 
-- Windows goes one step further and uses both, creating a (<CRLF>) combination, \r\n.
--set @newline = isnull(@newline,char(13)) -- Mac (\r)
---set @newline = isnull(@newline,char(10)) -- Linux (\n)
set @newline = isnull(@newline,char(13)+char(10)) -- Windows
--set @newline = '|' -- map after download

-- debugging
--print 'MSL: ' + @newline + rtrim(@msl)


select [# linkout.ft]=t
from (
	--
	-- print the header that identifies us as a linkout provider
	--
	-- this gives
	--     our provider id (prid:)
	--     our base URL, to which the record key will be appended
	--
	select 
		left_idx=NULL, msl_release_num=NULL, t=
		'---------------------------------------------------------------' + @newline
		+ 'prid:   '+ @LINKOUT_PROVIDER_ID + @newline
		+ 'dbase:  taxonomy' + @newline
		+ 'stype:  taxonomy/phylogenetic' + @newline
		+ '!base:  '+ @URL + @newline
		+ '---------------------------------------------------------------' 
union all
	-- 
	-- export the actual taxa
	-- 
	/*
	-- ---------------------------------------------------------
	-- "All distinct names"  version
	-- ---------------------------------------------------------
	-- This version provides a link for all unique names, ever. 
	-- 
	-- This was created to deal with the weeks/months after a new MSL
	-- release when NCBI is still using the old taxonomy. 
	-- 
	-- HOWEVER, NCBI linkout has a bug where >1 link on a node (say, it's
	-- old and new names, after a rename) creates a disambiguation link that
	-- then errors out. 

	-- use "left_idx" as a unique "row number" (arbitrary)
	-- the taxon name is the key for the linkout
	-- the ictv_id is the ID they return to us
	select 
		max(left_idx), max(msl_release_num), t=
		'linkid:   '+ rtrim(max(taxnode_id)) + @newline -- need "rownum!"
		+ 'query:  '+name+' [name]' + @newline
		+ 'base:  &base;' + @newline
		+ 'rule:  '+ rtrim(max(taxnode_id)) + @newline
		+ 'name:  '+name + @newline
		+'---------------------------------------------------------------' 
	from taxonomy_node_names taxa
	where msl_release_num <= @msl -- latest MSL
	 -- skip internal nodes: virtual subfamilies, etc
	and is_deleted = 0 and is_hidden=0 and is_obsolete=0
	and name is not null and name <> 'Unassigned'
	group by name 

	*/

	-- ---------------------------------------------------------
	-- "Only CURRENT names"  version
	-- ---------------------------------------------------------
	-- This version provides a link only for names in the most
	-- recent MSL. 
	-- 
	-- This was created to deal with the weeks/months after a new MSL
	-- release when NCBI is still using the old taxonomy. 
	-- 
	-- HOWEVER, NCBI linkout has a bug where >1 link on a node (say, it's
	-- old and new names, after a rename) creates a disambiguation link that
	-- then errors out. 

	-- use "left_idx" as a unique "row number" (arbitrary)
	-- the taxon name is the key for the linkout
	-- the ictv_id is the ID they return to us
	--  declare @msl int; set @msl=40; declare @newline varchar(10); set @newline='|' -- DEBUG
	select 
		max(taxnode_id), 
		max(msl_release_num), 
		 t=
		'linkid:   '+ rtrim(max(taxnode_id )) + @newline -- need "rownum!"
		+ 'query:  '+name+' [name]' + @newline
		+ 'base:  &base;' + @newline
		+ 'rule:  '+ rtrim(max(ictv_id)) + 
			-- for taxa in the current MSL, add the taxon_name=[name] suffix
			--(case when max(msl_release_num) = @msl then '&taxon_name='+replace(name,' ','%20') else '' end) +
			 @newline
		+ 'name:  '+name + @newline
		+'---------------------------------------------------------------'
	--  declare @msl int; set @msl=40; declare @newline varchar(10); set @newline='|'; select msl=msl_release_num, taxnode_id, ictv_id, name  -- DEBUG 
	from taxonomy_node_names taxa
	where msl_release_num is not null -- latest MSL
	 -- skip internal nodes: virtual subfamilies, etc
	and is_deleted = 0 and is_hidden=0 and is_obsolete=0
	and name is not null and name <> 'Unassigned'
	-- debug
	-- and name in ('Avipoxvirus canarypox','Canarypox virus','Canary pox virus') -- debug
	--and ictv_id=202214169 -- renamed 39/40
	group by name 
	--order by max(msl_release_num)


) as src 
order by  src.left_idx


GO

