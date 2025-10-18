-- Optimized JobStatus Query
-- Performance improvements: eliminate duplication, consolidate subqueries, optimize labor aggregations, 
-- simplify IIF statements, add early filtering
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
        [jh].[Company] as [JobHead_Company], 
        [jh].[JobNum] as [JobHead_JobNum], 
        [ja].[AssemblySeq] as [JobAsmbl_AssemblySeq],
        MAX([jo].[OprSeq]) as [Calculated_LastOVOp]
    FROM Erp.JobHead as [jh]
    INNER JOIN Erp.JobAsmbl as [ja] ON [jh].[Company] = [ja].[Company] AND [jh].[JobNum] = [ja].[JobNum]
    INNER JOIN Erp.JobOper as [jo] ON [ja].[Company] = [jo].[Company] AND [ja].[JobNum] = [jo].[JobNum] AND [ja].[AssemblySeq] = [jo].[AssemblySeq]
    WHERE [jo].[SubContract] = 1 
      AND [jo].[OpCode] NOT IN ('OMC-OVOP', 'OMP-OVOP')
    GROUP BY [jh].[Company], [jh].[JobNum], [ja].[AssemblySeq]
),

-- Material issued status
MtlIssued AS (
    SELECT DISTINCT 
        [jh].[Company] as [JobHead_Company], 
        [jh].[JobNum] as [JobHead_JobNum], 
        [ja].[AssemblySeq] as [JobAsmbl_AssemblySeq],
        1 as [Calculated_MtlIssued]
    FROM Erp.JobHead as [jh]
    INNER JOIN Erp.JobAsmbl as [ja] ON [jh].[Company] = [ja].[Company] AND [jh].[JobNum] = [ja].[JobNum]
    INNER JOIN Erp.PartTran as [pt] ON [ja].[Company] = [pt].[Company] AND [ja].[JobNum] = [pt].[JobNum] AND [ja].[AssemblySeq] = [pt].[AssemblySeq]
    WHERE [pt].[TranClass] = 'I' AND [pt].[TranQty] > 0
),

-- Heat treatment status
HeatTreat AS (
    SELECT 
        [jh].[Company] as [JobHead_Company], 
        [jh].[JobNum] as [JobHead_JobNum], 
        [ja].[AssemblySeq] as [JobAsmbl_AssemblySeq],
        1 as [Calculated_BackFromHT]
    FROM Erp.JobHead as [jh]
    INNER JOIN Erp.JobAsmbl as [ja] ON [jh].[Company] = [ja].[Company] AND [jh].[JobNum] = [ja].[JobNum]
    INNER JOIN Erp.JobOper as [jo] ON [ja].[Company] = [jo].[Company] AND [ja].[JobNum] = [jo].[JobNum] AND [ja].[AssemblySeq] = [jo].[AssemblySeq]
    WHERE [jo].[OpCode] = 'HT-OVOP' AND [jo].[OpComplete] = 1
),

-- Farmout operations
Farmout AS (
    SELECT 
        [jh2].[Company] as [JobHead2_Company], 
        [jh2].[JobNum] as [JobHead2_JobNum], 
        [ja2].[AssemblySeq] as [JobAsmbl2_AssemblySeq],
        1 as [Calculated_Farmout]
    FROM Erp.JobHead as [jh2]
    INNER JOIN Erp.JobAsmbl as [ja2] ON [jh2].[Company] = [ja2].[Company] AND [jh2].[JobNum] = [ja2].[JobNum]
    INNER JOIN Erp.JobOper as [jo2] ON [ja2].[Company] = [jo2].[Company] AND [ja2].[JobNum] = [jo2].[JobNum] AND [ja2].[AssemblySeq] = [jo2].[AssemblySeq]
    INNER JOIN Erp.PORel as [pr] ON [jo2].[Company] = [pr].[Company] AND [jo2].[JobNum] = [pr].[JobNum] AND [jo2].[AssemblySeq] = [pr].[AssemblySeq] AND [jo2].[OprSeq] = [pr].[JobSeq]
    WHERE [jo2].[OpCode] IN ('OMC-OVOP', 'OMP-OVOP') 
      AND [jo2].[OpComplete] = 0 
      AND [pr].[OpenRelease] = 1
),

