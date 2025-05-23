
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE --  CREATE
	procedure [dbo].[species_isolates_update_sorts] as
begin
	print 'updating [species_isolates_update_sorts].[species_sort] and [isolate_sort]'
	DECLARE @species_name nvarchar(200)

	DECLARE @species_sort int; DECLARE @cur_species nvarchar(200)
	DECLARE @isolate_sort int

	DECLARE @isolate_id int

	DECLARE @mesg nvarchar(4000)

	SET NOCOUNT ON 
	-- CURSOR
	DECLARE [SPECIES_ISOLATE_ROWS] SCROLL CURSOR FOR 
		select vmr.isolate_id, vmr.species_name 
		--select * 
		from species_isolates_alpha_num1_num2 vmr
		join taxonomy_node tn  on tn.taxnode_id = vmr.taxnode_id
		order by
			-- sort by species taxonomy 
			tn.left_idx 
			-- then E records before A
			, isolate_type DESC  
			-- then by isolate name
			, _isolate_name_alpha, _isolate_name_num1, _isolate_name_num2


	SET @species_sort = 0
	SET @isolate_sort = 1
	SET @cur_species = ''
	OPEN [SPECIES_ISOLATE_ROWS]
	FETCH NEXT FROM [SPECIES_ISOLATE_ROWS] INTO @isolate_id,  @species_name
	WHILE @@FETCH_STATUS = 0 BEGIN
  		-- DO WORK HERE
		IF @cur_species <> @species_name BEGIN
			-- new species: reset isolate sort, incr species sort
			SET @species_sort = @species_sort +1
			SET @isolate_sort = 1
			SET @cur_species = @species_name
		END ELSE BEGIN
			-- same species, new isolate: incr isolate sort only
			SET @isolate_sort = @isolate_sort + 1
		END

		-- update sort fields in VMR
		UPDATE [species_isolates] SET
			[species_sort] = @species_sort,
			[isolate_sort] = @isolate_sort
		WHERE isolate_id = @isolate_id

		SET @mesg = 'UPDATE [species_isolates] SET species_sort='+rtrim(@species_sort)+', isolate_sort='+rtrim(@isolate_sort)+' where isolate_id='+rtrim(@isolate_id)
		--RAISERROR (@mesg, 1, 1)
		print @mesg
   		-- NEXT
		FETCH NEXT FROM [SPECIES_ISOLATE_ROWS] INTO @isolate_id,  @species_name
	END; CLOSE [SPECIES_ISOLATE_ROWS]; DEALLOCATE [SPECIES_ISOLATE_ROWS]

end
/*
--
-- test
--

exec [species_isolates_update_sorts]


select * from [species_isolates] order by species_sort, isolate_sort


select * from [species_isolates] where isolate_sort > 1 order by species_sort, isolate_sort


select * from [species_isolates]
 where species_name in (select species_name from [species_isolates] where [species_isolates].[isolate_sort] > 1 and species_name <>'abolished')
 order by species_sort, isolate_sort


select * from species_isolates_alpha_num1_num2 vmr
where _isolate_name_num1 is not null and _isolate_name_num2 is not null order by species_sort, isolate_sort

*/

GO

