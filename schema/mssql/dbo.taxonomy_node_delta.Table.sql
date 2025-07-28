
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[taxonomy_node_delta](
	[prev_taxid] [int] NULL,
	[new_taxid] [int] NULL,
	[proposal] [varchar](255) NULL,
	[notes] [nvarchar](max) NULL,
	[is_merged] [int] NOT NULL,
	[is_split] [int] NOT NULL,
	[is_moved] [int] NOT NULL,
	[is_promoted] [int] NOT NULL,
	[is_demoted] [int] NOT NULL,
	[is_renamed] [int] NOT NULL,
	[is_new] [int] NOT NULL,
	[is_deleted] [int] NOT NULL,
	[is_now_type] [int] NOT NULL,
	[tag_csv]  AS ((((((((case when [is_merged]=(1) then 'Merged,' else '' end+case when [is_split]=(1) then 'Split,' else '' end)+case when [is_renamed]=(1) then 'Renamed,' else '' end)+case when [is_new]=(1) then 'New,' else '' end)+case when [is_deleted]=(1) then 'Abolished,' else '' end)+case when [is_moved]=(1) then 'Moved,' else '' end)+case when [is_promoted]=(1) then 'Promoted,' else '' end)+case when [is_demoted]=(1) then 'Demoted,' else '' end)+case when [is_now_type]=(1) then 'Assigned as Type Species,' when [is_now_type]=(-1) then 'Removed as Type Species,' else '' end),
	[is_lineage_updated] [int] NOT NULL,
	[msl] [int] NOT NULL,
	[tag_csv2]  AS (((((((((case when [is_merged]=(1) then 'Merged,' else '' end+case when [is_split]=(1) then 'Split,' else '' end)+case when [is_renamed]=(1) then 'Renamed,' else '' end)+case when [is_new]=(1) then 'New,' else '' end)+case when [is_deleted]=(1) then 'Abolished,' else '' end)+case when [is_moved]=(1) then 'Moved,' else '' end)+case when [is_promoted]=(1) then 'Promoted,' else '' end)+case when [is_demoted]=(1) then 'Demoted,' else '' end)+case when [is_now_type]=(1) then 'Assigned as Type Species,' when [is_now_type]=(-1) then 'Removed as Type Species,' else '' end)+case when [is_lineage_updated]=(1) then 'LineageUpdated,' else '' end) PERSISTED NOT NULL,
	[tag_csv_min]  AS (((((((case when [is_merged]=(1) then 'Merged,' else '' end+case when [is_split]=(1) then 'Split,' else '' end)+case when [is_renamed]=(1) then 'Renamed,' else '' end)+case when [is_new]=(1) then 'New,' else '' end)+case when [is_deleted]=(1) then 'Abolished,' else '' end)+case when [is_moved]=(1) then 'Moved,' else '' end)+case when [is_promoted]=(1) then 'Promoted,' else '' end)+case when [is_demoted]=(1) then 'Demoted,' else '' end) PERSISTED NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_prev_taxid]  DEFAULT (NULL) FOR [prev_taxid]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_new_taxid]  DEFAULT (NULL) FOR [new_taxid]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_proposal]  DEFAULT (NULL) FOR [proposal]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_merged]  DEFAULT ((0)) FOR [is_merged]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_split]  DEFAULT ((0)) FOR [is_split]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_moved]  DEFAULT ((0)) FOR [is_moved]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_promoted]  DEFAULT ((0)) FOR [is_promoted]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_demoted]  DEFAULT ((0)) FOR [is_demoted]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_renamed]  DEFAULT ((0)) FOR [is_renamed]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_new]  DEFAULT ((0)) FOR [is_new]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_deleted]  DEFAULT ((0)) FOR [is_deleted]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_now_type]  DEFAULT ((0)) FOR [is_now_type]
GO

ALTER TABLE [dbo].[taxonomy_node_delta] ADD  CONSTRAINT [DF_taxonomy_node_delta_is_lineage_updated]  DEFAULT ((0)) FOR [is_lineage_updated]
GO

ALTER TABLE [dbo].[taxonomy_node_delta]  WITH CHECK ADD  CONSTRAINT [CK_taxonomy_node_delta-is_deleted] CHECK  (([is_deleted]=(1) OR [is_deleted]=(0)))
GO

ALTER TABLE [dbo].[taxonomy_node_delta] CHECK CONSTRAINT [CK_taxonomy_node_delta-is_deleted]
GO

ALTER TABLE [dbo].[taxonomy_node_delta]  WITH CHECK ADD  CONSTRAINT [CK_taxonomy_node_delta-is_merged] CHECK  (([is_merged]=(1) OR [is_merged]=(0)))
GO

ALTER TABLE [dbo].[taxonomy_node_delta] CHECK CONSTRAINT [CK_taxonomy_node_delta-is_merged]
GO

ALTER TABLE [dbo].[taxonomy_node_delta]  WITH CHECK ADD  CONSTRAINT [CK_taxonomy_node_delta-is_moved] CHECK  (([is_moved]=(1) OR [is_moved]=(0)))
GO

ALTER TABLE [dbo].[taxonomy_node_delta] CHECK CONSTRAINT [CK_taxonomy_node_delta-is_moved]
GO

ALTER TABLE [dbo].[taxonomy_node_delta]  WITH CHECK ADD  CONSTRAINT [CK_taxonomy_node_delta-is_new] CHECK  (([is_new]=(1) OR [is_new]=(0)))
GO

ALTER TABLE [dbo].[taxonomy_node_delta] CHECK CONSTRAINT [CK_taxonomy_node_delta-is_new]
GO

ALTER TABLE [dbo].[taxonomy_node_delta]  WITH CHECK ADD  CONSTRAINT [CK_taxonomy_node_delta-is_now_type] CHECK  (([is_now_type]=(1) OR [is_now_type]=(0) OR [is_now_type]=(-1)))
GO

ALTER TABLE [dbo].[taxonomy_node_delta] CHECK CONSTRAINT [CK_taxonomy_node_delta-is_now_type]
GO

ALTER TABLE [dbo].[taxonomy_node_delta]  WITH CHECK ADD  CONSTRAINT [CK_taxonomy_node_delta-is_renamed] CHECK  (([is_renamed]=(1) OR [is_renamed]=(0)))
GO

ALTER TABLE [dbo].[taxonomy_node_delta] CHECK CONSTRAINT [CK_taxonomy_node_delta-is_renamed]
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_merged'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean: if true, taxa is one of several that was split from a single taxnode in the previous year' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_split'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean: 0 or 1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_moved'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean; taxa name re-used at higher level, such as promoting a species to a genus' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_promoted'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean: 0 or 1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_renamed'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean: 0 or 1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_new'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean: 0 or 1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_deleted'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'tri-value: -1, 0, 1: -1 = nolonger a type species; 1 = has become a type species' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'COLUMN',@level2name=N'is_now_type'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Links taxnode_ids between years, describing their changes. This data is generated by a query.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'CONSTRAINT',@level2name=N'CK_taxonomy_node_delta-is_deleted'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'CONSTRAINT',@level2name=N'CK_taxonomy_node_delta-is_merged'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'CONSTRAINT',@level2name=N'CK_taxonomy_node_delta-is_moved'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'CONSTRAINT',@level2name=N'CK_taxonomy_node_delta-is_new'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'tri-value (-1,0,1)' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'CONSTRAINT',@level2name=N'CK_taxonomy_node_delta-is_now_type'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'boolean' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'taxonomy_node_delta', @level2type=N'CONSTRAINT',@level2name=N'CK_taxonomy_node_delta-is_renamed'
GO