-- OV Not Final operations
OVNotFinal AS (
    SELECT 
        [jh3].[Company] as [JobHead3_Company], 
        [jh3].[JobNum] as [JobHead3_JobNum], 
        [ja3].[AssemblySeq] as [JobAsmbl3_AssemblySeq],
        1 as [Calculated_OVNotFinal]
    FROM Erp.JobHead as [jh3]
    INNER JOIN Erp.JobAsmbl as [ja3] ON [jh3].[Company] = [ja3].[Company] AND [jh3].[JobNum] = [ja3].[JobNum]
    INNER JOIN Erp.JobOper as [jo3] ON [ja3].[Company] = [jo3].[Company] AND [ja3].[JobNum] = [jo3].[JobNum] AND [ja3].[AssemblySeq] = [jo3].[AssemblySeq]
    INNER JOIN LastOVOperations as [lov1] ON [jo3].[Company] = [lov1].[JobHead_Company] AND [jo3].[JobNum] = [lov1].[JobHead_JobNum] AND [jo3].[AssemblySeq] = [lov1].[JobAsmbl_AssemblySeq]
    INNER JOIN Erp.PORel as [pr1] ON [jo3].[Company] = [pr1].[Company] AND [jo3].[JobNum] = [pr1].[JobNum] AND [jo3].[AssemblySeq] = [pr1].[AssemblySeq] AND [jo3].[OprSeq] = [pr1].[JobSeq]
    WHERE [jo3].[SubContract] = 1 
      AND [jo3].[OpComplete] = 0 
      AND [jo3].[OpCode] NOT IN ('OMC-OVOP', 'OMP-OVOP')
      AND [jo3].[OprSeq] <> [lov1].[Calculated_LastOVOp]
      AND [pr1].[OpenRelease] = 1
),

-- OV Final or Back operations
OVFinalOrBack AS (
    SELECT 
        [jh5].[Company] as [JobHead5_Company], 
        [jh5].[JobNum] as [JobHead5_JobNum], 
        [ja5].[AssemblySeq] as [JobAsmbl5_AssemblySeq],
        1 as [Calculated_OVFinalOrBack]
    FROM Erp.JobHead as [jh5]
    INNER JOIN Erp.JobAsmbl as [ja5] ON [jh5].[Company] = [ja5].[Company] AND [jh5].[JobNum] = [ja5].[JobNum]
    INNER JOIN LastOVOperations as [lov] ON [ja5].[Company] = [lov].[JobHead_Company] AND [ja5].[JobNum] = [lov].[JobHead_JobNum] AND [ja5].[AssemblySeq] = [lov].[JobAsmbl_AssemblySeq]
    INNER JOIN Erp.JobOper as [jo5] ON [lov].[JobHead_JobNum] = [jo5].[JobNum] AND [lov].[JobAsmbl_AssemblySeq] = [jo5].[AssemblySeq] AND [lov].[Calculated_LastOVOp] = [jo5].[OprSeq]
    INNER JOIN Erp.PORel as [pr2] ON [jo5].[Company] = [pr2].[Company] AND [jo5].[JobNum] = [pr2].[JobNum] AND [jo5].[AssemblySeq] = [pr2].[AssemblySeq] AND [jo5].[OprSeq] = [pr2].[JobSeq]
    WHERE [jo5].[OpCode] NOT IN ('OMC-OVOP', 'OMP-OVOP')
),

