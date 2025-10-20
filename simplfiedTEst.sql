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