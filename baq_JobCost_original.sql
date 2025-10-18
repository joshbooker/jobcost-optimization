select  
	[FinalTop].[JobHead6_Company] as [JobHead6_Company], 
	(iif(FinalTop.JobHead6_JobNum is null, FinalTop.JobHead6_JobNum01,FinalTop.JobHead6_JobNum)) as [Calculated_JobNum], 
	[FinalTop].[Calculated_Status] as [Calculated_Status] 

from  (select  
	[TopStatus].[JobHead6_Company] as [JobHead6_Company], 
	[AsmStatus].[JobHead6_JobNum] as [JobHead6_JobNum], 
	[TopStatus].[JobHead6_JobNum] as [JobHead6_JobNum01], 
	(iif(TopStatus.Calculated_TopStatus=0,AsmStatus.Calculated_Status,iif(AsmStatus.Calculated_Status<TopStatus.Calculated_TopStatus,AsmStatus.Calculated_Status,TopStatus.Calculated_TopStatus))) as [Calculated_Status], 
	[TopStatus].[Calculated_TopStatus] as [Calculated_TopStatus] 

from  (select  
	[Top2].[JobHead6_Company] as [JobHead6_Company], 
	[Top2].[JobHead6_JobNum] as [JobHead6_JobNum], 
	[Top2].[Calculated_MtlIssued] as [Calculated_MtlIssued], 
	[Top2].[Calculated_BackFromHT] as [Calculated_BackFromHT], 
	[Top2].[Calculated_Farmout] as [Calculated_Farmout], 
	[Top2].[Calculated_InProcess] as [Calculated_InProcess], 
	[Top2].[Calculated_OVNotFinal] as [Calculated_OVNotFinal], 
	[Top2].[Calculated_OVFinalOrBack] as [Calculated_OVFinalOrBack], 
	(CASE
    WHEN Calculated_OVFinalOrBack = 1 THEN 6
    WHEN Calculated_OVNotFinal = 1 THEN 5
    WHEN Calculated_InProcess = 1 THEN 4
    WHEN Calculated_Farmout = 1 THEN 3
    WHEN Calculated_BackFromHT = 1 THEN 2
    WHEN Calculated_MtlIssued = 1 THEN 1
    ELSE 0
END) as [Calculated_TopStatus] 

from  (select distinct 
	[JobHead6].[Company] as [JobHead6_Company], 
	[JobHead6].[JobNum] as [JobHead6_JobNum], 
	[JobHead6].[PartNum] as [JobHead6_PartNum], 
	[JobAsmbl6].[AssemblySeq] as [JobAsmbl6_AssemblySeq], 
	[JobAsmbl6].[PartNum] as [JobAsmbl6_PartNum], 
	[MtlIssued].[Calculated_MtlIssued] as [Calculated_MtlIssued], 
	[HeatTreat].[Calculated_BackFromHT] as [Calculated_BackFromHT], 
	[Farmout].[Calculated_Farmout] as [Calculated_Farmout], 
	(iif((NewIP=1 or NewIP2=1),1,0)) as [Calculated_InProcess], 
	[OVNotFinal].[Calculated_OVNotFinal] as [Calculated_OVNotFinal], 
	[OVFinalOrBack].[Calculated_OVFinalOrBack] as [Calculated_OVFinalOrBack], 
	(iif(MtlIssued.Calculated_MtlIssued = 1, iif(Labor.Calculated_LaborHrs>0,1,0),0)) as [Calculated_NewIP], 
	(iif(HeatTreat.Calculated_BackFromHT=1, iif(Labor.Calculated_LaborHrs=0,1,0),0)) as [Calculated_NewIP2], 
	(iif(DetailComplete2.Calculated_LaborTotal>=JobHead6.ProdQty,1,0)) as [Calculated_DetailComplete] 

from Erp.JobHead as [JobHead6]
left outer join Erp.JobAsmbl as [JobAsmbl6] on 
	  JobHead6.Company = JobAsmbl6.Company
	and  JobHead6.JobNum = JobAsmbl6.JobNum
left outer join  (select distinct 
	[JobAsmbl].[JobNum] as [JobAsmbl_JobNum], 
	[JobAsmbl].[AssemblySeq] as [JobAsmbl_AssemblySeq], 
	(1) as [Calculated_MtlIssued] 

from Erp.JobHead as [JobHead]
inner join Erp.JobAsmbl as [JobAsmbl] on 
	  JobHead.Company = JobAsmbl.Company
	and  JobHead.JobNum = JobAsmbl.JobNum
inner join Erp.PartTran as [PartTran] on 
	  JobAsmbl.Company = PartTran.Company
	and  JobAsmbl.JobNum = PartTran.JobNum
	and  JobAsmbl.AssemblySeq = PartTran.AssemblySeq
	and ( PartTran.TranClass = 'I'  
and PartTran.TranQty > 0  ))  as [MtlIssued] on 
	  JobAsmbl6.JobNum = MtlIssued.JobAsmbl_JobNum
	and  JobAsmbl6.AssemblySeq = MtlIssued.JobAsmbl_AssemblySeq
left outer join  (select  
	[JobAsmbl1].[JobNum] as [JobAsmbl1_JobNum], 
	[JobAsmbl1].[AssemblySeq] as [JobAsmbl1_AssemblySeq], 
	(1) as [Calculated_BackFromHT] 

from Erp.JobHead as [JobHead1]
inner join Erp.JobAsmbl as [JobAsmbl1] on 
	  JobHead1.Company = JobAsmbl1.Company
	and  JobHead1.JobNum = JobAsmbl1.JobNum
inner join Erp.JobOper as [JobOper1] on 
	  JobAsmbl1.Company = JobOper1.Company
	and  JobAsmbl1.JobNum = JobOper1.JobNum
	and  JobAsmbl1.AssemblySeq = JobOper1.AssemblySeq
	and ( JobOper1.OpCode = 'HT-OVOP'  
and JobOper1.OpComplete = true  ))  as [HeatTreat] on 
	  JobAsmbl6.JobNum = HeatTreat.JobAsmbl1_JobNum
	and  JobAsmbl6.AssemblySeq = HeatTreat.JobAsmbl1_AssemblySeq
left outer join  (select  
	[JobHead2].[JobNum] as [JobHead2_JobNum], 
	[JobAsmbl2].[AssemblySeq] as [JobAsmbl2_AssemblySeq], 
	(1) as [Calculated_Farmout] 

from Erp.JobHead as [JobHead2]
inner join Erp.JobAsmbl as [JobAsmbl2] on 
	  JobHead2.Company = JobAsmbl2.Company
	and  JobHead2.JobNum = JobAsmbl2.JobNum
inner join Erp.JobOper as [JobOper2] on 
	  JobAsmbl2.Company = JobOper2.Company
	and  JobAsmbl2.JobNum = JobOper2.JobNum
	and  JobAsmbl2.AssemblySeq = JobOper2.AssemblySeq
	and ( JobOper2.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  
and JobOper2.OpComplete = false  )
inner join Erp.PORel as [PORel] on 
	  JobOper2.Company = PORel.Company
	and  JobOper2.JobNum = PORel.JobNum
	and  JobOper2.AssemblySeq = PORel.AssemblySeq
	and  JobOper2.OprSeq = PORel.JobSeq
	and ( PORel.OpenRelease = true  ))  as [Farmout] on 
	  JobAsmbl6.JobNum = Farmout.JobHead2_JobNum
	and  JobAsmbl6.AssemblySeq = Farmout.JobAsmbl2_AssemblySeq
left outer join  (select  
	[JobHead3].[JobNum] as [JobHead3_JobNum], 
	[JobAsmbl3].[AssemblySeq] as [JobAsmbl3_AssemblySeq], 
	(1) as [Calculated_OVNotFinal], 
	[PORel1].[OpenRelease] as [PORel1_OpenRelease], 
	[PORel1].[PONum] as [PORel1_PONum], 
	[PORel1].[POLine] as [PORel1_POLine], 
	[PORel1].[PORelNum] as [PORel1_PORelNum], 
	[PORel1].[DueDate] as [PORel1_DueDate], 
	[PORel1].[XRelQty] as [PORel1_XRelQty], 
	[PORel1].[RelQty] as [PORel1_RelQty], 
	[PORel1].[JobNum] as [PORel1_JobNum], 
	[PORel1].[AssemblySeq] as [PORel1_AssemblySeq], 
	[PORel1].[JobSeq] as [PORel1_JobSeq] 

from Erp.JobHead as [JobHead3]
inner join Erp.JobAsmbl as [JobAsmbl3] on 
	  JobHead3.Company = JobAsmbl3.Company
	and  JobHead3.JobNum = JobAsmbl3.JobNum
inner join Erp.JobOper as [JobOper3] on 
	  JobAsmbl3.Company = JobOper3.Company
	and  JobAsmbl3.JobNum = JobOper3.JobNum
	and  JobAsmbl3.AssemblySeq = JobOper3.AssemblySeq
	and ( JobOper3.SubContract = true  
and JobOper3.OpComplete = false  
and not JobOper3.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
left outer join  (select  
	[JobHead4].[JobNum] as [JobHead4_JobNum], 
	[JobAsmbl4].[AssemblySeq] as [JobAsmbl4_AssemblySeq], 
	(max(JobOper4.OprSeq)) as [Calculated_LastOVOp] 

from Erp.JobHead as [JobHead4]
inner join Erp.JobAsmbl as [JobAsmbl4] on 
	  JobHead4.Company = JobAsmbl4.Company
	and  JobHead4.JobNum = JobAsmbl4.JobNum
inner join Erp.JobOper as [JobOper4] on 
	  JobAsmbl4.Company = JobOper4.Company
	and  JobAsmbl4.JobNum = JobOper4.JobNum
	and  JobAsmbl4.AssemblySeq = JobOper4.AssemblySeq
	and ( JobOper4.SubContract = true  
and not JobOper4.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
group by 
	[JobHead4].[JobNum], 
	[JobAsmbl4].[AssemblySeq])  as [LastOVOp1] on 
	  JobOper3.JobNum = LastOVOp1.JobHead4_JobNum
	and  JobOper3.AssemblySeq = LastOVOp1.JobAsmbl4_AssemblySeq
	and not JobOper3.OprSeq = LastOVOp1.Calculated_LastOVOp
inner join Erp.PORel as [PORel1] on 
	  JobOper3.Company = PORel1.Company
	and  JobOper3.JobNum = PORel1.JobNum
	and  JobOper3.AssemblySeq = PORel1.AssemblySeq
	and  JobOper3.OprSeq = PORel1.JobSeq
	and ( PORel1.OpenRelease = true  ))  as [OVNotFinal] on 
	  JobAsmbl6.JobNum = OVNotFinal.JobHead3_JobNum
	and  JobAsmbl6.AssemblySeq = OVNotFinal.JobAsmbl3_AssemblySeq
left outer join  (select  
	[JobHead5].[JobNum] as [JobHead5_JobNum], 
	[JobAsmbl5].[AssemblySeq] as [JobAsmbl5_AssemblySeq], 
	(1) as [Calculated_OVFinalOrBack], 
	[PORel2].[OpenRelease] as [PORel2_OpenRelease], 
	[PORel2].[VoidRelease] as [PORel2_VoidRelease], 
	[PORel2].[PONum] as [PORel2_PONum], 
	[PORel2].[POLine] as [PORel2_POLine], 
	[PORel2].[PORelNum] as [PORel2_PORelNum], 
	[PORel2].[DueDate] as [PORel2_DueDate], 
	[PORel2].[RelQty] as [PORel2_RelQty], 
	[PORel2].[JobNum] as [PORel2_JobNum], 
	[PORel2].[AssemblySeq] as [PORel2_AssemblySeq], 
	[PORel2].[JobSeq] as [PORel2_JobSeq], 
	[PORel2].[Status] as [PORel2_Status] 

from Erp.JobHead as [JobHead5]
inner join Erp.JobAsmbl as [JobAsmbl5] on 
	  JobHead5.Company = JobAsmbl5.Company
	and  JobHead5.JobNum = JobAsmbl5.JobNum
inner join  (select  
	[JobHead4].[JobNum] as [JobHead4_JobNum], 
	[JobAsmbl4].[AssemblySeq] as [JobAsmbl4_AssemblySeq], 
	(max(JobOper4.OprSeq)) as [Calculated_LastOVOp] 

from Erp.JobHead as [JobHead4]
inner join Erp.JobAsmbl as [JobAsmbl4] on 
	  JobHead4.Company = JobAsmbl4.Company
	and  JobHead4.JobNum = JobAsmbl4.JobNum
inner join Erp.JobOper as [JobOper4] on 
	  JobAsmbl4.Company = JobOper4.Company
	and  JobAsmbl4.JobNum = JobOper4.JobNum
	and  JobAsmbl4.AssemblySeq = JobOper4.AssemblySeq
	and ( JobOper4.SubContract = true  
and not JobOper4.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
group by 
	[JobHead4].[JobNum], 
	[JobAsmbl4].[AssemblySeq])  as [LastOVOp] on 
	  JobAsmbl5.JobNum = LastOVOp.JobHead4_JobNum
	and  JobAsmbl5.AssemblySeq = LastOVOp.JobAsmbl4_AssemblySeq
inner join Erp.JobOper as [JobOper5] on 
	  LastOVOp.JobHead4_JobNum = JobOper5.JobNum
	and  LastOVOp.JobAsmbl4_AssemblySeq = JobOper5.AssemblySeq
	and  LastOVOp.Calculated_LastOVOp = JobOper5.OprSeq
	and ( not JobOper5.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
inner join Erp.PORel as [PORel2] on 
	  JobOper5.Company = PORel2.Company
	and  JobOper5.JobNum = PORel2.JobNum
	and  JobOper5.AssemblySeq = PORel2.AssemblySeq
	and  JobOper5.OprSeq = PORel2.JobSeq)  as [OVFinalOrBack] on 
	  JobAsmbl6.JobNum = OVFinalOrBack.JobHead5_JobNum
	and  JobAsmbl6.AssemblySeq = OVFinalOrBack.JobAsmbl5_AssemblySeq
left outer join  (select  
	[LaborDtl].[Company] as [LaborDtl_Company], 
	[LaborDtl].[JobNum] as [LaborDtl_JobNum], 
	[LaborDtl].[AssemblySeq] as [LaborDtl_AssemblySeq], 
	(sum(LaborDtl.LaborHrs)) as [Calculated_LaborHrs] 

from Erp.LaborDtl as [LaborDtl]
group by 
	[LaborDtl].[Company], 
	[LaborDtl].[JobNum], 
	[LaborDtl].[AssemblySeq])  as [Labor] on 
	  JobAsmbl6.Company = Labor.LaborDtl_Company
	and  JobAsmbl6.JobNum = Labor.LaborDtl_JobNum
	and  JobAsmbl6.AssemblySeq = Labor.LaborDtl_AssemblySeq
left outer join  (select  
	[DetailComplete1].[JobHead7_Company] as [JobHead7_Company], 
	[DetailComplete1].[JobHead7_JobNum] as [JobHead7_JobNum], 
	[DetailComplete1].[JobAsmbl7_AssemblySeq] as [JobAsmbl7_AssemblySeq], 
	(sum(LaborDtl1.LaborQty)) as [Calculated_LaborTotal] 

from  (select  
	[JobHead7].[Company] as [JobHead7_Company], 
	[JobHead7].[JobNum] as [JobHead7_JobNum], 
	[JobAsmbl7].[AssemblySeq] as [JobAsmbl7_AssemblySeq], 
	[JobHead7].[ProdQty] as [JobHead7_ProdQty], 
	(max(JobOper.OprSeq)) as [Calculated_LastOpNotInsp] 

from Erp.JobHead as [JobHead7]
inner join Erp.JobAsmbl as [JobAsmbl7] on 
	  JobHead7.Company = JobAsmbl7.Company
	and  JobHead7.JobNum = JobAsmbl7.JobNum
inner join Erp.JobOper as [JobOper] on 
	  JobAsmbl7.Company = JobOper.Company
	and  JobAsmbl7.JobNum = JobOper.JobNum
	and  JobAsmbl7.AssemblySeq = JobOper.AssemblySeq
	and ( JobOper.OpCode <> '9-OP'  )
group by 
	[JobHead7].[Company], 
	[JobHead7].[JobNum], 
	[JobAsmbl7].[AssemblySeq], 
	[JobHead7].[ProdQty])  as [DetailComplete1]
inner join Erp.LaborDtl as [LaborDtl1] on 
	  DetailComplete1.JobHead7_Company = LaborDtl1.Company
	and  DetailComplete1.JobHead7_JobNum = LaborDtl1.JobNum
	and  DetailComplete1.JobAsmbl7_AssemblySeq = LaborDtl1.AssemblySeq
	and  DetailComplete1.Calculated_LastOpNotInsp = LaborDtl1.OprSeq
group by 
	[DetailComplete1].[JobHead7_Company], 
	[DetailComplete1].[JobHead7_JobNum], 
	[DetailComplete1].[JobAsmbl7_AssemblySeq])  as [DetailComplete2] on 
	  JobAsmbl6.Company = DetailComplete2.JobHead7_Company
	and  JobAsmbl6.JobNum = DetailComplete2.JobHead7_JobNum
	and  JobAsmbl6.AssemblySeq = DetailComplete2.JobAsmbl7_AssemblySeq)  as [Top2]
where (Top2.JobAsmbl6_AssemblySeq = 0))  as [TopStatus]
left outer join  (select  
	[Top].[JobHead6_JobNum] as [JobHead6_JobNum], 
	[Top].[JobAsmbl6_AssemblySeq] as [JobAsmbl6_AssemblySeq], 
	[Top].[Calculated_MtlIssued] as [Calculated_MtlIssued], 
	[Top].[Calculated_BackFromHT] as [Calculated_BackFromHT], 
	[Top].[Calculated_Farmout] as [Calculated_Farmout], 
	[Top].[Calculated_InProcess] as [Calculated_InProcess], 
	[Top].[Calculated_OVNotFinal] as [Calculated_OVNotFinal], 
	[Top].[Calculated_OVFinalOrBack] as [Calculated_OVFinalOrBack], 
	(CASE
    WHEN Calculated_OVFinalOrBack = 1 THEN 6
    WHEN Calculated_OVNotFinal = 1 THEN 5
    WHEN Calculated_InProcess = 1 THEN 4
    WHEN Calculated_Farmout = 1 THEN 3
    WHEN Calculated_BackFromHT = 1 THEN 2
    WHEN Calculated_MtlIssued = 1 THEN 1
    ELSE 0
END) as [Calculated_Status] 

from  (select distinct 
	[JobHead6].[Company] as [JobHead6_Company], 
	[JobHead6].[JobNum] as [JobHead6_JobNum], 
	[JobHead6].[PartNum] as [JobHead6_PartNum], 
	[JobAsmbl6].[AssemblySeq] as [JobAsmbl6_AssemblySeq], 
	[JobAsmbl6].[PartNum] as [JobAsmbl6_PartNum], 
	[MtlIssued].[Calculated_MtlIssued] as [Calculated_MtlIssued], 
	[HeatTreat].[Calculated_BackFromHT] as [Calculated_BackFromHT], 
	[Farmout].[Calculated_Farmout] as [Calculated_Farmout], 
	(iif((NewIP=1 or NewIP2=1),1,0)) as [Calculated_InProcess], 
	[OVNotFinal].[Calculated_OVNotFinal] as [Calculated_OVNotFinal], 
	[OVFinalOrBack].[Calculated_OVFinalOrBack] as [Calculated_OVFinalOrBack], 
	(iif(MtlIssued.Calculated_MtlIssued = 1, iif(Labor.Calculated_LaborHrs>0,1,0),0)) as [Calculated_NewIP], 
	(iif(HeatTreat.Calculated_BackFromHT=1, iif(Labor.Calculated_LaborHrs=0,1,0),0)) as [Calculated_NewIP2], 
	(iif(DetailComplete2.Calculated_LaborTotal>=JobHead6.ProdQty,1,0)) as [Calculated_DetailComplete] 

from Erp.JobHead as [JobHead6]
left outer join Erp.JobAsmbl as [JobAsmbl6] on 
	  JobHead6.Company = JobAsmbl6.Company
	and  JobHead6.JobNum = JobAsmbl6.JobNum
left outer join  (select distinct 
	[JobAsmbl].[JobNum] as [JobAsmbl_JobNum], 
	[JobAsmbl].[AssemblySeq] as [JobAsmbl_AssemblySeq], 
	(1) as [Calculated_MtlIssued] 

from Erp.JobHead as [JobHead]
inner join Erp.JobAsmbl as [JobAsmbl] on 
	  JobHead.Company = JobAsmbl.Company
	and  JobHead.JobNum = JobAsmbl.JobNum
inner join Erp.PartTran as [PartTran] on 
	  JobAsmbl.Company = PartTran.Company
	and  JobAsmbl.JobNum = PartTran.JobNum
	and  JobAsmbl.AssemblySeq = PartTran.AssemblySeq
	and ( PartTran.TranClass = 'I'  
and PartTran.TranQty > 0  ))  as [MtlIssued] on 
	  JobAsmbl6.JobNum = MtlIssued.JobAsmbl_JobNum
	and  JobAsmbl6.AssemblySeq = MtlIssued.JobAsmbl_AssemblySeq
left outer join  (select  
	[JobAsmbl1].[JobNum] as [JobAsmbl1_JobNum], 
	[JobAsmbl1].[AssemblySeq] as [JobAsmbl1_AssemblySeq], 
	(1) as [Calculated_BackFromHT] 

from Erp.JobHead as [JobHead1]
inner join Erp.JobAsmbl as [JobAsmbl1] on 
	  JobHead1.Company = JobAsmbl1.Company
	and  JobHead1.JobNum = JobAsmbl1.JobNum
inner join Erp.JobOper as [JobOper1] on 
	  JobAsmbl1.Company = JobOper1.Company
	and  JobAsmbl1.JobNum = JobOper1.JobNum
	and  JobAsmbl1.AssemblySeq = JobOper1.AssemblySeq
	and ( JobOper1.OpCode = 'HT-OVOP'  
and JobOper1.OpComplete = true  ))  as [HeatTreat] on 
	  JobAsmbl6.JobNum = HeatTreat.JobAsmbl1_JobNum
	and  JobAsmbl6.AssemblySeq = HeatTreat.JobAsmbl1_AssemblySeq
left outer join  (select  
	[JobHead2].[JobNum] as [JobHead2_JobNum], 
	[JobAsmbl2].[AssemblySeq] as [JobAsmbl2_AssemblySeq], 
	(1) as [Calculated_Farmout] 

from Erp.JobHead as [JobHead2]
inner join Erp.JobAsmbl as [JobAsmbl2] on 
	  JobHead2.Company = JobAsmbl2.Company
	and  JobHead2.JobNum = JobAsmbl2.JobNum
inner join Erp.JobOper as [JobOper2] on 
	  JobAsmbl2.Company = JobOper2.Company
	and  JobAsmbl2.JobNum = JobOper2.JobNum
	and  JobAsmbl2.AssemblySeq = JobOper2.AssemblySeq
	and ( JobOper2.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  
and JobOper2.OpComplete = false  )
inner join Erp.PORel as [PORel] on 
	  JobOper2.Company = PORel.Company
	and  JobOper2.JobNum = PORel.JobNum
	and  JobOper2.AssemblySeq = PORel.AssemblySeq
	and  JobOper2.OprSeq = PORel.JobSeq
	and ( PORel.OpenRelease = true  ))  as [Farmout] on 
	  JobAsmbl6.JobNum = Farmout.JobHead2_JobNum
	and  JobAsmbl6.AssemblySeq = Farmout.JobAsmbl2_AssemblySeq
left outer join  (select  
	[JobHead3].[JobNum] as [JobHead3_JobNum], 
	[JobAsmbl3].[AssemblySeq] as [JobAsmbl3_AssemblySeq], 
	(1) as [Calculated_OVNotFinal], 
	[PORel1].[OpenRelease] as [PORel1_OpenRelease], 
	[PORel1].[PONum] as [PORel1_PONum], 
	[PORel1].[POLine] as [PORel1_POLine], 
	[PORel1].[PORelNum] as [PORel1_PORelNum], 
	[PORel1].[DueDate] as [PORel1_DueDate], 
	[PORel1].[XRelQty] as [PORel1_XRelQty], 
	[PORel1].[RelQty] as [PORel1_RelQty], 
	[PORel1].[JobNum] as [PORel1_JobNum], 
	[PORel1].[AssemblySeq] as [PORel1_AssemblySeq], 
	[PORel1].[JobSeq] as [PORel1_JobSeq] 

from Erp.JobHead as [JobHead3]
inner join Erp.JobAsmbl as [JobAsmbl3] on 
	  JobHead3.Company = JobAsmbl3.Company
	and  JobHead3.JobNum = JobAsmbl3.JobNum
inner join Erp.JobOper as [JobOper3] on 
	  JobAsmbl3.Company = JobOper3.Company
	and  JobAsmbl3.JobNum = JobOper3.JobNum
	and  JobAsmbl3.AssemblySeq = JobOper3.AssemblySeq
	and ( JobOper3.SubContract = true  
and JobOper3.OpComplete = false  
and not JobOper3.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
left outer join  (select  
	[JobHead4].[JobNum] as [JobHead4_JobNum], 
	[JobAsmbl4].[AssemblySeq] as [JobAsmbl4_AssemblySeq], 
	(max(JobOper4.OprSeq)) as [Calculated_LastOVOp] 

from Erp.JobHead as [JobHead4]
inner join Erp.JobAsmbl as [JobAsmbl4] on 
	  JobHead4.Company = JobAsmbl4.Company
	and  JobHead4.JobNum = JobAsmbl4.JobNum
inner join Erp.JobOper as [JobOper4] on 
	  JobAsmbl4.Company = JobOper4.Company
	and  JobAsmbl4.JobNum = JobOper4.JobNum
	and  JobAsmbl4.AssemblySeq = JobOper4.AssemblySeq
	and ( JobOper4.SubContract = true  
and not JobOper4.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
group by 
	[JobHead4].[JobNum], 
	[JobAsmbl4].[AssemblySeq])  as [LastOVOp1] on 
	  JobOper3.JobNum = LastOVOp1.JobHead4_JobNum
	and  JobOper3.AssemblySeq = LastOVOp1.JobAsmbl4_AssemblySeq
	and not JobOper3.OprSeq = LastOVOp1.Calculated_LastOVOp
inner join Erp.PORel as [PORel1] on 
	  JobOper3.Company = PORel1.Company
	and  JobOper3.JobNum = PORel1.JobNum
	and  JobOper3.AssemblySeq = PORel1.AssemblySeq
	and  JobOper3.OprSeq = PORel1.JobSeq
	and ( PORel1.OpenRelease = true  ))  as [OVNotFinal] on 
	  JobAsmbl6.JobNum = OVNotFinal.JobHead3_JobNum
	and  JobAsmbl6.AssemblySeq = OVNotFinal.JobAsmbl3_AssemblySeq
left outer join  (select  
	[JobHead5].[JobNum] as [JobHead5_JobNum], 
	[JobAsmbl5].[AssemblySeq] as [JobAsmbl5_AssemblySeq], 
	(1) as [Calculated_OVFinalOrBack], 
	[PORel2].[OpenRelease] as [PORel2_OpenRelease], 
	[PORel2].[VoidRelease] as [PORel2_VoidRelease], 
	[PORel2].[PONum] as [PORel2_PONum], 
	[PORel2].[POLine] as [PORel2_POLine], 
	[PORel2].[PORelNum] as [PORel2_PORelNum], 
	[PORel2].[DueDate] as [PORel2_DueDate], 
	[PORel2].[RelQty] as [PORel2_RelQty], 
	[PORel2].[JobNum] as [PORel2_JobNum], 
	[PORel2].[AssemblySeq] as [PORel2_AssemblySeq], 
	[PORel2].[JobSeq] as [PORel2_JobSeq], 
	[PORel2].[Status] as [PORel2_Status] 

from Erp.JobHead as [JobHead5]
inner join Erp.JobAsmbl as [JobAsmbl5] on 
	  JobHead5.Company = JobAsmbl5.Company
	and  JobHead5.JobNum = JobAsmbl5.JobNum
inner join  (select  
	[JobHead4].[JobNum] as [JobHead4_JobNum], 
	[JobAsmbl4].[AssemblySeq] as [JobAsmbl4_AssemblySeq], 
	(max(JobOper4.OprSeq)) as [Calculated_LastOVOp] 

from Erp.JobHead as [JobHead4]
inner join Erp.JobAsmbl as [JobAsmbl4] on 
	  JobHead4.Company = JobAsmbl4.Company
	and  JobHead4.JobNum = JobAsmbl4.JobNum
inner join Erp.JobOper as [JobOper4] on 
	  JobAsmbl4.Company = JobOper4.Company
	and  JobAsmbl4.JobNum = JobOper4.JobNum
	and  JobAsmbl4.AssemblySeq = JobOper4.AssemblySeq
	and ( JobOper4.SubContract = true  
and not JobOper4.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
group by 
	[JobHead4].[JobNum], 
	[JobAsmbl4].[AssemblySeq])  as [LastOVOp] on 
	  JobAsmbl5.JobNum = LastOVOp.JobHead4_JobNum
	and  JobAsmbl5.AssemblySeq = LastOVOp.JobAsmbl4_AssemblySeq
inner join Erp.JobOper as [JobOper5] on 
	  LastOVOp.JobHead4_JobNum = JobOper5.JobNum
	and  LastOVOp.JobAsmbl4_AssemblySeq = JobOper5.AssemblySeq
	and  LastOVOp.Calculated_LastOVOp = JobOper5.OprSeq
	and ( not JobOper5.OpCode IN ('OMC-OVOP', 'OMP-OVOP')  )
inner join Erp.PORel as [PORel2] on 
	  JobOper5.Company = PORel2.Company
	and  JobOper5.JobNum = PORel2.JobNum
	and  JobOper5.AssemblySeq = PORel2.AssemblySeq
	and  JobOper5.OprSeq = PORel2.JobSeq)  as [OVFinalOrBack] on 
	  JobAsmbl6.JobNum = OVFinalOrBack.JobHead5_JobNum
	and  JobAsmbl6.AssemblySeq = OVFinalOrBack.JobAsmbl5_AssemblySeq
left outer join  (select  
	[LaborDtl].[Company] as [LaborDtl_Company], 
	[LaborDtl].[JobNum] as [LaborDtl_JobNum], 
	[LaborDtl].[AssemblySeq] as [LaborDtl_AssemblySeq], 
	(sum(LaborDtl.LaborHrs)) as [Calculated_LaborHrs] 

from Erp.LaborDtl as [LaborDtl]
group by 
	[LaborDtl].[Company], 
	[LaborDtl].[JobNum], 
	[LaborDtl].[AssemblySeq])  as [Labor] on 
	  JobAsmbl6.Company = Labor.LaborDtl_Company
	and  JobAsmbl6.JobNum = Labor.LaborDtl_JobNum
	and  JobAsmbl6.AssemblySeq = Labor.LaborDtl_AssemblySeq
left outer join  (select  
	[DetailComplete1].[JobHead7_Company] as [JobHead7_Company], 
	[DetailComplete1].[JobHead7_JobNum] as [JobHead7_JobNum], 
	[DetailComplete1].[JobAsmbl7_AssemblySeq] as [JobAsmbl7_AssemblySeq], 
	(sum(LaborDtl1.LaborQty)) as [Calculated_LaborTotal] 

from  (select  
	[JobHead7].[Company] as [JobHead7_Company], 
	[JobHead7].[JobNum] as [JobHead7_JobNum], 
	[JobAsmbl7].[AssemblySeq] as [JobAsmbl7_AssemblySeq], 
	[JobHead7].[ProdQty] as [JobHead7_ProdQty], 
	(max(JobOper.OprSeq)) as [Calculated_LastOpNotInsp] 

from Erp.JobHead as [JobHead7]
inner join Erp.JobAsmbl as [JobAsmbl7] on 
	  JobHead7.Company = JobAsmbl7.Company
	and  JobHead7.JobNum = JobAsmbl7.JobNum
inner join Erp.JobOper as [JobOper] on 
	  JobAsmbl7.Company = JobOper.Company
	and  JobAsmbl7.JobNum = JobOper.JobNum
	and  JobAsmbl7.AssemblySeq = JobOper.AssemblySeq
	and ( JobOper.OpCode <> '9-OP'  )
group by 
	[JobHead7].[Company], 
	[JobHead7].[JobNum], 
	[JobAsmbl7].[AssemblySeq], 
	[JobHead7].[ProdQty])  as [DetailComplete1]
inner join Erp.LaborDtl as [LaborDtl1] on 
	  DetailComplete1.JobHead7_Company = LaborDtl1.Company
	and  DetailComplete1.JobHead7_JobNum = LaborDtl1.JobNum
	and  DetailComplete1.JobAsmbl7_AssemblySeq = LaborDtl1.AssemblySeq
	and  DetailComplete1.Calculated_LastOpNotInsp = LaborDtl1.OprSeq
group by 
	[DetailComplete1].[JobHead7_Company], 
	[DetailComplete1].[JobHead7_JobNum], 
	[DetailComplete1].[JobAsmbl7_AssemblySeq])  as [DetailComplete2] on 
	  JobAsmbl6.Company = DetailComplete2.JobHead7_Company
	and  JobAsmbl6.JobNum = DetailComplete2.JobHead7_JobNum
	and  JobAsmbl6.AssemblySeq = DetailComplete2.JobAsmbl7_AssemblySeq)  as [Top]
where (Top.Calculated_DetailComplete = false  
and Top.JobAsmbl6_AssemblySeq <> 0))  as [AsmStatus] on 
	  TopStatus.JobHead6_JobNum = AsmStatus.JobHead6_JobNum)  as [FinalTop]