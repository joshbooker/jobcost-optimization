/*  
 * Disclaimer!!! 
 * This is not a real query being executed, but a simplified version for general vision. 
 * Executing it with any other tool may produce a different result. 
 */
with [LaborSummary] as 
(select  
	[LaborDtl].[Company] as [LaborDtl_Company], 
	[LaborDtl].[JobNum] as [LaborDtl_JobNum], 
	[LaborDtl].[AssemblySeq] as [LaborDtl_AssemblySeq], 
	(SUM(LaborDtl.LaborHrs)) as [Calculated_TotalLaborHrs], 
	(SUM(LaborDtl.LaborQty)) as [Calculated_TotalLaborQty] 

from Erp.LaborDtl as [LaborDtl]
group by 
	[LaborDtl].[Company], 
	[LaborDtl].[JobNum], 
	[LaborDtl].[AssemblySeq])
 ,[LastOVOperations] as 
(select  
	[JobHead].[Company] as [JobHead_Company], 
	[JobHead].[JobNum] as [JobHead_JobNum], 
	[JobAsmbl].[AssemblySeq] as [JobAsmbl_AssemblySeq], 
	(MAX(JobOper.OprSeq)) as [Calculated_LastOVOp] 

from Erp.JobHead as [JobHead]
inner join Erp.JobAsmbl as [JobAsmbl] on 
	  JobHead.Company = JobAsmbl.Company
	and  JobHead.JobNum = JobAsmbl.JobNum
inner join Erp.JobOper as [JobOper] on 
	  JobAsmbl.Company = JobOper.Company
	and  JobAsmbl.JobNum = JobOper.JobNum
	and  JobAsmbl.AssemblySeq = JobOper.AssemblySeq
where ( JobOper.SubContract = 1  
and not JobOper.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  
and JobHead.JobClosed = 0  
and JobHead.JobFirm = 1  )
group by 
	[JobHead].[Company], 
	[JobHead].[JobNum], 
	[JobAsmbl].[AssemblySeq])
 ,[MtlIssued] as 
(select distinct 
	[JobHead1].[Company] as [JobHead1_Company], 
	[JobHead1].[JobNum] as [JobHead1_JobNum], 
	[JobAsmbl1].[AssemblySeq] as [JobAsmbl1_AssemblySeq], 
	(1) as [Calculated_MtlIssued] 

from Erp.JobHead as [JobHead1]
inner join Erp.JobAsmbl as [JobAsmbl1] on 
	  JobHead1.Company = JobAsmbl1.Company
	and  JobHead1.JobNum = JobAsmbl1.JobNum
inner join Erp.PartTran as [PartTran] on 
	  JobAsmbl1.Company = PartTran.Company
	and  JobAsmbl1.JobNum = PartTran.JobNum
	and  JobAsmbl1.AssemblySeq = PartTran.AssemblySeq
where ( PartTran.TranClass = 'I'  
and PartTran.TranQty > 0  
and JobHead1.JobClosed = 0  
and JobHead1.JobFirm = 1  ))
 ,[HeatTreat] as 
(select  
	[JobHead2].[Company] as [JobHead2_Company], 
	[JobHead2].[JobNum] as [JobHead2_JobNum], 
	[JobAsmbl2].[AssemblySeq] as [JobAsmbl2_AssemblySeq], 
	(1) as [Calculated_BackFromHT] 

from Erp.JobHead as [JobHead2]
inner join Erp.JobAsmbl as [JobAsmbl2] on 
	  JobHead2.Company = JobAsmbl2.Company
	and  JobHead2.JobNum = JobAsmbl2.JobNum
inner join Erp.JobOper as [JobOper2] on 
	  JobAsmbl2.Company = JobOper2.Company
	and  JobAsmbl2.JobNum = JobOper2.JobNum
	and  JobAsmbl2.AssemblySeq = JobOper2.AssemblySeq
where ( JobOper2.OpCode = 'HT-OVOP'  
and JobOper2.OpComplete = 1  
and JobHead2.JobClosed = 0  
and JobHead2.JobFirm = 1  ))
 ,[Farmout] as 
