-- Optimized JobStatus Query
-- Performance improvements: eliminate duplication, consolidate subqueries, optimize labor aggregations, 
-- simplify IIF statements, add early filtering
--correlation error: 5f230725-6c1a-40e3-b31f-a6769b8b6a42
WITH 
-- Consolidated labor aggregations (Change #4)
LaborSummary AS (
    SELECT 
        Company, JobNum, AssemblySeq,
        SUM(LaborHrs) as TotalLaborHrs,
        SUM(LaborQty) as TotalLaborQty
    FROM Erp.LaborDtl
    GROUP BY Company, JobNum, AssemblySeq
),

-- Reusable LastOVOp logic (Change #3)
LastOVOperations AS (
    SELECT 
        Company, JobNum, AssemblySeq,
        MAX(OprSeq) as LastOVOp
    FROM Erp.JobHead jh
    INNER JOIN Erp.JobAsmbl ja ON jh.Company = ja.Company AND jh.JobNum = ja.JobNum
    INNER JOIN Erp.JobOper jo ON ja.Company = jo.Company AND ja.JobNum = jo.JobNum AND ja.AssemblySeq = jo.AssemblySeq
    WHERE jo.SubContract = 1 
      AND jo.OpCode NOT IN ('OMC-OVOP', 'OMP-OVOP')
    GROUP BY Company, JobNum, AssemblySeq
),

-- Material issued status
MtlIssued AS (
    SELECT DISTINCT 
        JobNum, AssemblySeq,
        1 as Calculated_MtlIssued
    FROM Erp.JobHead jh
    INNER JOIN Erp.JobAsmbl ja ON jh.Company = ja.Company AND jh.JobNum = ja.JobNum
    INNER JOIN Erp.PartTran pt ON ja.Company = pt.Company AND ja.JobNum = pt.JobNum AND ja.AssemblySeq = pt.AssemblySeq
    WHERE pt.TranClass = 'I' AND pt.TranQty > 0
),

-- Heat treatment status
HeatTreat AS (
    SELECT 
        JobNum, AssemblySeq,
        1 as Calculated_BackFromHT
    FROM Erp.JobHead jh
    INNER JOIN Erp.JobAsmbl ja ON jh.Company = ja.Company AND jh.JobNum = ja.JobNum
    INNER JOIN Erp.JobOper jo ON ja.Company = jo.Company AND ja.JobNum = jo.JobNum AND ja.AssemblySeq = jo.AssemblySeq
    WHERE jo.OpCode = 'HT-OVOP' AND jo.OpComplete = 1
),

-- Farmout operations
Farmout AS (
    SELECT 
        jh2.JobNum, ja2.AssemblySeq,
        1 as Calculated_Farmout
    FROM Erp.JobHead jh2
    INNER JOIN Erp.JobAsmbl ja2 ON jh2.Company = ja2.Company AND jh2.JobNum = ja2.JobNum
    INNER JOIN Erp.JobOper jo2 ON ja2.Company = jo2.Company AND ja2.JobNum = jo2.JobNum AND ja2.AssemblySeq = jo2.AssemblySeq
    INNER JOIN Erp.PORel pr ON jo2.Company = pr.Company AND jo2.JobNum = pr.JobNum AND jo2.AssemblySeq = pr.AssemblySeq AND jo2.OprSeq = pr.JobSeq
    WHERE jo2.OpCode IN ('OMC-OVOP', 'OMP-OVOP') 
      AND jo2.OpComplete = 0 
      AND pr.OpenRelease = 1
),

-- OV Not Final operations
OVNotFinal AS (
    SELECT 
        jh3.JobNum, ja3.AssemblySeq,
        1 as Calculated_OVNotFinal
    FROM Erp.JobHead jh3
    INNER JOIN Erp.JobAsmbl ja3 ON jh3.Company = ja3.Company AND jh3.JobNum = ja3.JobNum
    INNER JOIN Erp.JobOper jo3 ON ja3.Company = jo3.Company AND ja3.JobNum = jo3.JobNum AND ja3.AssemblySeq = jo3.AssemblySeq
    INNER JOIN LastOVOperations lov1 ON jo3.JobNum = lov1.JobNum AND jo3.AssemblySeq = lov1.AssemblySeq
    INNER JOIN Erp.PORel pr1 ON jo3.Company = pr1.Company AND jo3.JobNum = pr1.JobNum AND jo3.AssemblySeq = pr1.AssemblySeq AND jo3.OprSeq = pr1.JobSeq
    WHERE jo3.SubContract = 1 
      AND jo3.OpComplete = 0 
      AND jo3.OpCode NOT IN ('OMC-OVOP', 'OMP-OVOP')
      AND jo3.OprSeq <> lov1.LastOVOp
      AND pr1.OpenRelease = 1
),

-- OV Final or Back operations
OVFinalOrBack AS (
    SELECT 
        jh5.JobNum, ja5.AssemblySeq,
        1 as Calculated_OVFinalOrBack
    FROM Erp.JobHead jh5
    INNER JOIN Erp.JobAsmbl ja5 ON jh5.Company = ja5.Company AND jh5.JobNum = ja5.JobNum
    INNER JOIN LastOVOperations lov ON ja5.JobNum = lov.JobNum AND ja5.AssemblySeq = lov.AssemblySeq
    INNER JOIN Erp.JobOper jo5 ON lov.JobNum = jo5.JobNum AND lov.AssemblySeq = jo5.AssemblySeq AND lov.LastOVOp = jo5.OprSeq
    INNER JOIN Erp.PORel pr2 ON jo5.Company = pr2.Company AND jo5.JobNum = pr2.JobNum AND jo5.AssemblySeq = pr2.AssemblySeq AND jo5.OprSeq = pr2.JobSeq
    WHERE jo5.OpCode NOT IN ('OMC-OVOP', 'OMP-OVOP')
),

-- Detail completion check
DetailComplete AS (
    SELECT 
        jh7.Company, jh7.JobNum, ja7.AssemblySeq,
        SUM(ld1.LaborQty) as TotalLaborQty,
        jh7.ProdQty
    FROM Erp.JobHead jh7
    INNER JOIN Erp.JobAsmbl ja7 ON jh7.Company = ja7.Company AND jh7.JobNum = ja7.JobNum
    INNER JOIN (
        SELECT 
            Company, JobNum, AssemblySeq,
            MAX(OprSeq) as LastOpNotInsp
        FROM Erp.JobOper
        WHERE OpCode <> '9-OP'
        GROUP BY Company, JobNum, AssemblySeq
    ) lo ON jh7.Company = lo.Company AND jh7.JobNum = lo.JobNum AND ja7.AssemblySeq = lo.AssemblySeq
    INNER JOIN Erp.LaborDtl ld1 ON lo.Company = ld1.Company AND lo.JobNum = ld1.JobNum AND lo.AssemblySeq = ld1.AssemblySeq AND lo.LastOpNotInsp = ld1.OprSeq
    GROUP BY jh7.Company, jh7.JobNum, ja7.AssemblySeq, jh7.ProdQty
),

-- Single base query for all assemblies (Change #1 - Eliminate duplication)
JobStatusBase AS (
    SELECT DISTINCT 
        jh6.Company as JobHead6_Company,
        jh6.JobNum as JobHead6_JobNum,
        jh6.PartNum as JobHead6_PartNum,
        ja6.AssemblySeq as JobAsmbl6_AssemblySeq,
        ja6.PartNum as JobAsmbl6_PartNum,
        COALESCE(mi.Calculated_MtlIssued, 0) as Calculated_MtlIssued,
        COALESCE(ht.Calculated_BackFromHT, 0) as Calculated_BackFromHT,
        COALESCE(fo.Calculated_Farmout, 0) as Calculated_Farmout,
        COALESCE(ovnf.Calculated_OVNotFinal, 0) as Calculated_OVNotFinal,
        COALESCE(ovfb.Calculated_OVFinalOrBack, 0) as Calculated_OVFinalOrBack,
        COALESCE(ls.TotalLaborHrs, 0) as TotalLaborHrs,
        -- Simplified CASE statements instead of nested IIF (Change #5)
        CASE 
            WHEN COALESCE(mi.Calculated_MtlIssued, 0) = 1 AND COALESCE(ls.TotalLaborHrs, 0) > 0 THEN 1 
            ELSE 0 
        END as Calculated_NewIP,
        CASE 
            WHEN COALESCE(ht.Calculated_BackFromHT, 0) = 1 AND COALESCE(ls.TotalLaborHrs, 0) = 0 THEN 1 
            ELSE 0 
        END as Calculated_NewIP2,
        CASE 
            WHEN COALESCE(dc.TotalLaborQty, 0) >= jh6.ProdQty THEN 1 
            ELSE 0 
        END as Calculated_DetailComplete
    FROM Erp.JobHead jh6
    LEFT JOIN Erp.JobAsmbl ja6 ON jh6.Company = ja6.Company AND jh6.JobNum = ja6.JobNum
    LEFT JOIN MtlIssued mi ON ja6.JobNum = mi.JobNum AND ja6.AssemblySeq = mi.AssemblySeq
    LEFT JOIN HeatTreat ht ON ja6.JobNum = ht.JobNum AND ja6.AssemblySeq = ht.AssemblySeq
    LEFT JOIN Farmout fo ON ja6.JobNum = fo.JobNum AND ja6.AssemblySeq = fo.AssemblySeq
    LEFT JOIN OVNotFinal ovnf ON ja6.JobNum = ovnf.JobNum AND ja6.AssemblySeq = ovnf.AssemblySeq
    LEFT JOIN OVFinalOrBack ovfb ON ja6.JobNum = ovfb.JobNum AND ja6.AssemblySeq = ovfb.AssemblySeq
    LEFT JOIN LaborSummary ls ON ja6.Company = ls.Company AND ja6.JobNum = ls.JobNum AND ja6.AssemblySeq = ls.AssemblySeq
    LEFT JOIN DetailComplete dc ON jh6.Company = dc.Company AND jh6.JobNum = dc.JobNum AND ja6.AssemblySeq = dc.AssemblySeq
    -- Early filtering (Change #6)
    WHERE jh6.JobClosed = 0 
      AND jh6.JobFirm = 1
),

-- Calculate InProcess status with simplified logic
JobStatusWithInProcess AS (
    SELECT *,
        CASE 
            WHEN (Calculated_NewIP = 1 OR Calculated_NewIP2 = 1) THEN 1 
            ELSE 0 
        END as Calculated_InProcess
    FROM JobStatusBase
),

-- Calculate status for each assembly
JobStatusWithStatus AS (
    SELECT *,
        CASE
            WHEN Calculated_OVFinalOrBack = 1 THEN 6
            WHEN Calculated_OVNotFinal = 1 THEN 5
            WHEN Calculated_InProcess = 1 THEN 4
            WHEN Calculated_Farmout = 1 THEN 3
            WHEN Calculated_BackFromHT = 1 THEN 2
            WHEN Calculated_MtlIssued = 1 THEN 1
            ELSE 0
        END as Calculated_Status
    FROM JobStatusWithInProcess
),

-- Top level status (AssemblySeq = 0)
TopStatus AS (
    SELECT 
        JobHead6_Company,
        JobHead6_JobNum,
        Calculated_Status as Calculated_TopStatus
    FROM JobStatusWithStatus
    WHERE JobAsmbl6_AssemblySeq = 0
),

-- Assembly level status (AssemblySeq <> 0, incomplete only)
AsmStatus AS (
    SELECT 
        JobHead6_JobNum,
        Calculated_Status
    FROM JobStatusWithStatus
    WHERE Calculated_DetailComplete = 0 
      AND JobAsmbl6_AssemblySeq <> 0
)

-- Final result with fallback logic
SELECT  
    ts.JobHead6_Company,
    COALESCE(asms.JobHead6_JobNum, ts.JobHead6_JobNum) as Calculated_JobNum,
    CASE
        WHEN ts.Calculated_TopStatus = 0 THEN COALESCE(asms.Calculated_Status, 0)
        WHEN asms.Calculated_Status < ts.Calculated_TopStatus THEN asms.Calculated_Status
        ELSE ts.Calculated_TopStatus
    END as Calculated_Status
FROM TopStatus ts
LEFT JOIN AsmStatus asms ON ts.JobHead6_JobNum = asms.JobHead6_JobNum;