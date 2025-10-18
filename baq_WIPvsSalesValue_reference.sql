-- Retrieve data from 'JobStatus' query into JobStatus 
with [JobCost] as 
(select  
	[JobAsmbl].[Company] as [JobAsmbl_Company], 
	[JobAsmbl].[Plant] as [JobAsmbl_Plant], 
	[JobAsmbl].[JobNum] as [JobAsmbl_JobNum], 
	[JobHead].[JobClosed] as [JobHead_JobClosed], 
	(ROUND(SUM(JobAsmbl.TLAMaterialCost),2)) as [Calculated_JobMaterial], 
	(ROUND(SUM(JobAsmbl.TLALaborCost),2)) as [Calculated_JobLabor], 
	(ROUND(SUM(JobAsmbl.TLABurdenCost),2)) as [Calculated_JobBurden], 
	(ROUND(SUM(JobAsmbl.TLAMtlBurCost),2)) as [Calculated_JobMtlBur], 
	(ROUND(SUM(JobAsmbl.TLASubcontractCost),2)) as [Calculated_JobSubcontract], 
	(MIN(JobAsmbl.StartDate)) as [Calculated_JobScheduledOn], 
	(JobHead.CreateDate) as [Calculated_JobCreatedOn] 

from Erp.JobAsmbl as [JobAsmbl]
inner join Erp.JobHead as [JobHead] on 
	  JobAsmbl.Company = JobHead.Company
	and  JobAsmbl.JobNum = JobHead.JobNum
	and ( JobHead.WIPCleared = 0  
and JobHead.JobFirm = 1  )
group by 
	[JobAsmbl].[Company], 
	[JobAsmbl].[Plant], 
	[JobAsmbl].[JobNum], 
	[JobHead].[JobClosed], 
	(JobHead.CreateDate))
 ,[InventoryCost] as 
(select  
	[PartTran].[Company] as [PartTran_Company], 
	[PartTran].[Plant] as [PartTran_Plant], 
	[PartTran].[JobNum] as [PartTran_JobNum], 
	(ROUND(SUM(PartTran.TranQty*PartTran.MtlUnitCost),2)) as [Calculated_InvMtl], 
	(ROUND(SUM(PartTran.TranQty*PartTran.LbrUnitCost),2)) as [Calculated_InvLbr], 
	(ROUND(SUM(PartTran.TranQty*PartTran.BurUnitCost),2)) as [Calculated_InvBur], 
	(ROUND(SUM(PartTran.TranQty*PartTran.MtlBurUnitCost),2)) as [Calculated_InvMtlBur], 
	(ROUND(SUM(PartTran.TranQty*PartTran.SubUnitCost),2)) as [Calculated_InvSub] 

from Erp.PartTran as [PartTran]
where (PartTran.JobNum <> ''  
and PartTran.TranType = 'MFG-STK'  
and PartTran.TranDate <= Constants.Today)
group by 
	[PartTran].[Company], 
	[PartTran].[Plant], 
	[PartTran].[JobNum])
 ,[COGS] as 
(select  
	[PartTran1].[Company] as [PartTran1_Company], 
	[PartTran1].[Plant] as [PartTran1_Plant], 
	[PartTran1].[JobNum] as [PartTran1_JobNum], 
	(ROUND(SUM(PartTran1.TranQty * PartTran1.MtlUnitCost),2)) as [Calculated_COGSMtl], 
	(ROUND(SUM(PartTran1.TranQty * PartTran1.LbrUnitCost),2)) as [Calculated_COGSLbr], 
	(ROUND(SUM(PartTran1.TranQty * PartTran1.BurUnitCost),2)) as [Calculated_COGSBur], 
	(ROUND(SUM(PartTran1.TranQty * PartTran1.MtlBurUnitCost),2)) as [Calculated_COGSMtlBur], 
	(ROUND(SUM(PartTran1.TranQty * PartTran1.SubUnitCost),2)) as [Calculated_COGSSub] 

from Erp.PartTran as [PartTran1]
where (PartTran1.TranType = 'MFG-CUS'  
and PartTran1.TranDate <= '10/13/2025')
group by 
	[PartTran1].[Company], 
	[PartTran1].[Plant], 
	[PartTran1].[JobNum])
 ,[MFGVAR] as 