(select  
	[JobHead3].[Company] as [JobHead3_Company], 
	[JobHead3].[JobNum] as [JobHead3_JobNum], 
	[JobAsmbl3].[AssemblySeq] as [JobAsmbl3_AssemblySeq], 
	(1) as [Calculated_Farmout] 

from Erp.JobHead as [JobHead3]
inner join Erp.JobAsmbl as [JobAsmbl3] on 
	  JobHead3.Company = JobAsmbl3.Company
	and  JobHead3.JobNum = JobAsmbl3.JobNum
inner join Erp.JobOper as [JobOper3] on 
	  JobAsmbl3.Company = JobOper3.Company
	and  JobAsmbl3.JobNum = JobOper3.JobNum
	and  JobAsmbl3.AssemblySeq = JobOper3.AssemblySeq
inner join Erp.PORel as [PORel] on 
	  JobOper3.Company = PORel.Company
	and  JobOper3.JobNum = PORel.JobNum
	and  JobOper3.AssemblySeq = PORel.AssemblySeq
	and  JobOper3.OprSeq = PORel.JobSeq
where ( JobOper3.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  
and JobOper3.OpComplete = 0  
and PORel.OpenRelease = 1  
and JobHead3.JobClosed = 0  
and JobHead3.JobFirm = 1  ))
 ,[OVNotFinal] as 
(select  
	[JobHead4].[Company] as [JobHead4_Company], 
	[JobHead4].[JobNum] as [JobHead4_JobNum], 
	[JobAsmbl4].[AssemblySeq] as [JobAsmbl4_AssemblySeq], 
	(1) as [Calculated_OVNotFinal] 

from Erp.JobHead as [JobHead4]
inner join Erp.JobAsmbl as [JobAsmbl4] on 
	  JobHead4.Company = JobAsmbl4.Company
	and  JobHead4.JobNum = JobAsmbl4.JobNum
inner join Erp.JobOper as [JobOper4] on 
	  JobAsmbl4.Company = JobOper4.Company
	and  JobAsmbl4.JobNum = JobOper4.JobNum
	and  JobAsmbl4.AssemblySeq = JobOper4.AssemblySeq
inner join  LastOVOperations  as [LastOV1] on 
	  JobOper4.Company = LastOV1.JobHead_Company
	and  JobOper4.JobNum = LastOV1.JobHead_JobNum
	and  JobOper4.AssemblySeq = LastOV1.JobAsmbl_AssemblySeq
inner join Erp.PORel as [PORel1] on 
	  JobOper4.Company = PORel1.Company
	and  JobOper4.JobNum = PORel1.JobNum
	and  JobOper4.AssemblySeq = PORel1.AssemblySeq
	and  JobOper4.OprSeq = PORel1.JobSeq
where ( JobOper4.SubContract = 1  
and JobOper4.OpComplete = 0  
and not JobOper4.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  
and JobOper4.OprSeq <> LastOV1.Calculated_LastOVOp  
and PORel1.OpenRelease = 1  
and JobHead4.JobClosed = 0  
and JobHead4.JobFirm = 1  ))
 ,[OVFinalOrBack] as 
(select  
	[JobHead5].[Company] as [JobHead5_Company], 
	[JobHead5].[JobNum] as [JobHead5_JobNum], 
	[JobAsmbl5].[AssemblySeq] as [JobAsmbl5_AssemblySeq], 
	(1) as [Calculated_OVFinalOrBack] 

from Erp.JobHead as [JobHead5]
inner join Erp.JobAsmbl as [JobAsmbl5] on 
	  JobHead5.Company = JobAsmbl5.Company
	and  JobHead5.JobNum = JobAsmbl5.JobNum
inner join  LastOVOperations  as [LastOV2] on 
	  JobAsmbl5.Company = LastOV2.JobHead_Company
	and  JobAsmbl5.JobNum = LastOV2.JobHead_JobNum
	and  JobAsmbl5.AssemblySeq = LastOV2.JobAsmbl_AssemblySeq
inner join Erp.JobOper as [JobOper5] on 
	  LastOV2.JobHead_JobNum = JobOper5.JobNum
	and  LastOV2.JobAsmbl_AssemblySeq = JobOper5.AssemblySeq
	and  LastOV2.Calculated_LastOVOp = JobOper5.OprSeq
inner join Erp.PORel as [PORel2] on 
	  JobOper5.Company = PORel2.Company
	and  JobOper5.JobNum = PORel2.JobNum
	and  JobOper5.AssemblySeq = PORel2.AssemblySeq
	and  JobOper5.OprSeq = PORel2.JobSeq
where ( not JobOper5.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  
and JobHead5.JobClosed = 0  
and JobHead5.JobFirm = 1  ))
 ,[LastOpNotInspection] as 
(select  
	[JobOperSub].[Company] as [JobOperSub_Company], 
	[JobOperSub].[JobNum] as [JobOperSub_JobNum], 
	[JobOperSub].[AssemblySeq] as [JobOperSub_AssemblySeq], 
	(MAX(JobOperSub.OprSeq)) as [Calculated_LastOpNotInsp] 

from Erp.JobOper as [JobOperSub]
where ( JobOperSub.OpCode <> '9-OP'  )
group by 
	[JobOperSub].[Company], 
	[JobOperSub].[JobNum], 
	[JobOperSub].[AssemblySeq])
 ,[DetailComplete] as 
