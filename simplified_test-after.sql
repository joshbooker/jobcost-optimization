/*  
 * Disclaimer!!! 
 * This is not a real query being executed, but a simplified version for general vision. 
 * Executing it with any other tool may produce a different result. 
 */
with [JobStatusBase] as 
(select  
	[JobHead].[Company] as [JobHead_Company], 
	[JobHead].[JobNum] as [JobHead_JobNum], 
	[JobAsmbl].[AssemblySeq] as [JobAsmbl_AssemblySeq], 
	[JobAsmbl].[JobComplete] as [JobAsmbl_JobComplete], 
	(((CASE 
		WHEN JobAsmbl.AssemblySeq = 0 THEN 1 
	ELSE 
		0 
	END))) as [Calculated_MtlIssued], 
	((CASE 
		WHEN JobHead.JobEngineered = 1 THEN 1 
	ELSE 
		0 
	END)) as [Calculated_BackFromHT], 
	((CASE 
		WHEN JobHead.JobReleased = 1 THEN 1 
	ELSE 
		0 
	END)) as [Calculated_InProcess], 
	((CASE 
		WHEN JobAsmbl.AssemblySeq > 0 THEN 1 
	ELSE 
		0 
	END)) as [Calculated_Farmout], 
	((CASE 
		WHEN JobHead.JobComplete = 1 THEN 1 
	ELSE 
		0 
	END)) as [Calculated_OVFinalOrBack], 
	((CASE 
		WHEN JobAsmbl.JobComplete = 0 THEN 1 
	ELSE 
		0 
	END)) as [Calculated_OVNotFinal], 
	((CASE 
		WHEN JobAsmbl.JobComplete = 1 THEN 1 
	ELSE 
		0 
	END)) as [Calculated_DetailComplete] 

from Erp.JobHead as [JobHead]
inner join Erp.JobAsmbl as [JobAsmbl] on 
	  JobHead.Company = JobAsmbl.Company
	and  JobHead.JobNum = JobAsmbl.JobNum
where ( (JobHead.JobClosed = 0  
and JobHead.JobFirm = 1 ) ))
 ,[JobStatusWithStatus] as 
(select  
	[StatusBase].[JobHead_Company] as [StatusBase_JobHead_Company], 
	[StatusBase].[JobHead_JobNum] as [StatusBase_JobHead_JobNum], 
	[StatusBase].[JobAsmbl_AssemblySeq] as [StatusBase_JobAsmbl_AssemblySeq], 
	[StatusBase].[JobAsmbl_JobComplete] as [StatusBase_JobAsmbl_JobComplete], 
	[StatusBase].[Calculated_MtlIssued] as [StatusBase_Calculated_MtlIssued], 
	[StatusBase].[Calculated_BackFromHT] as [StatusBase_Calculated_BackFromHT], 
	[StatusBase].[Calculated_InProcess] as [StatusBase_Calculated_InProcess], 
	[StatusBase].[Calculated_Farmout] as [StatusBase_Calculated_Farmout], 
	[StatusBase].[Calculated_OVFinalOrBack] as [StatusBase_Calculated_OVFinalOrBack], 
	[StatusBase].[Calculated_OVNotFinal] as [StatusBase_Calculated_OVNotFinal], 
	[StatusBase].[Calculated_DetailComplete] as [StatusBase_Calculated_DetailComplete], 
	(((CASE 
		WHEN StatusBase.Calculated_OVFinalOrBack = 1 THEN 6 
		WHEN StatusBase.Calculated_OVNotFinal = 1 THEN 5 
		WHEN StatusBase.Calculated_InProcess = 1 THEN 4 
		WHEN StatusBase.Calculated_Farmout = 1 THEN 3 
		WHEN StatusBase.Calculated_BackFromHT = 1 THEN 2 
		WHEN StatusBase.Calculated_MtlIssued = 1 THEN 1 
	ELSE 
		0 
	END))) as [Calculated_Status] 

from  JobStatusBase  as [StatusBase])
 ,[TopStatus] as 
(select  
	[WithStatus1].[StatusBase_JobHead_Company] as [WithStatus1_StatusBase_JobHead_Company], 
	[WithStatus1].[StatusBase_JobHead_JobNum] as [WithStatus1_StatusBase_JobHead_JobNum], 
	[WithStatus1].[Calculated_Status] as [Calculated_TopStatus] 

from  JobStatusWithStatus  as [WithStatus1]
where ( (WithStatus1.StatusBase_JobAsmbl_AssemblySeq = 0 ) ))
 ,[AsmStatus] as 
(select  
	[WithStatus2].[StatusBase_JobHead_JobNum] as [WithStatus2_StatusBase_JobHead_JobNum], 
	[WithStatus2].[Calculated_Status] as [WithStatus2_Calculated_Status] 

from  JobStatusWithStatus  as [WithStatus2]
where ( (WithStatus2.StatusBase_Calculated_DetailComplete = 0  
and WithStatus2.StatusBase_JobAsmbl_AssemblySeq <> 0 ) ))

select  
	[TopLevel].[WithStatus1_StatusBase_JobHead_Company] as [TopLevel_WithStatus1_StatusBase_JobHead_Company], 
	(((COALESCE(AsmLevel.WithStatus2_StatusBase_JobHead_JobNum, TopLevel.WithStatus1_StatusBase_JobHead_JobNum)))) as [Calculated_JobNum], 
	((CASE 
		WHEN TopLevel.Calculated_TopStatus = 0 THEN COALESCE(AsmLevel.WithStatus2_Calculated_Status, 0) 
		WHEN AsmLevel.WithStatus2_Calculated_Status < TopLevel.Calculated_TopStatus THEN AsmLevel.WithStatus2_Calculated_Status 
	ELSE 
		TopLevel.Calculated_TopStatus 
	END)) as [Calculated_Status] 

from  TopStatus  as [TopLevel]
left outer join  AsmStatus  as [AsmLevel] on 
	  TopLevel.WithStatus1_StatusBase_JobHead_JobNum = AsmLevel.WithStatus2_StatusBase_JobHead_JobNum