-- Optimized JobStatus Query
-- Performance improvements: eliminate duplication, consolidate subqueries, optimize labor aggregations, 
-- simplify IIF statements, add early filtering
-- Applied SQL-to-BAQ prefixing rules for tool compatibility
--correlation error: 77c8add7-84c6-4049-91d6-d1ef5aae8ef6
WITH 
-- Consolidated labor aggregations (Change #4)
LaborSummary AS (
    SELECT 
        [LaborDtl].[Company] as [LaborDtl_Company], 
        [LaborDtl].[JobNum] as [LaborDtl_JobNum], 
        [LaborDtl].[AssemblySeq] as [LaborDtl_AssemblySeq],
        SUM([LaborDtl].[LaborHrs]) as [Calculated_TotalLaborHrs],
        SUM([LaborDtl].[LaborQty]) as [Calculated_TotalLaborQty]
    FROM Erp.LaborDtl as [LaborDtl]
    GROUP BY [LaborDtl].[Company], [LaborDtl].[JobNum], [LaborDtl].[AssemblySeq]
),

-- Reusable LastOVOp logic (Change #3)
LastOVOperations AS (
    SELECT 
        [JobHead].[Company] as [JobHead_Company], 
        [JobHead].[JobNum] as [JobHead_JobNum], 
        [JobAsmbl].[AssemblySeq] as [JobAsmbl_AssemblySeq],
        MAX([JobOper].[OprSeq]) as [Calculated_LastOVOp]
    FROM Erp.JobHead as [JobHead]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl] ON [JobHead].[Company] = [JobAsmbl].[Company] AND [JobHead].[JobNum] = [JobAsmbl].[JobNum]
    INNER JOIN Erp.JobOper as [JobOper] ON [JobAsmbl].[Company] = [JobOper].[Company] AND [JobAsmbl].[JobNum] = [JobOper].[JobNum] AND [JobAsmbl].[AssemblySeq] = [JobOper].[AssemblySeq]
    WHERE [JobOper].[SubContract] = 1 
      AND [JobOper].[OpCode] NOT IN ('OMC-OVOP', 'OMP-OVOP')
      AND [JobHead].[JobClosed] = 0 
      AND [JobHead].[JobFirm] = 1
    GROUP BY [JobHead].[Company], [JobHead].[JobNum], [JobAsmbl].[AssemblySeq]
),

-- Material issued status
MtlIssued AS (
    SELECT DISTINCT 
        [JobHead1].[Company] as [JobHead1_Company], 
        [JobHead1].[JobNum] as [JobHead1_JobNum], 
        [JobAsmbl1].[AssemblySeq] as [JobAsmbl1_AssemblySeq],
        1 as [Calculated_MtlIssued]
    FROM Erp.JobHead as [JobHead1]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl1] ON [JobHead1].[Company] = [JobAsmbl1].[Company] AND [JobHead1].[JobNum] = [JobAsmbl1].[JobNum]
    INNER JOIN Erp.PartTran as [PartTran] ON [JobAsmbl1].[Company] = [PartTran].[Company] AND [JobAsmbl1].[JobNum] = [PartTran].[JobNum] AND [JobAsmbl1].[AssemblySeq] = [PartTran].[AssemblySeq]
    WHERE [PartTran].[TranClass] = 'I' AND [PartTran].[TranQty] > 0
      AND [JobHead1].[JobClosed] = 0 
      AND [JobHead1].[JobFirm] = 1
),

-- Heat treatment status
HeatTreat AS (
    SELECT 
        [JobHead2].[Company] as [JobHead2_Company], 
        [JobHead2].[JobNum] as [JobHead2_JobNum], 
        [JobAsmbl2].[AssemblySeq] as [JobAsmbl2_AssemblySeq],
        1 as [Calculated_BackFromHT]
    FROM Erp.JobHead as [JobHead2]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl2] ON [JobHead2].[Company] = [JobAsmbl2].[Company] AND [JobHead2].[JobNum] = [JobAsmbl2].[JobNum]
    INNER JOIN Erp.JobOper as [JobOper2] ON [JobAsmbl2].[Company] = [JobOper2].[Company] AND [JobAsmbl2].[JobNum] = [JobOper2].[JobNum] AND [JobAsmbl2].[AssemblySeq] = [JobOper2].[AssemblySeq]
    WHERE [JobOper2].[OpCode] = 'HT-OVOP' AND [JobOper2].[OpComplete] = 1
      AND [JobHead2].[JobClosed] = 0 
      AND [JobHead2].[JobFirm] = 1
),