(select  
	[PartTran2].[Company] as [PartTran2_Company], 
	[PartTran2].[Plant] as [PartTran2_Plant], 
	[PartTran2].[JobNum] as [PartTran2_JobNum], 
	(ROUND(SUM(PartTran2.TranQty * PartTran2.MtlUnitCost),2)) as [Calculated_VARMtl], 
	(ROUND(SUM(PartTran2.TranQty * PartTran2.LbrUnitCost),2)) as [Calculated_VARLbr], 
	(ROUND(SUM(PartTran2.TranQty * PartTran2.BurUnitCost),2)) as [Calculated_VARBur], 
	(ROUND(SUM(PartTran2.TranQty * PartTran2.MtlBurUnitCost),2)) as [Calculated_VARMtlBur], 
	(ROUND(SUM(PartTran2.TranQty * PartTran2.SubUnitCost),2)) as [Calculated_VARSub] 

from Erp.PartTran as [PartTran2]
where (PartTran2.TranType = 'MFG-VAR'  
and PartTran2.TranDate <= '10/13/2025')
group by 
	[PartTran2].[Company], 
	[PartTran2].[Plant], 
	[PartTran2].[JobNum])
 ,[DMR] as 
(select  
	[DMRHead].[Company] as [DMRHead_Company], 
	[DMRHead].[Plant] as [DMRHead_Plant], 
	[DMRHead].[JobNum] as [DMRHead_JobNum], 
	(ROUND(SUM((DMRHead.TotDiscrepantQty - DMRHead.TotAcceptedQty) * DMRHead.AvgMtlUnitCost),2)) as [Calculated_DMRMtl], 
	(ROUND(SUM((DMRHead.TotDiscrepantQty - DMRHead.TotAcceptedQty) * DMRHead.AvgLbrUnitCost),2)) as [Calculated_DMRLbr], 
	(ROUND(SUM((DMRHead.TotDiscrepantQty - DMRHead.TotAcceptedQty) * DMRHead.AvgBurUnitCost),2)) as [Calculated_DMRBur], 
	(ROUND(SUM((DMRHead.TotDiscrepantQty - DMRHead.TotAcceptedQty) * DMRHead.AvgMtlBurUnitCost),2)) as [Calculated_DMRMtlBur], 
	(ROUND(SUM((DMRHead.TotDiscrepantQty - DMRHead.TotAcceptedQty) * DMRHead.AvgSubUnitCost),2)) as [Calculated_DMRSub] 

from Erp.DMRHead as [DMRHead]
where (DMRHead.PONum = 0  
and DMRHead.MtlSeq = 0)
group by 
	[DMRHead].[Company], 
	[DMRHead].[Plant], 
	[DMRHead].[JobNum])
 ,[COMBPREP] as 