(select  
	[LastOpNotInspection1].[JobOperSub_Company] as [JobHead6_Company], 
	[LastOpNotInspection1].[JobOperSub_JobNum] as [JobHead6_JobNum], 
	[LastOpNotInspection1].[JobOperSub_AssemblySeq] as [JobAsmbl6_AssemblySeq], 
	(SUM(LaborDtl1.LaborQty)) as [Calculated_TotalLaborQty], 
	[JobHead6].[ProdQty] as [JobHead6_ProdQty] 

from  LastOpNotInspection  as [LastOpNotInspection1]
inner join Erp.JobHead as [JobHead6] on 
	  LastOpNotInspection1.JobOperSub_Company = JobHead6.Company
	and  LastOpNotInspection1.JobOperSub_JobNum = JobHead6.JobNum
inner join Erp.LaborDtl as [LaborDtl1] on 
	  LastOpNotInspection1.JobOperSub_Company = LaborDtl1.Company
	and  LastOpNotInspection1.JobOperSub_JobNum = LaborDtl1.JobNum
	and  LastOpNotInspection1.JobOperSub_AssemblySeq = LaborDtl1.AssemblySeq
	and  LastOpNotInspection1.Calculated_LastOpNotInsp = LaborDtl1.OprSeq
where ( JobHead6.JobClosed = 0  
and JobHead6.JobFirm = 1  )
group by 
	[LastOpNotInspection1].[JobOperSub_Company], 
	[LastOpNotInspection1].[JobOperSub_JobNum], 
	[LastOpNotInspection1].[JobOperSub_AssemblySeq], 
	[JobHead6].[ProdQty])
 ,[JobStatusBase] as 
(select distinct 
	[JobHead8].[Company] as [JobHead8_Company], 
	[JobHead8].[JobNum] as [JobHead8_JobNum], 
	[JobHead8].[PartNum] as [JobHead8_PartNum], 
	[JobAsmbl8].[AssemblySeq] as [JobAsmbl8_AssemblySeq], 
	[JobAsmbl8].[PartNum] as [JobAsmbl8_PartNum], 
	(COALESCE(MtlIssued1.Calculated_MtlIssued, 0)) as [Calculated_MtlIssued], 
	(COALESCE(HeatTreat1.Calculated_BackFromHT, 0)) as [Calculated_BackFromHT], 
	(COALESCE(Farmout1.Calculated_Farmout, 0)) as [Calculated_Farmout], 
	(COALESCE(OVNotFinal1.Calculated_OVNotFinal, 0)) as [Calculated_OVNotFinal], 
	(COALESCE(OVFinalOrBack1.Calculated_OVFinalOrBack, 0)) as [Calculated_OVFinalOrBack], 
	(COALESCE(LaborSummary1.Calculated_TotalLaborHrs, 0)) as [Calculated_TotalLaborHrs], 
	(CASE 
		WHEN COALESCE(MtlIssued1.Calculated_MtlIssued, 0) = 1 AND COALESCE(LaborSummary1.Calculated_TotalLaborHrs, 0) > 0 THEN 1 
	ELSE 
		0 
	END) as [Calculated_NewIP], 
	(CASE 
		WHEN COALESCE(HeatTreat1.Calculated_BackFromHT, 0) = 1 AND COALESCE(LaborSummary1.Calculated_TotalLaborHrs, 0) = 0 THEN 1 
	ELSE 
		0 
	END) as [Calculated_NewIP2], 
	(CASE 
		WHEN COALESCE(DetailComplete1.Calculated_TotalLaborQty, 0) >= COALESCE(DetailComplete1.JobHead6_ProdQty, 0) THEN 1 
	ELSE 
		0 
	END) as [Calculated_DetailComplete] 

from Erp.JobHead as [JobHead8]
left outer join Erp.JobAsmbl as [JobAsmbl8] on 
	  JobHead8.Company = JobAsmbl8.Company
	and  JobHead8.JobNum = JobAsmbl8.JobNum
left outer join  MtlIssued  as [MtlIssued1] on 
	  JobAsmbl8.Company = MtlIssued1.JobHead1_Company
	and  JobAsmbl8.JobNum = MtlIssued1.JobHead1_JobNum
	and  JobAsmbl8.AssemblySeq = MtlIssued1.JobAsmbl1_AssemblySeq
left outer join  HeatTreat  as [HeatTreat1] on 
	  JobAsmbl8.Company = HeatTreat1.JobHead2_Company
	and  JobAsmbl8.JobNum = HeatTreat1.JobHead2_JobNum
	and  JobAsmbl8.AssemblySeq = HeatTreat1.JobAsmbl2_AssemblySeq
left outer join  Farmout  as [Farmout1] on 
	  JobAsmbl8.Company = Farmout1.JobHead3_Company
	and  JobAsmbl8.JobNum = Farmout1.JobHead3_JobNum
	and  JobAsmbl8.AssemblySeq = Farmout1.JobAsmbl3_AssemblySeq
left outer join  OVNotFinal  as [OVNotFinal1] on 
	  JobAsmbl8.Company = OVNotFinal1.JobHead4_Company
	and  JobAsmbl8.JobNum = OVNotFinal1.JobHead4_JobNum
	and  JobAsmbl8.AssemblySeq = OVNotFinal1.JobAsmbl4_AssemblySeq
left outer join  OVFinalOrBack  as [OVFinalOrBack1] on 
	  JobAsmbl8.Company = OVFinalOrBack1.JobHead5_Company
	and  JobAsmbl8.JobNum = OVFinalOrBack1.JobHead5_JobNum
	and  JobAsmbl8.AssemblySeq = OVFinalOrBack1.JobAsmbl5_AssemblySeq
left outer join  LaborSummary  as [LaborSummary1] on 
	  JobAsmbl8.Company = LaborSummary1.LaborDtl_Company
	and  JobAsmbl8.JobNum = LaborSummary1.LaborDtl_JobNum
	and  JobAsmbl8.AssemblySeq = LaborSummary1.LaborDtl_AssemblySeq
left outer join  DetailComplete  as [DetailComplete1] on 
	  JobHead8.Company = DetailComplete1.JobHead6_Company
	and  JobHead8.JobNum = DetailComplete1.JobHead6_JobNum
where ( JobHead8.JobClosed = 0  
and JobHead8.JobFirm = 1  
and (DetailComplete1.JobAsmbl6_AssemblySeq is null 
or JobAsmbl8.AssemblySeq = DetailComplete1.JobAsmbl6_AssemblySeq ) ))
 ,[JobStatusWithInProcess] as 
