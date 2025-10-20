-- Simplified test query demonstrating core JobStatus optimization concept
-- Shows single-calculation, multiple-filter pattern instead of duplicate logic
-- IMPORTANT: Calculated fields should NOT be prefixed with table aliases
-- IMPORTANT: Only base table fields should use TableAlias_FieldName pattern
-- baq_JobStatus_SimpleTest5
WITH JobStatusBase AS (
    SELECT 
        [JobHead].[Company] as [JobHead_Company],
        [JobHead].[JobNum] as [JobHead_JobNum],
        [JobAsmbl].[AssemblySeq] as [JobAsmbl_AssemblySeq],
        [JobAsmbl].[JobComplete] as [JobAsmbl_JobComplete],
        
        -- Calculated fields: Keep Calculated_ prefix, do NOT add table alias prefix
        -- These represent derived/computed values, not direct table fields
        CASE WHEN [JobAsmbl].[AssemblySeq] = 0 THEN 1 ELSE 0 END as [Calculated_MtlIssued],
        CASE WHEN [JobHead].[JobEngineered] = 1 THEN 1 ELSE 0 END as [Calculated_BackFromHT],
        CASE WHEN [JobHead].[JobReleased] = 1 THEN 1 ELSE 0 END as [Calculated_InProcess],
        CASE WHEN [JobAsmbl].[AssemblySeq] > 0 THEN 1 ELSE 0 END as [Calculated_Farmout],
        CASE WHEN [JobHead].[JobComplete] = 1 THEN 1 ELSE 0 END as [Calculated_OVFinalOrBack],
        CASE WHEN [JobAsmbl].[JobComplete] = 0 THEN 1 ELSE 0 END as [Calculated_OVNotFinal],
        CASE WHEN [JobAsmbl].[JobComplete] = 1 THEN 1 ELSE 0 END as [Calculated_DetailComplete]

    FROM Erp.JobHead AS [JobHead] 
    INNER JOIN Erp.JobAsmbl AS [JobAsmbl] ON [JobHead].[Company] = [JobAsmbl].[Company] 
        AND [JobHead].[JobNum] = [JobAsmbl].[JobNum]
    
    -- Early filtering for performance (key optimization)
    WHERE [JobHead].[JobClosed] = 0 AND [JobHead].[JobFirm] = 1
),

-- Calculate status for each assembly (single calculation)
-- PRE-APPLYING TOOL PREFIX LOGIC: Use the prefixed names that tool will create
JobStatusWithStatus AS (
    SELECT 
        -- Pre-apply prefixes: StatusBase + original field names
        [StatusBase].[JobHead_Company] as [StatusBase_JobHead_Company],
        [StatusBase].[JobHead_JobNum] as [StatusBase_JobHead_JobNum], 
        [StatusBase].[JobAsmbl_AssemblySeq] as [StatusBase_JobAsmbl_AssemblySeq],
        [StatusBase].[JobAsmbl_JobComplete] as [StatusBase_JobAsmbl_JobComplete],
        -- Calculated fields: apply prefix to match tool behavior
        [StatusBase].[Calculated_MtlIssued] as [StatusBase_Calculated_MtlIssued],
        [StatusBase].[Calculated_BackFromHT] as [StatusBase_Calculated_BackFromHT],
        [StatusBase].[Calculated_InProcess] as [StatusBase_Calculated_InProcess],
        [StatusBase].[Calculated_Farmout] as [StatusBase_Calculated_Farmout],
        [StatusBase].[Calculated_OVFinalOrBack] as [StatusBase_Calculated_OVFinalOrBack],
        [StatusBase].[Calculated_OVNotFinal] as [StatusBase_Calculated_OVNotFinal],
        [StatusBase].[Calculated_DetailComplete] as [StatusBase_Calculated_DetailComplete],
        -- New calculated field: tool will likely keep this as-is
        CASE
            WHEN [StatusBase].[Calculated_OVFinalOrBack] = 1 THEN 6
            WHEN [StatusBase].[Calculated_OVNotFinal] = 1 THEN 5
            WHEN [StatusBase].[Calculated_InProcess] = 1 THEN 4
            WHEN [StatusBase].[Calculated_Farmout] = 1 THEN 3
            WHEN [StatusBase].[Calculated_BackFromHT] = 1 THEN 2
            WHEN [StatusBase].[Calculated_MtlIssued] = 1 THEN 1
            ELSE 0
        END as [Calculated_Status]
    FROM JobStatusBase as [StatusBase]
),

-- Top level status (AssemblySeq = 0) - filter on single calculation
TopStatus AS (
    SELECT 
        -- Pre-apply prefixes to match what tool will create
        [WithStatus1].[StatusBase_JobHead_Company] as [WithStatus1_StatusBase_JobHead_Company],
        [WithStatus1].[StatusBase_JobHead_JobNum] as [WithStatus1_StatusBase_JobHead_JobNum],
        [WithStatus1].[Calculated_Status] as [Calculated_TopStatus]
    FROM JobStatusWithStatus as [WithStatus1]
    WHERE [WithStatus1].[StatusBase_JobAsmbl_AssemblySeq] = 0
),

-- Assembly level status (AssemblySeq <> 0, incomplete only) - filter on single calculation
AsmStatus AS (
    SELECT 
        -- Pre-apply prefixes to match what tool will create
        [WithStatus2].[StatusBase_JobHead_JobNum] as [WithStatus2_StatusBase_JobHead_JobNum],
        [WithStatus2].[Calculated_Status] as [WithStatus2_Calculated_Status]
    FROM JobStatusWithStatus as [WithStatus2]
    WHERE [WithStatus2].[StatusBase_Calculated_DetailComplete] = 0 
      AND [WithStatus2].[StatusBase_JobAsmbl_AssemblySeq] <> 0
)

-- Final result with fallback logic
-- PRE-APPLYING TOOL LOGIC: Use the exact prefixed names the tool will create
SELECT  
    [TopLevel].[WithStatus1_StatusBase_JobHead_Company] as [TopLevel_WithStatus1_StatusBase_JobHead_Company],
    COALESCE([AsmLevel].[WithStatus2_StatusBase_JobHead_JobNum], [TopLevel].[WithStatus1_StatusBase_JobHead_JobNum]) as [Calculated_JobNum],
    CASE
        WHEN [TopLevel].[Calculated_TopStatus] = 0 THEN COALESCE([AsmLevel].[WithStatus2_Calculated_Status], 0)
        WHEN [AsmLevel].[WithStatus2_Calculated_Status] < [TopLevel].[Calculated_TopStatus] THEN [AsmLevel].[WithStatus2_Calculated_Status]
        ELSE [TopLevel].[Calculated_TopStatus]
    END as [Calculated_Status]
FROM TopStatus as [TopLevel]
LEFT JOIN AsmStatus as [AsmLevel] ON [TopLevel].[WithStatus1_StatusBase_JobHead_JobNum] = [AsmLevel].[WithStatus2_StatusBase_JobHead_JobNum];