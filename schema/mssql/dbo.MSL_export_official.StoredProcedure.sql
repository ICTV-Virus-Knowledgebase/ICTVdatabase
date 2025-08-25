
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE procedure [dbo].[MSL_export_official]
	@msl_or_tree int = NULL,
	@taxnode_id int = NULL,
	@server varchar(200) = 'ictv.global'
as
-- DEBUG - uncomment to replace procedure definition for testing.
--declare @msl_or_tree int; set @msl_or_tree=38 /*170000*/ ; declare @taxnode_id int; set @taxnode_id = 202201547 -- DEBUG
 -- -------------------------------------------------------------------------
-- EXPORT FULL OFFICIAL MSL *with* extended fields for inclusion in MSL
-- 		ncbi, isoalte, molecule, last_change, last_change_msl, history_url
-- NON-included extended fields:
--		FYI_molecule_type
-- TEST:
--     exec [MSL_export_official_test] 38, 202201547, 'test.ictv.global'
--     exec [MSL_export_official_test] NULL, NULL, 'test.ictv.global'
-- -------------------------------------------------------------------------
-- Run time 
--	~ 15 minutes (full)
-- -------------------------------------------------------------------------
-- 20250228 Start switch to ICTV#### for ictv_id
-- 20230504 MSL38 add URL for proposal zip filename
-- 20210510 MSL36 remove is_ref, remove column giving rank where molecule_id is set
-- 20181018 changed from msl_release_num based joins to tree_id for better index usage
--          time 70min >> 14 min
-- -------------------------------------------------------------------------

--
-- create ICTV MSL (extended) from taxonomy_node
declare @msl int
declare @tree_id int
select  @tree_id=tree_id, @msl=msl_release_num 
from taxonomy_toc 
where  @msl_or_tree is null  or msl_release_num = @msl_or_tree or tree_id =  @msl_or_tree 
order by msl_release_num

select 'TARGET MSL: '=@msl, 'TARGET TREE:'=@tree_id
print 'TARGET MSL:'+rtrim(@msl)

select 
	PASTE_TEXT_FOR_VERSION_WORKSHEET ='version info:'
	, 'ICTV '+LEFT(rtrim(tree_id),4)+' Master Species List (MSL'+RTRIM(msl_release_num)+')' as cell_2B
	, 'update today''s date!' as cell_5C
	, 'New MSL including all taxa updates since the '+(select name from taxonomy_node where level_id=100 and msl_release_num=(@msl-1))+' release' as cell_6E
	, 'Updates approved during '+ cast(notes as varchar(max)) as cell_7F
	, 'and ratified by the ICTV membership in '+LEFT(rtrim(tree_id+10000),4) as cell_8F
	, 'ICTV'+LEFT(rtrim(tree_id),4)+' Master Species List#'+RTRIM(msl_release_num)+'' as taxa_tab_name
from taxonomy_node
where level_id = 100 
and msl_release_num = @msl

select REPORT='molecule stats',  *, 
	usage=(select count(n.taxnode_id) from taxonomy_node n where n.inher_molecule_id=m.id and n.tree_id=@tree_id)
from taxonomy_molecule m
order by id


select REPORT='rank stats',  *, 
	usage=(select count(n.taxnode_id) from taxonomy_node n where n.level_id=l.id and n.tree_id=@tree_id)
from taxonomy_level l
order by id