(select  
	(CASE 
		WHEN (Calculated_NewIP = 1 OR Calculated_NewIP2 = 1) THEN 1 
	ELSE 
		0 
	END) as [Calculated_InProcess] 

from  JobStatusBase  as [JobStatusBase1])
 ,[JobStatusWithStatus] as 
(select  
	(CASE 
		WHEN Calculated_OVFinalOrBack = 1 THEN 6 
		WHEN Calculated_OVNotFinal = 1 THEN 5 
		WHEN Calculated_InProcess = 1 THEN 4 
		WHEN Calculated_Farmout = 1 THEN 3 
		WHEN Calculated_BackFromHT = 1 THEN 2 
		WHEN Calculated_MtlIssued = 1 THEN 1 
	ELSE 
		0 
	END) as [Calculated_Status] 

from  JobStatusWithInProcess  as [JobStatusWithInProcess1])
 ,[TopStatus] as 
(select  
	[JobStatusWithStatus1].[JobHead8_Company] as [JobStatusWithStatus1_JobHead8_Company], 
	[JobStatusWithStatus1].[JobHead8_JobNum] as [JobStatusWithStatus1_JobHead8_JobNum], 
	[JobStatusWithStatus1].[Calculated_Status] as [Calculated_TopStatus] 

from  JobStatusWithStatus  as [JobStatusWithStatus1]
where ( JobStatusWithStatus1.JobAsmbl8_AssemblySeq = 0  ))
 ,[AsmStatus] as 
(select  
	[JobStatusWithStatus2].[JobHead8_JobNum] as [JobStatusWithStatus2_JobHead8_JobNum], 
	[JobStatusWithStatus2].[Calculated_Status] as [JobStatusWithStatus2_Calculated_Status] 

from  JobStatusWithStatus  as [JobStatusWithStatus2]
where ( JobStatusWithStatus2.Calculated_DetailComplete = 0  
and JobStatusWithStatus2.JobAsmbl8_AssemblySeq <> 0  ))

select  
	[TopStatus1].[JobHead8_Company] as [JobHead8_Company], 
	(COALESCE(AsmStatus1.JobHead8_JobNum, TopStatus1.JobHead8_JobNum)) as [Calculated_JobNum], 
	(CASE 
		WHEN TopStatus1.Calculated_TopStatus = 0 THEN COALESCE(AsmStatus1.Calculated_Status, 0) 
		WHEN AsmStatus1.Calculated_Status < TopStatus1.Calculated_TopStatus THEN AsmStatus1.Calculated_Status 
	ELSE 
		TopStatus1.Calculated_TopStatus 
	END) as [Calculated_Status] 

from  TopStatus  as [TopStatus1]
left outer join  AsmStatus  as [AsmStatus1] on 
	  TopStatus1.JobHead8_JobNum = AsmStatus1.JobHead8_JobNum