(select  
	[JobCost].[JobAsmbl_Company] as [JobAsmbl_Company], 
	[JobCost].[JobAsmbl_Plant] as [JobAsmbl_Plant], 
	[JobCost].[JobAsmbl_JobNum] as [JobAsmbl_JobNum], 
	[JobCost].[Calculated_JobCreatedOn] as [Calculated_JobCreatedOn], 
	[JobCost].[Calculated_JobScheduledOn] as [Calculated_JobScheduledOn], 
	[JobCost].[JobHead_JobClosed] as [JobHead_JobClosed], 
	[JobCost].[Calculated_JobMaterial] as [Calculated_JobMaterial], 
	[JobCost].[Calculated_JobLabor] as [Calculated_JobLabor], 
	[JobCost].[Calculated_JobBurden] as [Calculated_JobBurden], 
	[JobCost].[Calculated_JobMtlBur] as [Calculated_JobMtlBur], 
	[JobCost].[Calculated_JobSubcontract] as [Calculated_JobSubcontract], 
	(ISNULL(InventoryCost.Calculated_InvMtl, 0)) as [Calculated_InvMtl], 
	(ISNULL(InventoryCost.Calculated_InvLbr, 0)) as [Calculated_InvLbr], 
	(ISNULL(InventoryCost.Calculated_InvBur, 0)) as [Calculated_InvBur], 
	(ISNULL(InventoryCost.Calculated_InvMtlBur, 0)) as [Calculated_InvMtlBur], 
	(ISNULL(InventoryCost.Calculated_InvSub, 0)) as [Calculated_InvSub], 
	(ISNULL(COGS.Calculated_COGSMtl, 0)) as [Calculated_COGSMtl], 
	(ISNULL(COGS.Calculated_COGSLbr, 0)) as [Calculated_COGSLbr], 
	(ISNULL(COGS.Calculated_COGSBur, 0)) as [Calculated_COGSBur], 
	(ISNULL(COGS.Calculated_COGSMtlBur, 0)) as [Calculated_COGSMtlBur], 
	(ISNULL(COGS.Calculated_COGSSub, 0)) as [Calculated_COGSSub], 
	(ISNULL(MFGVAR.Calculated_VARMtl, 0)) as [Calculated_VARMtl], 
	(ISNULL(MFGVAR.Calculated_VARLbr, 0)) as [Calculated_VARLbr], 
	(ISNULL(MFGVAR.Calculated_VARBur, 0)) as [Calculated_VARBur], 
	(ISNULL(MFGVAR.Calculated_VARMtlBur, 0)) as [Calculated_VARMtlBur], 
	(ISNULL(MFGVAR.Calculated_VARSub, 0)) as [Calculated_VARSub], 
	(ISNULL(DMR.Calculated_DMRMtl, 0)) as [Calculated_DMRMtl], 
	(ISNULL(DMR.Calculated_DMRLbr, 0)) as [Calculated_DMRLbr], 
	(ISNULL(DMR.Calculated_DMRBur, 0)) as [Calculated_DMRBur], 
	(ISNULL(DMR.Calculated_DMRMtlBur, 0)) as [Calculated_DMRMtlBur], 
	(ISNULL(DMR.Calculated_DMRSub, 0)) as [Calculated_DMRSub] 

from  JobCost  as [JobCost]
left outer join  InventoryCost  as [InventoryCost] on 
	  JobCost.JobAsmbl_Company = InventoryCost.PartTran_Company
	and  JobCost.JobAsmbl_JobNum = InventoryCost.PartTran_JobNum
left outer join  COGS  as [COGS] on 
	  JobCost.JobAsmbl_Company = COGS.PartTran1_Company
	and  JobCost.JobAsmbl_JobNum = COGS.PartTran1_JobNum
left outer join  MFGVAR  as [MFGVAR] on 
	  JobCost.JobAsmbl_Company = MFGVAR.PartTran2_Company
	and  JobCost.JobAsmbl_JobNum = MFGVAR.PartTran2_JobNum
left outer join  DMR  as [DMR] on 
	  JobCost.JobAsmbl_Company = DMR.DMRHead_Company
	and  JobCost.JobAsmbl_JobNum = DMR.DMRHead_JobNum)
 ,[COMB] as 