select
	-- basic MSL - one line per species
	--TN.msl_release_num, -- debugging
	[sort]          = ROW_NUMBER() OVER(ORDER BY tn.left_idx ASC)
	,[realm]         = isnull([realm].name,'')
	,[subrealm]     = isnull([subrealm].name,'')
	,[kingdom]      = isnull([kingdom].name,'')
	,[subkingdom]   = isnull([subkingdom].name,'')
	,[phylum]       = isnull([phylum].name,'')
	,[subphylum]    = isnull([subphylum].name,'')
	,[class]        = isnull([class].name,'')
	,[subclass]     = isnull([subclass].name,'')
	,[order]        = isnull([order].name,'')
	,[suborder]     = isnull([suborder].name,'')
	,[family]       = isnull([family].name,'')
	,[subfamily]    = isnull([subfamily].name,'')
	,[genus]        = isnull([genus].name,'')
	,[subgenus]     = isnull([subgenus].name,'')
	,[species]      = isnull([species].name,'')
	-- ICTV_id (details URL) for that species
	, history_url = '=HYPERLINK("https://'+@server+'/taxonomy/taxondetails?taxnode_id='+rtrim(tn.taxnode_id)+'&ictv_id=ICTV'+rtrim(tn.ictv_id)+'","ICTV'+rtrim(tn.ictv_id)+'")'

	-- add info on most recent change to that taxon
	--,tn.taxnode_id, tn.ictv_id, 
	-- select msl_release_num, ictV_id, name, abbrev from taxonomy_node where abbrev is not null
	/* == MSL32 - move isolate and accession info to tables [virus_isolates]
	,last_ncbi=isnull((
		-- most recent change tag of node or ancestor 
		select top(1) t.genbank_accession_csv
		from taxonomy_node_merge_split tms
		join taxonomy_node t on 
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.msl_release_num <= tn.msl_release_num
		where tms.next_ictv_id = tn.ictv_id
		and t.genbank_accession_csv is not null
		order by tn.msl_release_num-t.msl_release_num, abs(tn.left_idx - t.left_idx)
	),'')
	,last_isolates=isnull((
		-- most recent change tag of node or ancestor 
		-- select top(1) rtrim(t.taxnode_id)+','+t.name+','+cast(t.isolate_csv as varchar(max)) -- debug
		select top(1) t.isolate_csv 
		from taxonomy_node_merge_split tms
--		join taxonomy_node_n t on -- get isolates with full Unicode names!
		join taxonomy_node t on -- until move to nvarchar/ntext, some isolates will be missing diacriticals
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.msl_release_num <= tn.msl_release_num
		where tms.next_ictv_id = tn.ictv_id
		and t.isolate_csv is not null
		order by tn.msl_release_num-t.msl_release_num, abs(tn.left_idx - t.left_idx)
	),'')
	== */
	-- add info on most recent molecule type designation to that taxon (or it's ancestors)
	,molecule=isnull((
		-- most recent change tag of node or ancestor 
		select top(1) mol.abbrev
		from taxonomy_node_merge_split tms
		join taxonomy_node t on 
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.tree_id <= tn.tree_id
		join taxonomy_node tancestor on
			-- look at ancestors w/in each historic MSL
			tancestor.left_idx <= t.left_idx and tancestor.right_idx >= t.right_idx 
			and tancestor.tree_id = t.tree_id and tancestor.level_id > 100 
		join taxonomy_molecule mol on mol.id = tancestor.inher_molecule_id
		where tms.next_ictv_id = tn.ictv_id
		and mol.abbrev is not null
		order by tn.tree_id-tancestor.tree_id, tancestor.node_depth desc
	),'')
	-- DEBUG - where did molecule data come from
	/*
	, moleculeRank=isnull((
		-- we could push this into the trigger...
		(select top 1 rank from taxonomy_node_names tns where tns.tree_id = tn.tree_id and tn.left_idx between tns.left_idx and tns.right_idx and tns.molecule_id = tn.inher_molecule_id order by tns.node_depth desc)
	),'')
	,molecule_src=isnull((
		-- most recent change tag of node or ancestor 
		select top(1) rtrim(tancestor.msl_release_num)+':'+tancestor.lineage -- mol.abbrev
		from taxonomy_node_merge_split tms
		join taxonomy_node t on 
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.msl_release_num <= tn.msl_release_num
		join taxonomy_node tancestor on
			-- look at ancestors w/in each historic MSL
			tancestor.left_idx <= t.left_idx and tancestor.right_idx >= t.right_idx 
			and tancestor.tree_id = t.tree_id and tancestor.level_id > 100 
		join taxonomy_molecule mol on mol.id = tancestor.inher_molecule_id
		where tms.next_ictv_id = tn.ictv_id
		and mol.abbrev is not null
		order by tn.msl_release_num-tancestor.msl_release_num, tancestor.node_depth desc
	),'')
	*/
	-- add info on most recent change to that taxon (or it's ancestors)
	, last_change=(
		select top(1) dx.prev_tags 
		from taxonomy_node_merge_split tms
		join taxonomy_node t on 
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.tree_id <= tn.tree_id
		join taxonomy_node_dx dx on
			-- look at ancestors w/in each historic MSL
			dx.left_idx <= t.left_idx and dx.right_idx >= t.right_idx 
			and dx.tree_id = t.tree_id and dx.level_id > 100 
			and dx.prev_tags is not null and dx.prev_tags <> ''
		where tms.next_ictv_id = tn.ictv_id
		order by tn.tree_id-dx.tree_id, dx.node_depth desc
	)
	, last_change_msl=(
		-- MSL of most recent change tag of node or ancestor 
		select top(1) dx.msl_release_num 
		from taxonomy_node_merge_split tms
		join taxonomy_node t on 
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.tree_id <= tn.tree_id
		join taxonomy_node_dx dx on
			-- look at ancestors w/in each historic MSL
			dx.left_idx <= t.left_idx and dx.right_idx >= t.right_idx 
			and dx.tree_id = t.tree_id and dx.level_id > 100 
			and dx.prev_tags is not null and dx.prev_tags <> ''
		where tms.next_ictv_id = tn.ictv_id
		order by tn.tree_id-dx.tree_id, dx.node_depth desc
	)
	, last_change_proposal=isnull((
		-- PROPOSAL of most recent change tag of node or ancestor WITH PROPOSAL
		select top(1) 
			prev_proposal = (case
				when dx.prev_proposal is null then ''
				when dx.prev_proposal not like '%;%' then '=HYPERLINK("https://'+@server+'/ictv/proposals/'+dx.prev_proposal+'","'+dx.prev_proposal+'")'
				-- if three proposals use the last (most recent) one (Excel only allows one link per cell)
				when dx.prev_proposal     like '%;%;%' then '=HYPERLINK("https://'+@server+'/ictv/proposals/'+substring(dx.prev_proposal,charindex(';',dx.prev_proposal,charindex(';',dx.prev_proposal)+1)+1,1000)+'","'+substring(dx.prev_proposal,charindex(';',dx.prev_proposal,charindex(';',dx.prev_proposal)+1)+1,1000)+'")'
				-- if two proposals use the last (most recent) one (Excel only allows one link per cell)
				when dx.prev_proposal     like '%;%' then '=HYPERLINK("https://'+@server+'/ictv/proposals/'+substring(dx.prev_proposal,charindex(';',dx.prev_proposal)+1,1000)+'","'+substring(dx.prev_proposal,charindex(';',dx.prev_proposal)+1,1000)+'")'
				end)
		from taxonomy_node_merge_split tms
		join taxonomy_node t on 
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.tree_id <= tn.tree_id
		join taxonomy_node_dx dx on
			-- look at ancestors w/in each historic MSL
			dx.left_idx <= t.left_idx and dx.right_idx >= t.right_idx 
			and dx.tree_id = t.tree_id and dx.level_id > 100 
			and dx.prev_tags is not null and dx.prev_tags <> ''
		where tms.next_ictv_id = tn.ictv_id
		and dx.prev_proposal is not null and dx.prev_proposal <> ''
		and dx.tree_id = (
			-- limit to same MSL (but not same ancestory) as last change TAG
			select top(1) dx.tree_id 
			from taxonomy_node_merge_split tms
			join taxonomy_node t on 
				-- historic across merge/splits
				t.ictv_id=tms.prev_ictv_id
				 and t.tree_id <= tn.tree_id
			join taxonomy_node_dx dx on
				-- look at ancestors w/in each historic MSL
				dx.left_idx <= t.left_idx and dx.right_idx >= t.right_idx 
				and dx.tree_id = t.tree_id and dx.level_id > 100 
				and dx.prev_tags is not null and dx.prev_tags <> ''
			where tms.next_ictv_id = tn.ictv_id
			order by tn.tree_id-dx.tree_id, dx.node_depth desc
		)
		order by tn.tree_id-dx.tree_id, dx.node_depth desc	
	),'')
	-- these columns are not currently released in the official MSL
	-- ICTV does not OFFICIALLY track abbreviations 
	/*, FYI_last_abbrev=isnull((
		-- most recent change tag of node or ancestor 
		select top(1) tancestor.abbrev_csv
		from taxonomy_node_merge_split tms
		join taxonomy_node t on 
			-- historic across merge/splits
			t.ictv_id=tms.prev_ictv_id
			 and t.msl_release_num <= tn.msl_release_num
		join taxonomy_node tancestor on
			-- look at ancestors w/in each historic MSL
			tancestor.left_idx <= t.left_idx and tancestor.right_idx >= t.right_idx 
			and tancestor.tree_id = t.tree_id and tancestor.level_id > 100 
		where tms.next_ictv_id = tn.ictv_id
		and tancestor.abbrev_csv is not null
		order by tn.msl_release_num-tancestor.msl_release_num, tancestor.node_depth desc
	),'')
	*/
from taxonomy_node tn
left outer join taxonomy_node [tree] on [tree].taxnode_id=tn.tree_id
left outer join taxonomy_node [realm] on [realm].taxnode_id=tn.realm_id
left outer join taxonomy_node [subrealm] on [subrealm].taxnode_id=tn.subrealm_id
left outer join taxonomy_node [kingdom] on [kingdom].taxnode_id=tn.kingdom_id
left outer join taxonomy_node [subkingdom] on [subkingdom].taxnode_id=tn.subkingdom_id
left outer join taxonomy_node [phylum] on [phylum].taxnode_id=tn.phylum_id
left outer join taxonomy_node [subphylum] on [subphylum].taxnode_id=tn.subphylum_id
left outer join taxonomy_node [class] on [class].taxnode_id=tn.class_id
left outer join taxonomy_node [subclass] on [subclass].taxnode_id=tn.subclass_id
left outer join taxonomy_node [order] on [order].taxnode_id=tn.order_id
left outer join taxonomy_node [suborder] on [suborder].taxnode_id=tn.suborder_id
left outer join taxonomy_node [family] on [family].taxnode_id=tn.family_id
left outer join taxonomy_node [subfamily] on [subfamily].taxnode_id=tn.subfamily_id
left outer join taxonomy_node [genus] on [genus].taxnode_id=tn.genus_id
left outer join taxonomy_node [subgenus] on [subgenus].taxnode_id=tn.subgenus_id
left outer join taxonomy_node [species] on [species].taxnode_id=tn.species_id
where tn.is_deleted = 0 and tn.is_hidden = 0 and tn.is_obsolete=0
and tn.tree_id = @tree_id
and tn.level_id = 600 /* species */
-- limit to a specific taxon, if specified
and (@taxnode_id is NULL or tn.taxnode_id = @taxnode_id)
--===  debugging taxa ===
--and tn.name like '%ebolavirus'
--and tn.ictv_id=19710324 -- Tobacco necrosis virus A
--dx.ictv_id=19981390 -- 'East African cassava mosaic virus'
--t.ictv_id=19951067 -- Pongine herpesvirus 2
-- and tn.name='Pongine herpesvirus 2'
--and tn.name ='Enterobacteria phage Mu' -- test for abbreviation from MSL18
/*-- TEST MSL33 new taxa
and tn.name in (
	'Alphaarterivirus equid'  -- moved, renamed
	,'Betaarterivirus ninrav' -- new
)*/
/*-- TEST MSL29/MSL28 export problems
and tn.name in (
	'Schefflera ringspot virus'
	,'Gooseberry vein banding associated virus'
	,'Spirea yellow leafspot virus'
	,'Chrysochromulina brevifilum virus PW1'
	,'Pagoda yellow mosaic associated virus'
	,'Haloarcula hispanica icosahedral virus 2' -- molecule problem
	, 'Blueberry latent virus' -- MSL28: missing molecule
)*/
--and tn.name like 'Melanoplus sanguinipes entomopoxvirus%'
order by tn.left_idx -- must match ROW_NUMBER() OVER()


-- 
-- debugging
--
/*
-- Tobacco necrosis virus A
select ictv_id, msl_release_num, name from taxonomy_node where msl_release_num = 29 and name ='Tobacco necrosis virus A'
select ictv_id, msl_release_num, name from taxonomy_node where msl_release_num = 29 and name='East African cassava mosaic virus'
select ictv_id, msl_release_num, name from taxonomy_node where msl_release_num = 29 and name='Pongine herpesvirus 2'

select 
	top(1) -- select
	dx.msl_release_num, dx.prev_tags, dx.prev_proposal, dx.level_id , dx.lineage
from taxonomy_node_dx dx 
join taxonomy_node t on dx.left_idx < t.left_idx and dx.right_idx > t.right_idx and dx.tree_id = t.tree_id and dx.level_id > 100 
where 
--dx.ictv_id=19710324 -- 'Tobacco necrosis virus A'
--dx.ictv_id=19981390 -- 'East African cassava mosaic virus'
--t.ictv_id=19951067 -- Pongine herpesvirus 2
t.taxnode_id=20081030 -- Lymphocryptovirus
and dx.prev_tags is not null and dx.prev_tags <> '' 
order by 29-dx.msl_release_num, dx.node_depth

-- data problems exposed
Cetacean morbillivirus - no deltas, ever
Human metapneumovirus  - no deltas, ever
Euphorbia leaf curl virus
Dolichos yellow mosaic virus
*/

/*
-- ******************************************
-- don't need to do this (for MSL export) 
-- now inherit across MSLs
-- ******************************************

--
-- push molcule_id annotation forward 1 MSL
-- !!!!! SLOW because of inheritance trigger: !!!!! --
update taxonomy_node set 
--select targ.msl_release_num, targ.molecule_id , src.next_tags, 
	molecule_id = src.molecule_id
from taxonomy_node targ
join taxonomy_node_dx src on src.next_id=targ.taxnode_id
and src.molecule_id is not null
and targ.molecule_id is null

-- 
-- push molecule_id annotation BACKWARD 1 MSL
--
update taxonomy_node set 
--select targ.msl_release_num, targ.molecule_id , src.next_tags, 
	molecule_id = src.molecule_id
from taxonomy_node targ
join taxonomy_node_dx src on src.prev_id=targ.taxnode_id
and src.molecule_id is not null
and targ.molecule_id is null
*/

/* 
-- TEST
exec MSL_export_official
*/
GO

