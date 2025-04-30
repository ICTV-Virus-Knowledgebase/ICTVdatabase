Protocol

1. Export linkout text from database, for most recent MSL (NULL)
    EXEC [NCBI_linkout_ft_export] NULL, '|'

2. right click on grid, "save results as" TXT
    # download to
    ncbi_msl37_linkout.ft.txt
    # convert 
    sed -e 's/|/\n/g;' ncbi_msl37_linkout.ft.txt ncbi_msl37_linkout.ft.txt
    # check encoding
    file *.ft
    # ictv_2015_ncbi_linkout.unix.ft: UTF-8 Unicode text
3. cmd-line "ftp ftp-private.ncbi.nlm.nih.gov"
4. login as "ictv" password ######### (see Keeper: "ICTV VIrus Knowledgebase/NCBI linkout for ICTV")
        user ictv ######
	cd holdings
	put ictv_2015_ncbi_linkout.ft ictv.ft
	quit
6. done.


------------------------------------------------------------------------------------------------------
2011 new taxa: http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=292029&lvl=3&lin=f&keep=1&srchmode=1&unlock
2011 old taxa: http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=28883&lvl=3&lin=f&keep=1&srchmode=1&unlock
------------------------------------------------------------------------------------------------------
From: Scott Federhen, NCBI [federhen@ncbi.nlm.nih.gov]
CC: LinkOut team/NCBI/NLM [mailto:linkout@ncbi.nlm.nih.gov] 
Sent: October 6, 2010 

Host:  ftp-private.ncbi.nlm.nih.gov
Username: ictv
Password: ##########

The user name and password are case sensitive. LinkOut files are placed in the “holdings” directory.



=======================================================================================================
MSL30/2015 QC
=======================================================================================================

Elliot

I generated the latest 2015 linkout file and uploaded it NCBI, per notes in “20160630_NCBI_linkout”
It seems to have gone live to their production server in < 20 minutes. 
Note – the last linkout update was 2011 ;-(

One “feature” is that taxa we have abolished, renamed or merged, but which still appear in NCBI, loose their links. 
We are capable of generating links for them, but have chosen not to. We could link them either to their updated versions, or to their obsolete versions. 
Thoughts? 

Regards 
Curtis

EXAMPLES
NEW 
2012	Acidianus spindle-shaped virus 1
	Now correctly linked: http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=693629
	To http://www.ictvonline.org/virusTaxonomy.asp?src=NCBI&ictv_id=20125931

REMOVED
2013 	Adeno-associated virus – 3 [>>MERGEd>>] Adeno-associated dependoparvovirus A
	OLD NAME no longer linked (NCBI: no rank; shown as a subtaxa of new name)
http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=46350&lvl=3&lin=f&keep=1&srchmode=1&unlock
	NEW NAME correctly linked (NCBI: species)
		http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=1511891&lvl=3&lin=f&keep=1&srchmode=1&unlock 
		to http://www.ictvonline.org/virusTaxonomy.asp?src=NCBI&ictv_id=20132583
	TAXON HISTORY @ ICTV
	http://www.ictvonline.org/taxonomyHistory.asp?taxnode_id=20124277&taxa_name=Adeno-associated%20virus-3

=======================================================================================================
MSL30/2015 QC
=======================================================================================================