(select  
	[COMBPREP].[JobAsmbl_Company] as [JobAsmbl_Company], 
	[COMBPREP].[JobAsmbl_Plant] as [JobAsmbl_Plant], 
	[COMBPREP].[JobAsmbl_JobNum] as [JobAsmbl_JobNum], 
	[COMBPREP].[Calculated_JobCreatedOn] as [Calculated_JobCreatedOn], 
	[COMBPREP].[Calculated_JobScheduledOn] as [Calculated_JobScheduledOn], 
	[COMBPREP].[Calculated_JobMaterial] as [Calculated_JobMaterial], 
	[COMBPREP].[Calculated_JobLabor] as [Calculated_JobLabor], 
	[COMBPREP].[Calculated_JobBurden] as [Calculated_JobBurden], 
	[COMBPREP].[Calculated_JobMtlBur] as [Calculated_JobMtlBur], 
	[COMBPREP].[Calculated_JobSubcontract] as [Calculated_JobSubcontract], 
	[COMBPREP].[Calculated_InvMtl] as [Calculated_InvMtl], 
	[COMBPREP].[Calculated_InvLbr] as [Calculated_InvLbr], 
	[COMBPREP].[Calculated_InvBur] as [Calculated_InvBur], 
	[COMBPREP].[Calculated_InvMtlBur] as [Calculated_InvMtlBur], 
	[COMBPREP].[Calculated_InvSub] as [Calculated_InvSub], 
	[COMBPREP].[Calculated_COGSMtl] as [Calculated_COGSMtl], 
	[COMBPREP].[Calculated_COGSLbr] as [Calculated_COGSLbr], 
	[COMBPREP].[Calculated_COGSBur] as [Calculated_COGSBur], 
	[COMBPREP].[Calculated_COGSMtlBur] as [Calculated_COGSMtlBur], 
	[COMBPREP].[Calculated_COGSSub] as [Calculated_COGSSub], 
	(ROUND(COMBPREP.Calculated_VARMtl + CASE
                                  WHEN COMBPREP.JobHead_JobClosed = 1 THEN
                                      COMBPREP.Calculated_JobMaterial - COMBPREP.Calculated_InvMtl - COMBPREP.Calculated_COGSMtl - COMBPREP.Calculated_VARMtl - COMBPREP.Calculated_DMRMtl
                                  ELSE
                                      0
                              END,2)) as [Calculated_VARMtl], 
	(ROUND(COMBPREP.Calculated_VARLbr + CASE
                                  WHEN COMBPREP.JobHead_JobClosed = 1 THEN
                                      COMBPREP.Calculated_JobLabor - COMBPREP.Calculated_InvLbr - COMBPREP.Calculated_COGSLbr - COMBPREP.Calculated_VARLbr - COMBPREP.Calculated_DMRLbr
                                  ELSE
                                      0
                              END,2)) as [Calculated_VARLbr], 
	(ROUND(COMBPREP.Calculated_VARBur + CASE
                                  WHEN COMBPREP.JobHead_JobClosed = 1 THEN
                                      COMBPREP.Calculated_JobBurden - COMBPREP.Calculated_InvBur - COMBPREP.Calculated_COGSBur - COMBPREP.Calculated_VARBur - COMBPREP.Calculated_DMRBur
                                  ELSE
                                      0
                              END,2)) as [Calculated_VARBur], 
	(ROUND(COMBPREP.Calculated_VARMtlBur + CASE
                                  WHEN COMBPREP.JobHead_JobClosed = 1 THEN
                                      COMBPREP.Calculated_JobMtlBur - COMBPREP.Calculated_InvMtlBur - COMBPREP.Calculated_COGSMtlBur - COMBPREP.Calculated_VARMtlBur - COMBPREP.Calculated_DMRMtlBur
                                  ELSE
                                      0
                              END,2)) as [Calculated_VARMtlBur], 
	(ROUND(COMBPREP.Calculated_VARSub + CASE
                                  WHEN COMBPREP.JobHead_JobClosed = 1 THEN
                                      COMBPREP.Calculated_JobSubcontract - COMBPREP.Calculated_InvSub - COMBPREP.Calculated_COGSSub - COMBPREP.Calculated_VARSub - COMBPREP.Calculated_DMRSub
                                  ELSE
                                      0
                              END,2)) as [Calculated_VARSub], 
	[COMBPREP].[Calculated_DMRMtl] as [Calculated_DMRMtl], 
	[COMBPREP].[Calculated_DMRLbr] as [Calculated_DMRLbr], 
	[COMBPREP].[Calculated_DMRBur] as [Calculated_DMRBur], 
	[COMBPREP].[Calculated_DMRMtlBur] as [Calculated_DMRMtlBur], 
	[COMBPREP].[Calculated_DMRSub] as [Calculated_DMRSub] 

from  COMBPREP  as [COMBPREP])
 ,[FINAL] as 