-- Farmout operations
Farmout AS (
    SELECT 
        [JobHead3].[Company] as [JobHead3_Company], 
        [JobHead3].[JobNum] as [JobHead3_JobNum], 
        [JobAsmbl3].[AssemblySeq] as [JobAsmbl3_AssemblySeq],
        1 as [Calculated_Farmout]
    FROM Erp.JobHead as [JobHead3]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl3] ON [JobHead3].[Company] = [JobAsmbl3].[Company] AND [JobHead3].[JobNum] = [JobAsmbl3].[JobNum]
    INNER JOIN Erp.JobOper as [JobOper3] ON [JobAsmbl3].[Company] = [JobOper3].[Company] AND [JobAsmbl3].[JobNum] = [JobOper3].[JobNum] AND [JobAsmbl3].[AssemblySeq] = [JobOper3].[AssemblySeq]
    INNER JOIN Erp.PORel as [PORel] ON [JobOper3].[Company] = [PORel].[Company] AND [JobOper3].[JobNum] = [PORel].[JobNum] AND [JobOper3].[AssemblySeq] = [PORel].[AssemblySeq] AND [JobOper3].[OprSeq] = [PORel].[JobSeq]
    WHERE [JobOper3].[OpCode] IN ('OMC-OVOP', 'OMP-OVOP') 
      AND [JobOper3].[OpComplete] = 0 
      AND [PORel].[OpenRelease] = 1
      AND [JobHead3].[JobClosed] = 0 
      AND [JobHead3].[JobFirm] = 1
),

-- OV Not Final operations
OVNotFinal AS (
    SELECT 
        [JobHead4].[Company] as [JobHead4_Company], 
        [JobHead4].[JobNum] as [JobHead4_JobNum], 
        [JobAsmbl4].[AssemblySeq] as [JobAsmbl4_AssemblySeq],
        1 as [Calculated_OVNotFinal]
    FROM Erp.JobHead as [JobHead4]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl4] ON [JobHead4].[Company] = [JobAsmbl4].[Company] AND [JobHead4].[JobNum] = [JobAsmbl4].[JobNum]
    INNER JOIN Erp.JobOper as [JobOper4] ON [JobAsmbl4].[Company] = [JobOper4].[Company] AND [JobAsmbl4].[JobNum] = [JobOper4].[JobNum] AND [JobAsmbl4].[AssemblySeq] = [JobOper4].[AssemblySeq]
    INNER JOIN LastOVOperations as [LastOV1] ON [JobOper4].[Company] = [LastOV1].[JobHead_Company] AND [JobOper4].[JobNum] = [LastOV1].[JobHead_JobNum] AND [JobOper4].[AssemblySeq] = [LastOV1].[JobAsmbl_AssemblySeq]
    INNER JOIN Erp.PORel as [PORel1] ON [JobOper4].[Company] = [PORel1].[Company] AND [JobOper4].[JobNum] = [PORel1].[JobNum] AND [JobOper4].[AssemblySeq] = [PORel1].[AssemblySeq] AND [JobOper4].[OprSeq] = [PORel1].[JobSeq]
    WHERE [JobOper4].[SubContract] = 1 
      AND [JobOper4].[OpComplete] = 0 
      AND [JobOper4].[OpCode] NOT IN ('OMC-OVOP', 'OMP-OVOP')
      AND [JobOper4].[OprSeq] <> [LastOV1].[Calculated_LastOVOp]
      AND [PORel1].[OpenRelease] = 1
      AND [JobHead4].[JobClosed] = 0 
      AND [JobHead4].[JobFirm] = 1
),

