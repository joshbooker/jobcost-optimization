with [LaborSummary] as 
(select  
	[LaborDtl].[Company] as [LaborDtl_Company], 
	[LaborDtl].[JobNum] as [LaborDtl_JobNum], 
	[LaborDtl].[AssemblySeq] as [LaborDtl_AssemblySeq], 
	(SUM(LaborHrs)) as [TotalLaborHrs], 
	(SUM(LaborQty)) as [TotalLaborQty] 

from Erp.LaborDtl as [LaborDtl]
group by 
	[LaborDtl].[Company], 
	[LaborDtl].[JobNum], 
	[LaborDtl].[AssemblySeq])
 ,[LastOVOperations] as 
(select  
	[ja].[AssemblySeq] as [ja_AssemblySeq], 
	[ja].[JobNum] as [ja_JobNum], 
	[ja].[Company] as [ja_Company], 
	(MAX(OprSeq)) as [LastOVOp] 

from Erp.JobHead as [jh]
inner join Erp.JobAsmbl as [ja] on 
	  jh.Company = ja.Company
	and  jh.JobNum = ja.JobNum
inner join Erp.JobOper as [jo] on 
	  ja.Company = jo.Company
	and  ja.JobNum = jo.JobNum
	and  ja.AssemblySeq = jo.AssemblySeq
where ( jo.SubContract = 1  
and not jo.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
group by 
	[ja].[AssemblySeq], 
	[ja].[JobNum], 
	[ja].[Company])

select  
	[LS].[LaborDtl_Company] as [LaborDtl_Company], 
	[LS].[LaborDtl_JobNum] as [LaborDtl_JobNum], 
	[LS].[LaborDtl_AssemblySeq] as [LaborDtl_AssemblySeq], 
	[LS].[TotalLaborHrs] as [TotalLaborHrs], 
	[LS].[TotalLaborQty] as [TotalLaborQty], 
	[LO].[ja_AssemblySeq] as [ja_AssemblySeq], 
	[LO].[ja_JobNum] as [ja_JobNum], 
	[LO].[ja_Company] as [ja_Company], 
	[LO].[LastOVOp] as [LastOVOp] 

from  LaborSummary  as [LS]
right outer join  LastOVOperations  as [LO] on 
	  LS.LaborDtl_Company = LO.ja_Company
	and  LS.LaborDtl_JobNum = LO.ja_JobNum
	and  LS.LaborDtl_AssemblySeq = LO.ja_AssemblySeq