(select  
	[COMB].[JobAsmbl_Company] as [JobAsmbl_Company], 
	[COMB].[JobAsmbl_Plant] as [JobAsmbl_Plant], 
	[COMB].[JobAsmbl_JobNum] as [JobAsmbl_JobNum], 
	[JobHead1].[JobClosed] as [JobHead1_JobClosed], 
	[JobHead1].[ClosedDate] as [JobHead1_ClosedDate], 
	[JobHead1].[WIPCleared] as [JobHead1_WIPCleared], 
	[COMB].[Calculated_JobCreatedOn] as [Calculated_JobCreatedOn], 
	[COMB].[Calculated_JobScheduledOn] as [Calculated_JobScheduledOn], 
	(ISNULL(PartPlant.PartNum,'')) as [Calculated_PartNum], 
	(ISNULL(part.ProdCode,'')) as [Calculated_ProdCode], 
	(PartPlant.PersonID) as [Calculated_Planner], 
	(ROUND(COMB.Calculated_JobLabor - COMB.Calculated_InvLbr - COMB.Calculated_COGSLbr - COMB.Calculated_VARLbr - COMB.Calculated_DMRLbr, 2)) as [Calculated_WIPLbr], 
	(ROUND(COMB.Calculated_JobBurden - COMB.Calculated_InvBur - COMB.Calculated_COGSBur - COMB.Calculated_VARBur - COMB.Calculated_DMRBur, 2)) as [Calculated_WIPBur], 
	(ROUND(COMB.Calculated_JobMaterial - COMB.Calculated_InvMtl - COMB.Calculated_COGSMtl - COMB.Calculated_VARMtl - COMB.Calculated_DMRMtl, 2)) as [Calculated_WIPMtl], 
	(ROUND(COMB.Calculated_JobSubcontract - COMB.Calculated_InvSub - COMB.Calculated_COGSSub - COMB.Calculated_VARSub - COMB.Calculated_DMRSub, 2)) as [Calculated_WIPSubcontract], 
	(ROUND(COMB.Calculated_JobMtlBur - COMB.Calculated_InvMtlBur - COMB.Calculated_COGSMtlBur - COMB.Calculated_VARMtlBur - COMB.Calculated_DMRMtlBur, 2)) as [Calculated_WIPMtlBur], 
	(CASE WHEN Constants.CompanyID = 'F001' AND COMB.JobAsmbl_Company <> 'F101' THEN 1 ELSE CASE WHEN COMB.JobAsmbl_Company = Constants.CompanyID THEN 1 ELSE 0 END END) as [Calculated_show] 

from  COMB  as [COMB]
inner join Erp.JobHead as [JobHead1] on 
	  COMB.JobAsmbl_Company = JobHead1.Company
	and  COMB.JobAsmbl_Plant = JobHead1.Plant
	and  COMB.JobAsmbl_JobNum = JobHead1.JobNum
left outer join Erp.PartPlant as [PartPlant] on 
	  JobHead1.Company = PartPlant.Company
	and  JobHead1.PartNum = PartPlant.PartNum
	and  JobHead1.Plant = PartPlant.Plant
left outer join Erp.Part as [Part] on 
	  PartPlant.Company = Part.Company
	and  PartPlant.PartNum = Part.PartNum)

select  
	[ElFin].[JobAsmbl_JobNum] as [JobAsmbl_JobNum], 
	[ElFin].[Calculated_PartNum] as [Calculated_PartNum], 
	[ElFin].[Calculated_WIPTotal] as [Calculated_WIPTotal], 
	(case 
        when JobStatus.Calculated_Status = 1 then '1. Material Issued'
        when JobStatus.Calculated_Status = 2 then '2. Back From HT'
        when JobStatus.Calculated_Status = 3 then '3. Farmout'
        when JobStatus.Calculated_Status = 4 then '4. In Process'
        when JobStatus.Calculated_Status = 5 then '5. OV Not Final'
        when JobStatus.Calculated_Status = 6 then '6. OV Final or Back'
        else '0. Unknown'
        end) as [Calculated_ActualStatus], 
	(sum(OpenValue1.Calculated_OpenValue)) as [Calculated_OpenValTot], 
	[JobStatus].[Calculated_Status] as [JobStatus_Calculated_Status] 