-- OV Final or Back operations
OVFinalOrBack AS (
    SELECT 
        [JobHead5].[Company] as [JobHead5_Company], 
        [JobHead5].[JobNum] as [JobHead5_JobNum], 
        [JobAsmbl5].[AssemblySeq] as [JobAsmbl5_AssemblySeq],
        1 as [Calculated_OVFinalOrBack]
    FROM Erp.JobHead as [JobHead5]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl5] ON [JobHead5].[Company] = [JobAsmbl5].[Company] AND [JobHead5].[JobNum] = [JobAsmbl5].[JobNum]
    INNER JOIN LastOVOperations as [LastOV2] ON [JobAsmbl5].[Company] = [LastOV2].[JobHead_Company] AND [JobAsmbl5].[JobNum] = [LastOV2].[JobHead_JobNum] AND [JobAsmbl5].[AssemblySeq] = [LastOV2].[JobAsmbl_AssemblySeq]
    INNER JOIN Erp.JobOper as [JobOper5] ON [LastOV2].[JobHead_JobNum] = [JobOper5].[JobNum] AND [LastOV2].[JobAsmbl_AssemblySeq] = [JobOper5].[AssemblySeq] AND [LastOV2].[Calculated_LastOVOp] = [JobOper5].[OprSeq]
    INNER JOIN Erp.PORel as [PORel2] ON [JobOper5].[Company] = [PORel2].[Company] AND [JobOper5].[JobNum] = [PORel2].[JobNum] AND [JobOper5].[AssemblySeq] = [PORel2].[AssemblySeq] AND [JobOper5].[OprSeq] = [PORel2].[JobSeq]
    WHERE [JobOper5].[OpCode] NOT IN ('OMC-OVOP', 'OMP-OVOP')
      AND [JobHead5].[JobClosed] = 0 
      AND [JobHead5].[JobFirm] = 1
),

-- Last operation that is not inspection (for DetailComplete logic)
LastOpNotInspection AS (
    SELECT 
        [JobOperSub].[Company] as [JobOperSub_Company], 
        [JobOperSub].[JobNum] as [JobOperSub_JobNum], 
        [JobOperSub].[AssemblySeq] as [JobOperSub_AssemblySeq],
        MAX([JobOperSub].[OprSeq]) as [Calculated_LastOpNotInsp]
    FROM Erp.JobOper as [JobOperSub]
    WHERE [JobOperSub].[OpCode] <> '9-OP'
    GROUP BY [JobOperSub].[Company], [JobOperSub].[JobNum], [JobOperSub].[AssemblySeq]
),

-- Detail completion check
DetailComplete AS (
    SELECT 
        [LastOpNotInspection1].[JobOperSub_Company] as [JobHead6_Company], 
        [LastOpNotInspection1].[JobOperSub_JobNum] as [JobHead6_JobNum], 
        [LastOpNotInspection1].[JobOperSub_AssemblySeq] as [JobAsmbl6_AssemblySeq],
        SUM([LaborDtl1].[LaborQty]) as [Calculated_TotalLaborQty],
        [JobHead6].[ProdQty] as [JobHead6_ProdQty]
    FROM LastOpNotInspection as [LastOpNotInspection1]
    INNER JOIN Erp.JobHead as [JobHead6] ON [LastOpNotInspection1].[JobOperSub_Company] = [JobHead6].[Company] AND [LastOpNotInspection1].[JobOperSub_JobNum] = [JobHead6].[JobNum]
    INNER JOIN Erp.LaborDtl as [LaborDtl1] ON [LastOpNotInspection1].[JobOperSub_Company] = [LaborDtl1].[Company] AND [LastOpNotInspection1].[JobOperSub_JobNum] = [LaborDtl1].[JobNum] AND [LastOpNotInspection1].[JobOperSub_AssemblySeq] = [LaborDtl1].[AssemblySeq] AND [LastOpNotInspection1].[Calculated_LastOpNotInsp] = [LaborDtl1].[OprSeq]
    WHERE [JobHead6].[JobClosed] = 0 
      AND [JobHead6].[JobFirm] = 1
    GROUP BY [LastOpNotInspection1].[JobOperSub_Company], [LastOpNotInspection1].[JobOperSub_JobNum], [LastOpNotInspection1].[JobOperSub_AssemblySeq], [JobHead6].[ProdQty]
),

