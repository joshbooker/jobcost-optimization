NOTE.md
Curious, I asked Claude who came up with [some solid recommendations](https://github.com/joshbooker/jobcost-optimization/blob/main/JobStatus_Optimization_Analysis.md).  The resulting SQL wouldn't import successfully using SQL to BAQ but may not be too far off.  Most likely, has to do with Table_Field aliases are off in [this 'optimized' sql](https://github.com/joshbooker/jobcost-optimization/blob/main/baq_JobCost_optimized.sql).  

(Note: I'm cloud w no db so this query isn't tested)

My next step would be to lookup the correlation id in the server logs to see if it's a simple fix to get it to import.

Either that or redo JobCost in BAQ Designer from ground up using CTEs and some of the suggestions.

Think:  each CTE is a resultset of it's own, use them when you're doing a grouping/joins that you only wanna do once and use later maybe more than once. like your TopStatus and AsmStatus you want all metrics for all assemblies, then you want either top or asms in your fallback.  Do all the work once, then breakout twice for your fallback at the end.

For exmaple, here's a small test (that does import via SQL-to-BAQ)

```sql
with [LaborSummary] as 
(select  
	[LaborDtl].[Company] as [LaborDtl_Company], 
	[LaborDtl].[JobNum] as [LaborDtl_JobNum], 
	[LaborDtl].[AssemblySeq] as [LaborDtl_AssemblySeq], 
	(((SUM(LaborHrs)))) as [TotalLaborHrs], 
	((SUM(LaborQty))) as [TotalLaborQty] 

from Erp.LaborDtl as [LaborDtl]
group by 
	[LaborDtl].[Company], 
	[LaborDtl].[JobNum], 
	[LaborDtl].[AssemblySeq]),
[LastOVOperations] as 
(select  
	[ja].[AssemblySeq] as [ja_AssemblySeq], 
	[ja].[JobNum] as [ja_JobNum], 
	[ja].[Company] as [ja_Company], 
	(((MAX(OprSeq)))) as [LastOVOp] 

from Erp.JobHead as [jh]
inner join Erp.JobAsmbl as [ja] on 
	  jh.Company = ja.Company
	and  jh.JobNum = ja.JobNum
inner join Erp.JobOper as [jo] on 
	  ja.Company = jo.Company
	and  ja.JobNum = jo.JobNum
	and  ja.AssemblySeq = jo.AssemblySeq
where ( (jo.SubContract = 1  
and not jo.OpCode IN ('OMC-OVOP', 'OMP-OVOP') ) )
group by 
	[ja].[AssemblySeq], 
	[ja].[JobNum], 
	[ja].[Company])

select  
	[LO].[ja_AssemblySeq] as [ja_AssemblySeq], 
	[LO].[ja_JobNum] as [ja_JobNum], 
	[LO].[ja_Company] as [ja_Company], 
	[LO].[LastOVOp] as [LastOVOp], 
	[LS].[TotalLaborHrs] as [TotalLaborHrs], 
	[LS].[TotalLaborQty] as [TotalLaborQty] 

from  LaborSummary  as [LS]
right outer join  LastOVOperations  as [LO] on 
	  LS.LaborDtl_Company = LO.ja_Company
	and  LS.LaborDtl_JobNum = LO.ja_JobNum
	and  LS.LaborDtl_AssemblySeq = LO.ja_Company
```