from  (select  
	[FINAL].[JobAsmbl_Company] as [JobAsmbl_Company], 
	[FINAL].[JobAsmbl_Plant] as [JobAsmbl_Plant], 
	[FINAL].[JobAsmbl_JobNum] as [JobAsmbl_JobNum], 
	[FINAL].[JobHead1_JobClosed] as [JobHead1_JobClosed], 
	[FINAL].[JobHead1_ClosedDate] as [JobHead1_ClosedDate], 
	[FINAL].[Calculated_JobCreatedOn] as [Calculated_JobCreatedOn], 
	[FINAL].[Calculated_JobScheduledOn] as [Calculated_JobScheduledOn], 
	[FINAL].[Calculated_PartNum] as [Calculated_PartNum], 
	[FINAL].[Calculated_ProdCode] as [Calculated_ProdCode], 
	[FINAL].[Calculated_Planner] as [Calculated_Planner], 
	[FINAL].[Calculated_WIPLbr] as [Calculated_WIPLbr], 
	[FINAL].[Calculated_WIPBur] as [Calculated_WIPBur], 
	[FINAL].[Calculated_WIPMtl] as [Calculated_WIPMtl], 
	[FINAL].[Calculated_WIPSubcontract] as [Calculated_WIPSubcontract], 
	[FINAL].[Calculated_WIPMtlBur] as [Calculated_WIPMtlBur], 
	(FINAL.Calculated_WIPLbr + FINAL.Calculated_WIPBur + FINAL.Calculated_WIPMtl + FINAL.Calculated_WIPSubcontract + FINAL.Calculated_WIPMtlBur) as [Calculated_WIPTotal] 

from  FINAL  as [FINAL]
where (FINAL.JobHead1_WIPCleared = 0  
and FINAL.Calculated_show = 1) and ( FINAL.Calculated_WIPLbr + FINAL.Calculated_WIPBur + FINAL.Calculated_WIPMtl + FINAL.Calculated_WIPSubcontract + FINAL.Calculated_WIPMtlBur <> 0  ))  as [ElFin]
left outer join  (select  
	[JobProd].[Company] as [JobProd_Company], 
	[JobProd].[JobNum] as [JobProd_JobNum], 
	(sum(OrderRel.OurReqQty-OrderRel.OurJobShippedQty-OrderRel.OurStockShippedQty)) as [Calculated_RemainQty], 
	((RemainQty * OrderDtl.UnitPrice)) as [Calculated_OpenValue], 
	[OrderDtl].[UnitPrice] as [OrderDtl_UnitPrice] 

from Erp.JobProd as [JobProd]
inner join Erp.OrderRel as [OrderRel] on 
	  JobProd.Company = OrderRel.Company
	and  JobProd.OrderNum = OrderRel.OrderNum
	and  JobProd.OrderLine = OrderRel.OrderLine
	and  JobProd.OrderRelNum = OrderRel.OrderRelNum
inner join Erp.OrderDtl as [OrderDtl] on 
	  OrderRel.Company = OrderDtl.Company
	and  OrderRel.OrderNum = OrderDtl.OrderNum
	and  OrderRel.OrderLine = OrderDtl.OrderLine
inner join Erp.OrderHed as [OrderHed] on 
	  OrderDtl.Company = OrderHed.Company
	and  OrderDtl.OrderNum = OrderHed.OrderNum
group by 
	[JobProd].[Company], 
	[JobProd].[JobNum], 
	[OrderDtl].[UnitPrice])  as [OpenValue1] on 
	  ElFin.JobAsmbl_Company = OpenValue1.JobProd_Company
	and  ElFin.JobAsmbl_JobNum = OpenValue1.JobProd_JobNum
left outer join JobStatus as [JobStatus] on 
	  ElFin.JobAsmbl_Company = JobStatus.JobHead6_Company
	and  ElFin.JobAsmbl_JobNum = JobStatus.Calculated_JobNum
group by 
	[ElFin].[JobAsmbl_JobNum], 
	[ElFin].[Calculated_PartNum], 
	[ElFin].[Calculated_WIPTotal], 
	(case 
        when JobStatus.Calculated_Status = 1 then '1. Material Issued'
        when JobStatus.Calculated_Status = 2 then '2. Back From HT'
        when JobStatus.Calculated_Status = 3 then '3. Farmout'
        when JobStatus.Calculated_Status = 4 then '4. In Process'
        when JobStatus.Calculated_Status = 5 then '5. OV Not Final'
        when JobStatus.Calculated_Status = 6 then '6. OV Final or Back'
        else '0. Unknown'
        end), 
	[JobStatus].[Calculated_Status]