-- Detail completion check
DetailComplete AS (
    SELECT 
        [jh7].[Company] as [JobHead7_Company], 
        [jh7].[JobNum] as [JobHead7_JobNum], 
        [ja7].[AssemblySeq] as [JobAsmbl7_AssemblySeq],
        SUM([ld1].[LaborQty]) as [Calculated_TotalLaborQty],
        [jh7].[ProdQty] as [JobHead7_ProdQty]
    FROM Erp.JobHead as [jh7]
    INNER JOIN Erp.JobAsmbl as [ja7] ON [jh7].[Company] = [ja7].[Company] AND [jh7].[JobNum] = [ja7].[JobNum]
    INNER JOIN (
        SELECT 
            [JobOper].[Company] as [JobOper_Company], 
            [JobOper].[JobNum] as [JobOper_JobNum], 
            [JobOper].[AssemblySeq] as [JobOper_AssemblySeq],
            MAX([JobOper].[OprSeq]) as [Calculated_LastOpNotInsp]
        FROM Erp.JobOper as [JobOper]
        WHERE [JobOper].[OpCode] <> '9-OP'
        GROUP BY [JobOper].[Company], [JobOper].[JobNum], [JobOper].[AssemblySeq]
    ) as [lo] ON [jh7].[Company] = [lo].[JobOper_Company] AND [jh7].[JobNum] = [lo].[JobOper_JobNum] AND [ja7].[AssemblySeq] = [lo].[JobOper_AssemblySeq]
    INNER JOIN Erp.LaborDtl as [ld1] ON [lo].[JobOper_Company] = [ld1].[Company] AND [lo].[JobOper_JobNum] = [ld1].[JobNum] AND [lo].[JobOper_AssemblySeq] = [ld1].[AssemblySeq] AND [lo].[Calculated_LastOpNotInsp] = [ld1].[OprSeq]
    GROUP BY [jh7].[Company], [jh7].[JobNum], [ja7].[AssemblySeq], [jh7].[ProdQty]
),

