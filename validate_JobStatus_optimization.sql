-- Comparison script to validate original vs optimized JobStatus queries
-- This script will help ensure identical results between the two versions

-- Create temp tables to store results from both queries
IF OBJECT_ID('tempdb..#OriginalResults') IS NOT NULL DROP TABLE #OriginalResults;
IF OBJECT_ID('tempdb..#OptimizedResults') IS NOT NULL DROP TABLE #OptimizedResults;

-- Store original query results
-- (Insert the original query here when testing)
/*
SELECT  
    JobHead6_Company, 
    Calculated_JobNum, 
    Calculated_Status
INTO #OriginalResults
FROM (
    -- ORIGINAL QUERY GOES HERE
) OriginalQuery;
*/

-- Store optimized query results
-- (Insert the optimized query here when testing)
/*
SELECT  
    JobHead6_Company, 
    Calculated_JobNum, 
    Calculated_Status
INTO #OptimizedResults
FROM (
    -- OPTIMIZED QUERY GOES HERE
) OptimizedQuery;
*/

-- Comparison tests
PRINT '=== JOBSTATUS QUERY COMPARISON RESULTS ===';

-- Test 1: Row count comparison
DECLARE @OriginalCount INT = (SELECT COUNT(*) FROM #OriginalResults);
DECLARE @OptimizedCount INT = (SELECT COUNT(*) FROM #OptimizedResults);

PRINT 'Row Count Comparison:';
PRINT 'Original: ' + CAST(@OriginalCount AS VARCHAR(10));
PRINT 'Optimized: ' + CAST(@OptimizedCount AS VARCHAR(10));
PRINT 'Match: ' + CASE WHEN @OriginalCount = @OptimizedCount THEN 'YES' ELSE 'NO' END;
PRINT '';

-- Test 2: Find rows in original but not in optimized
PRINT 'Rows in Original but NOT in Optimized:';
SELECT COUNT(*) as MissingInOptimized
FROM #OriginalResults o
LEFT JOIN #OptimizedResults op ON o.JobHead6_Company = op.JobHead6_Company 
                                AND o.Calculated_JobNum = op.Calculated_JobNum
WHERE op.Calculated_JobNum IS NULL;

-- Test 3: Find rows in optimized but not in original
PRINT 'Rows in Optimized but NOT in Original:';
SELECT COUNT(*) as ExtraInOptimized
FROM #OptimizedResults op
LEFT JOIN #OriginalResults o ON o.JobHead6_Company = op.JobHead6_Company 
                              AND o.Calculated_JobNum = op.Calculated_JobNum
WHERE o.Calculated_JobNum IS NULL;

-- Test 4: Find status differences for matching jobs
PRINT 'Status Differences for Matching Jobs:';
SELECT 
    o.JobHead6_Company,
    o.Calculated_JobNum,
    o.Calculated_Status as Original_Status,
    op.Calculated_Status as Optimized_Status
FROM #OriginalResults o
INNER JOIN #OptimizedResults op ON o.JobHead6_Company = op.JobHead6_Company 
                                 AND o.Calculated_JobNum = op.Calculated_JobNum
WHERE o.Calculated_Status <> op.Calculated_Status
ORDER BY o.JobHead6_Company, o.Calculated_JobNum;

-- Test 5: Status distribution comparison
PRINT 'Status Distribution Comparison:';
SELECT 
    'Original' as Source,
    Calculated_Status,
    COUNT(*) as Count
FROM #OriginalResults
GROUP BY Calculated_Status
UNION ALL
SELECT 
    'Optimized' as Source,
    Calculated_Status,
    COUNT(*) as Count
FROM #OptimizedResults
GROUP BY Calculated_Status
ORDER BY Source, Calculated_Status;

-- Test 6: Sample data comparison
PRINT 'Sample Data Comparison (First 10 rows):';
SELECT 
    'Original' as Source,
    JobHead6_Company,
    Calculated_JobNum,
    Calculated_Status
FROM (
    SELECT *, ROW_NUMBER() OVER (ORDER BY JobHead6_Company, Calculated_JobNum) as rn
    FROM #OriginalResults
) o WHERE rn <= 10
UNION ALL
SELECT 
    'Optimized' as Source,
    JobHead6_Company,
    Calculated_JobNum,
    Calculated_Status
FROM (
    SELECT *, ROW_NUMBER() OVER (ORDER BY JobHead6_Company, Calculated_JobNum) as rn
    FROM #OptimizedResults
) op WHERE rn <= 10
ORDER BY Source, JobHead6_Company, Calculated_JobNum;

-- Final validation summary
DECLARE @RowCountMatch BIT = CASE WHEN @OriginalCount = @OptimizedCount THEN 1 ELSE 0 END;
DECLARE @MissingRows INT = (
    SELECT COUNT(*) 
    FROM #OriginalResults o
    LEFT JOIN #OptimizedResults op ON o.JobHead6_Company = op.JobHead6_Company 
                                    AND o.Calculated_JobNum = op.Calculated_JobNum
    WHERE op.Calculated_JobNum IS NULL
);
DECLARE @ExtraRows INT = (
    SELECT COUNT(*) 
    FROM #OptimizedResults op
    LEFT JOIN #OriginalResults o ON o.JobHead6_Company = op.JobHead6_Company 
                                  AND o.Calculated_JobNum = op.Calculated_JobNum
    WHERE o.Calculated_JobNum IS NULL
);
DECLARE @StatusDiffs INT = (
    SELECT COUNT(*) 
    FROM #OriginalResults o
    INNER JOIN #OptimizedResults op ON o.JobHead6_Company = op.JobHead6_Company 
                                     AND o.Calculated_JobNum = op.Calculated_JobNum
    WHERE o.Calculated_Status <> op.Calculated_Status
);

PRINT '';
PRINT '=== VALIDATION SUMMARY ===';
PRINT 'Row Count Match: ' + CASE WHEN @RowCountMatch = 1 THEN 'PASS' ELSE 'FAIL' END;
PRINT 'Missing Rows: ' + CAST(@MissingRows AS VARCHAR(10));
PRINT 'Extra Rows: ' + CAST(@ExtraRows AS VARCHAR(10));
PRINT 'Status Differences: ' + CAST(@StatusDiffs AS VARCHAR(10));
PRINT '';
PRINT 'OVERALL RESULT: ' + CASE 
    WHEN @RowCountMatch = 1 AND @MissingRows = 0 AND @ExtraRows = 0 AND @StatusDiffs = 0 
    THEN 'QUERIES PRODUCE IDENTICAL RESULTS ✓' 
    ELSE 'QUERIES HAVE DIFFERENCES - REVIEW REQUIRED ✗' 
END;

-- Cleanup
DROP TABLE #OriginalResults;
DROP TABLE #OptimizedResults;