-- Single base query for all assemblies (Change #1 - Eliminate duplication)
JobStatusBase AS (
    SELECT DISTINCT 
        [JobHead8].[Company] as [JobHead8_Company],
        [JobHead8].[JobNum] as [JobHead8_JobNum],
        [JobHead8].[PartNum] as [JobHead8_PartNum],
        [JobAsmbl8].[AssemblySeq] as [JobAsmbl8_AssemblySeq],
        [JobAsmbl8].[PartNum] as [JobAsmbl8_PartNum],
        COALESCE([MtlIssued1].[Calculated_MtlIssued], 0) as [Calculated_MtlIssued],
        COALESCE([HeatTreat1].[Calculated_BackFromHT], 0) as [Calculated_BackFromHT],
        COALESCE([Farmout1].[Calculated_Farmout], 0) as [Calculated_Farmout],
        COALESCE([OVNotFinal1].[Calculated_OVNotFinal], 0) as [Calculated_OVNotFinal],
        COALESCE([OVFinalOrBack1].[Calculated_OVFinalOrBack], 0) as [Calculated_OVFinalOrBack],
        COALESCE([LaborSummary1].[Calculated_TotalLaborHrs], 0) as [Calculated_TotalLaborHrs],
        -- Simplified CASE statements instead of nested IIF (Change #5)
        CASE 
            WHEN COALESCE([MtlIssued1].[Calculated_MtlIssued], 0) = 1 AND COALESCE([LaborSummary1].[Calculated_TotalLaborHrs], 0) > 0 THEN 1 
            ELSE 0 
        END as [Calculated_NewIP],
        CASE 
            WHEN COALESCE([HeatTreat1].[Calculated_BackFromHT], 0) = 1 AND COALESCE([LaborSummary1].[Calculated_TotalLaborHrs], 0) = 0 THEN 1 
            ELSE 0 
        END as [Calculated_NewIP2],
        CASE 
            WHEN COALESCE([DetailComplete1].[Calculated_TotalLaborQty], 0) >= COALESCE([DetailComplete1].[JobHead6_ProdQty], 0) THEN 1 
            ELSE 0 
        END as [Calculated_DetailComplete]
    FROM Erp.JobHead as [JobHead8]
    LEFT JOIN Erp.JobAsmbl as [JobAsmbl8] ON [JobHead8].[Company] = [JobAsmbl8].[Company] AND [JobHead8].[JobNum] = [JobAsmbl8].[JobNum]
    LEFT JOIN MtlIssued as [MtlIssued1] ON [JobAsmbl8].[Company] = [MtlIssued1].[JobHead1_Company] AND [JobAsmbl8].[JobNum] = [MtlIssued1].[JobHead1_JobNum] AND [JobAsmbl8].[AssemblySeq] = [MtlIssued1].[JobAsmbl1_AssemblySeq]
    LEFT JOIN HeatTreat as [HeatTreat1] ON [JobAsmbl8].[Company] = [HeatTreat1].[JobHead2_Company] AND [JobAsmbl8].[JobNum] = [HeatTreat1].[JobHead2_JobNum] AND [JobAsmbl8].[AssemblySeq] = [HeatTreat1].[JobAsmbl2_AssemblySeq]
    LEFT JOIN Farmout as [Farmout1] ON [JobAsmbl8].[Company] = [Farmout1].[JobHead3_Company] AND [JobAsmbl8].[JobNum] = [Farmout1].[JobHead3_JobNum] AND [JobAsmbl8].[AssemblySeq] = [Farmout1].[JobAsmbl3_AssemblySeq]
    LEFT JOIN OVNotFinal as [OVNotFinal1] ON [JobAsmbl8].[Company] = [OVNotFinal1].[JobHead4_Company] AND [JobAsmbl8].[JobNum] = [OVNotFinal1].[JobHead4_JobNum] AND [JobAsmbl8].[AssemblySeq] = [OVNotFinal1].[JobAsmbl4_AssemblySeq]
    LEFT JOIN OVFinalOrBack as [OVFinalOrBack1] ON [JobAsmbl8].[Company] = [OVFinalOrBack1].[JobHead5_Company] AND [JobAsmbl8].[JobNum] = [OVFinalOrBack1].[JobHead5_JobNum] AND [JobAsmbl8].[AssemblySeq] = [OVFinalOrBack1].[JobAsmbl5_AssemblySeq]
    LEFT JOIN LaborSummary as [LaborSummary1] ON [JobAsmbl8].[Company] = [LaborSummary1].[LaborDtl_Company] AND [JobAsmbl8].[JobNum] = [LaborSummary1].[LaborDtl_JobNum] AND [JobAsmbl8].[AssemblySeq] = [LaborSummary1].[LaborDtl_AssemblySeq]
    LEFT JOIN DetailComplete as [DetailComplete1] ON [JobHead8].[Company] = [DetailComplete1].[JobHead6_Company] AND [JobHead8].[JobNum] = [DetailComplete1].[JobHead6_JobNum]
    -- Early filtering (Change #6)
    WHERE [JobHead8].[JobClosed] = 0 
      AND [JobHead8].[JobFirm] = 1
      AND ([DetailComplete1].[JobAsmbl6_AssemblySeq] IS NULL OR [JobAsmbl8].[AssemblySeq] = [DetailComplete1].[JobAsmbl6_AssemblySeq])
),

-- Calculate InProcess status with simplified logic
JobStatusWithInProcess AS (
    SELECT 
        [JobStatusBase1].[JobHead8_Company] as [JobStatusBase1_JobHead8_Company],
        [JobStatusBase1].[JobHead8_JobNum] as [JobStatusBase1_JobHead8_JobNum],
        [JobStatusBase1].[JobHead8_PartNum] as [JobStatusBase1_JobHead8_PartNum],
        [JobStatusBase1].[JobAsmbl8_AssemblySeq] as [JobStatusBase1_JobAsmbl8_AssemblySeq],
        [JobStatusBase1].[JobAsmbl8_PartNum] as [JobStatusBase1_JobAsmbl8_PartNum],
        [JobStatusBase1].[Calculated_MtlIssued] as [Calculated_MtlIssued],
        [JobStatusBase1].[Calculated_BackFromHT] as [Calculated_BackFromHT],
        [JobStatusBase1].[Calculated_Farmout] as [Calculated_Farmout],
        [JobStatusBase1].[Calculated_OVNotFinal] as [Calculated_OVNotFinal],
        [JobStatusBase1].[Calculated_OVFinalOrBack] as [Calculated_OVFinalOrBack],
        [JobStatusBase1].[Calculated_TotalLaborHrs] as [Calculated_TotalLaborHrs],
        [JobStatusBase1].[Calculated_NewIP] as [Calculated_NewIP],
        [JobStatusBase1].[Calculated_NewIP2] as [Calculated_NewIP2],
        [JobStatusBase1].[Calculated_DetailComplete] as [Calculated_DetailComplete],
        CASE 
            WHEN ([JobStatusBase1].[Calculated_NewIP] = 1 OR [JobStatusBase1].[Calculated_NewIP2] = 1) THEN 1 
            ELSE 0 
        END as [Calculated_InProcess]
    FROM JobStatusBase as [JobStatusBase1]
),

-- Calculate status for each assembly
JobStatusWithStatus AS (
    SELECT 
        [JobStatusWithInProcess1].[JobStatusBase1_JobHead8_Company] as [JobStatusWithInProcess1_JobHead8_Company],
        [JobStatusWithInProcess1].[JobStatusBase1_JobHead8_JobNum] as [JobStatusWithInProcess1_JobHead8_JobNum],
        [JobStatusWithInProcess1].[JobStatusBase1_JobHead8_PartNum] as [JobStatusWithInProcess1_JobHead8_PartNum],
        [JobStatusWithInProcess1].[JobStatusBase1_JobAsmbl8_AssemblySeq] as [JobStatusWithInProcess1_JobAsmbl8_AssemblySeq],
        [JobStatusWithInProcess1].[JobStatusBase1_JobAsmbl8_PartNum] as [JobStatusWithInProcess1_JobAsmbl8_PartNum],
        [JobStatusWithInProcess1].[Calculated_MtlIssued] as [Calculated_MtlIssued],
        [JobStatusWithInProcess1].[Calculated_BackFromHT] as [Calculated_BackFromHT],
        [JobStatusWithInProcess1].[Calculated_Farmout] as [Calculated_Farmout],
        [JobStatusWithInProcess1].[Calculated_OVNotFinal] as [Calculated_OVNotFinal],
        [JobStatusWithInProcess1].[Calculated_OVFinalOrBack] as [Calculated_OVFinalOrBack],
        [JobStatusWithInProcess1].[Calculated_TotalLaborHrs] as [Calculated_TotalLaborHrs],
        [JobStatusWithInProcess1].[Calculated_NewIP] as [Calculated_NewIP],
        [JobStatusWithInProcess1].[Calculated_NewIP2] as [Calculated_NewIP2],
        [JobStatusWithInProcess1].[Calculated_DetailComplete] as [Calculated_DetailComplete],
        [JobStatusWithInProcess1].[Calculated_InProcess] as [Calculated_InProcess],
        CASE
            WHEN [JobStatusWithInProcess1].[Calculated_OVFinalOrBack] = 1 THEN 6
            WHEN [JobStatusWithInProcess1].[Calculated_OVNotFinal] = 1 THEN 5
            WHEN [JobStatusWithInProcess1].[Calculated_InProcess] = 1 THEN 4
            WHEN [JobStatusWithInProcess1].[Calculated_Farmout] = 1 THEN 3
            WHEN [JobStatusWithInProcess1].[Calculated_BackFromHT] = 1 THEN 2
            WHEN [JobStatusWithInProcess1].[Calculated_MtlIssued] = 1 THEN 1
            ELSE 0
        END as [Calculated_Status]
    FROM JobStatusWithInProcess as [JobStatusWithInProcess1]
),

-- Top level status (AssemblySeq = 0)
TopStatus AS (
    SELECT 
        [JobStatusWithStatus1].[JobStatusWithInProcess1_JobHead8_Company] as [TopStatus_JobHead8_Company],
        [JobStatusWithStatus1].[JobStatusWithInProcess1_JobHead8_JobNum] as [TopStatus_JobHead8_JobNum],
        [JobStatusWithStatus1].[Calculated_Status] as [Calculated_TopStatus]
    FROM JobStatusWithStatus as [JobStatusWithStatus1]
    WHERE [JobStatusWithStatus1].[JobStatusWithInProcess1_JobAsmbl8_AssemblySeq] = 0
),

-- Assembly level status (AssemblySeq <> 0, incomplete only)
AsmStatus AS (
    SELECT 
        [JobStatusWithStatus2].[JobStatusWithInProcess1_JobHead8_JobNum] as [AsmStatus_JobHead8_JobNum],
        [JobStatusWithStatus2].[Calculated_Status] as [AsmStatus_Calculated_Status]
    FROM JobStatusWithStatus as [JobStatusWithStatus2]
    WHERE [JobStatusWithStatus2].[Calculated_DetailComplete] = 0 
      AND [JobStatusWithStatus2].[JobStatusWithInProcess1_JobAsmbl8_AssemblySeq] <> 0
)

-- Final result with fallback logic
SELECT  
    [TopStatus1].[TopStatus_JobHead8_Company] as [JobHead8_Company],
    COALESCE([AsmStatus1].[AsmStatus_JobHead8_JobNum], [TopStatus1].[TopStatus_JobHead8_JobNum]) as [Calculated_JobNum],
    CASE
        WHEN [TopStatus1].[Calculated_TopStatus] = 0 THEN COALESCE([AsmStatus1].[AsmStatus_Calculated_Status], 0)
        WHEN [AsmStatus1].[AsmStatus_Calculated_Status] < [TopStatus1].[Calculated_TopStatus] THEN [AsmStatus1].[AsmStatus_Calculated_Status]
        ELSE [TopStatus1].[Calculated_TopStatus]
    END as [Calculated_Status]
FROM TopStatus as [TopStatus1]
LEFT JOIN AsmStatus as [AsmStatus1] ON [TopStatus1].[TopStatus_JobHead8_JobNum] = [AsmStatus1].[AsmStatus_JobHead8_JobNum];