-- Single base query for all assemblies (Change #1 - Eliminate duplication)
JobStatusBase AS (
    SELECT DISTINCT 
        [jh6].[Company] as [JobHead6_Company],
        [jh6].[JobNum] as [JobHead6_JobNum],
        [jh6].[PartNum] as [JobHead6_PartNum],
        [ja6].[AssemblySeq] as [JobAsmbl6_AssemblySeq],
        [ja6].[PartNum] as [JobAsmbl6_PartNum],
        COALESCE([mi].[Calculated_MtlIssued], 0) as [Calculated_MtlIssued],
        COALESCE([ht].[Calculated_BackFromHT], 0) as [Calculated_BackFromHT],
        COALESCE([fo].[Calculated_Farmout], 0) as [Calculated_Farmout],
        COALESCE([ovnf].[Calculated_OVNotFinal], 0) as [Calculated_OVNotFinal],
        COALESCE([ovfb].[Calculated_OVFinalOrBack], 0) as [Calculated_OVFinalOrBack],
        COALESCE([ls].[Calculated_TotalLaborHrs], 0) as [Calculated_TotalLaborHrs],
        -- Simplified CASE statements instead of nested IIF (Change #5)
        CASE 
            WHEN COALESCE([mi].[Calculated_MtlIssued], 0) = 1 AND COALESCE([ls].[Calculated_TotalLaborHrs], 0) > 0 THEN 1 
            ELSE 0 
        END as [Calculated_NewIP],
        CASE 
            WHEN COALESCE([ht].[Calculated_BackFromHT], 0) = 1 AND COALESCE([ls].[Calculated_TotalLaborHrs], 0) = 0 THEN 1 
            ELSE 0 
        END as [Calculated_NewIP2],
        CASE 
            WHEN COALESCE([dc].[Calculated_TotalLaborQty], 0) >= [jh6].[ProdQty] THEN 1 
            ELSE 0 
        END as [Calculated_DetailComplete]
    FROM Erp.JobHead as [jh6]
    LEFT JOIN Erp.JobAsmbl as [ja6] ON [jh6].[Company] = [ja6].[Company] AND [jh6].[JobNum] = [ja6].[JobNum]
    LEFT JOIN MtlIssued as [mi] ON [ja6].[Company] = [mi].[JobHead_Company] AND [ja6].[JobNum] = [mi].[JobHead_JobNum] AND [ja6].[AssemblySeq] = [mi].[JobAsmbl_AssemblySeq]
    LEFT JOIN HeatTreat as [ht] ON [ja6].[Company] = [ht].[JobHead_Company] AND [ja6].[JobNum] = [ht].[JobHead_JobNum] AND [ja6].[AssemblySeq] = [ht].[JobAsmbl_AssemblySeq]
    LEFT JOIN Farmout as [fo] ON [ja6].[Company] = [fo].[JobHead2_Company] AND [ja6].[JobNum] = [fo].[JobHead2_JobNum] AND [ja6].[AssemblySeq] = [fo].[JobAsmbl2_AssemblySeq]
    LEFT JOIN OVNotFinal as [ovnf] ON [ja6].[Company] = [ovnf].[JobHead3_Company] AND [ja6].[JobNum] = [ovnf].[JobHead3_JobNum] AND [ja6].[AssemblySeq] = [ovnf].[JobAsmbl3_AssemblySeq]
    LEFT JOIN OVFinalOrBack as [ovfb] ON [ja6].[Company] = [ovfb].[JobHead5_Company] AND [ja6].[JobNum] = [ovfb].[JobHead5_JobNum] AND [ja6].[AssemblySeq] = [ovfb].[JobAsmbl5_AssemblySeq]
    LEFT JOIN LaborSummary as [ls] ON [ja6].[Company] = [ls].[LaborDtl_Company] AND [ja6].[JobNum] = [ls].[LaborDtl_JobNum] AND [ja6].[AssemblySeq] = [ls].[LaborDtl_AssemblySeq]
    LEFT JOIN DetailComplete as [dc] ON [jh6].[Company] = [dc].[JobHead7_Company] AND [jh6].[JobNum] = [dc].[JobHead7_JobNum] AND [ja6].[AssemblySeq] = [dc].[JobAsmbl7_AssemblySeq]
    -- Early filtering (Change #6)
    WHERE [jh6].[JobClosed] = 0 
      AND [jh6].[JobFirm] = 1
),

-- Calculate InProcess status with simplified logic
JobStatusWithInProcess AS (
    SELECT *,
        CASE 
            WHEN ([Calculated_NewIP] = 1 OR [Calculated_NewIP2] = 1) THEN 1 
            ELSE 0 
        END as [Calculated_InProcess]
    FROM JobStatusBase
),

-- Calculate status for each assembly
JobStatusWithStatus AS (
    SELECT *,
        CASE
            WHEN [Calculated_OVFinalOrBack] = 1 THEN 6
            WHEN [Calculated_OVNotFinal] = 1 THEN 5
            WHEN [Calculated_InProcess] = 1 THEN 4
            WHEN [Calculated_Farmout] = 1 THEN 3
            WHEN [Calculated_BackFromHT] = 1 THEN 2
            WHEN [Calculated_MtlIssued] = 1 THEN 1
            ELSE 0
        END as [Calculated_Status]
    FROM JobStatusWithInProcess
),

-- Top level status (AssemblySeq = 0)
TopStatus AS (
    SELECT 
        [JobHead6_Company],
        [JobHead6_JobNum],
        [Calculated_Status] as [Calculated_TopStatus]
    FROM JobStatusWithStatus
    WHERE [JobAsmbl6_AssemblySeq] = 0
),

-- Assembly level status (AssemblySeq <> 0, incomplete only)
AsmStatus AS (
    SELECT 
        [JobHead6_JobNum],
        [Calculated_Status]
    FROM JobStatusWithStatus
    WHERE [Calculated_DetailComplete] = 0 
      AND [JobAsmbl6_AssemblySeq] <> 0
)

-- Final result with fallback logic
SELECT  
    [ts].[JobHead6_Company] as [JobHead6_Company],
    COALESCE([asms].[JobHead6_JobNum], [ts].[JobHead6_JobNum]) as [Calculated_JobNum],
    CASE
        WHEN [ts].[Calculated_TopStatus] = 0 THEN COALESCE([asms].[Calculated_Status], 0)
        WHEN [asms].[Calculated_Status] < [ts].[Calculated_TopStatus] THEN [asms].[Calculated_Status]
        ELSE [ts].[Calculated_TopStatus]
    END as [Calculated_Status]
FROM TopStatus as [ts]
LEFT JOIN AsmStatus as [asms] ON [ts].[JobHead6_JobNum] = [asms].[JobHead6_JobNum];