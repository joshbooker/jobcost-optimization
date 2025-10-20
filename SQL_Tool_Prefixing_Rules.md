# **SQL-to-BAQ Import Source File Prefixing Rules for Tool Compatibility**

## **Core Rule: Pre-Apply Single Prefix Strategy**

The tool adds the table/CTE alias as a prefix to output field names, then references those prefixed names in WHERE/JOIN clauses. To make this work, **pre-apply the prefix in your source file**.

---




## **Quick Reference:**
0. **No SELECT \***: Always explicitly list all fields in SELECT; never use SELECT *
1. **Unique Alias Strategy**: Use sequential numbering to prevent table alias conflicts (JobHead1, JobHead2, etc.)
2. **Base fields**: `[Alias].[Field] as [Alias_Field]`
3. **New calculations**: `CASE ... as [Calculated_Name]` (no prefix needed)
4. **Extract subqueries**: Replace nested subqueries with separate CTEs (critical for tool compatibility)
5. **Pass-through fields**: `[CTE].[PrevField] as [CTE_PrevField]` (for all CTE-to-CTE references, including JOINs, WHERE, SELECT)
6. **WHERE/JOIN**: Use the pre-applied prefix names on both sides of conditions
7. **Build progressively**: Each CTE adds its alias to all output field names

**Key insight**: The tool expects to find the field names it references, so pre-build those exact names in your SELECT clauses! Never use SELECT *.
---


## **Rule 0: No SELECT \***

**Pattern:** Always explicitly list all fields in SELECT statements. Never use `SELECT *` in any CTE or query.

**Why:**
- Ensures all output fields are properly prefixed and named for tool compatibility
- Prevents accidental omission of required field renaming or prefixing
- Guarantees that all cross-CTE references use the correct, tool-compatible field names

**Example:**
```sql
-- ✅ CORRECT:
SELECT [Alias].[Field1] as [Alias_Field1], [Alias].[Field2] as [Alias_Field2] FROM ...

-- ❌ WRONG:
SELECT * FROM ...
```

**Critical:** SELECT * will break field name consistency and cause tool conversion failures. Always enumerate every field explicitly, using the correct prefixing and naming rules above.

---

## **Rule 1: Unique Alias Strategy**

**Pattern:** Use sequential numbering to prevent table alias conflicts when the same table appears multiple times.

```sql
-- ✅ CORRECT: Sequential numbering for unique aliases
JobStatusBase AS (
    SELECT 
        [JobHead1].[Company] as [JobHead1_Company],
        [JobHead1].[JobNum] as [JobHead1_JobNum]
    FROM Erp.JobHead as [JobHead1]
    ...
),

DetailComplete AS (
    SELECT 
        [JobHead2].[Company] as [JobHead2_Company],
        [JobHead2].[JobNum] as [JobHead2_JobNum]
    FROM Erp.JobHead as [JobHead2]
    ...
),

-- ❌ WRONG: Reusing same alias causes conflicts
JobStatusBase AS (
    SELECT 
        [JobHead].[Company] as [JobHead_Company],
        [JobHead].[JobNum] as [JobHead_JobNum]
    FROM Erp.JobHead as [JobHead]
    ...
),

DetailComplete AS (
    SELECT 
        [JobHead].[Company] as [JobHead_Company],  -- CONFLICT!
        [JobHead].[JobNum] as [JobHead_JobNum]     -- CONFLICT!
    FROM Erp.JobHead as [JobHead]
    ...
)
```

**Why this works:**
- Prevents alias name collisions across CTEs
- Each table instance has a unique identifier
- Tool can distinguish between JobHead1_Company and JobHead2_Company
- Maintains clear relationship between alias and output field name

---

## **Rule 2: Base Table Fields**

**Pattern:** `[TableAlias].[Field] as [TableAlias_Field]`

```sql
-- ✅ CORRECT Source:
SELECT 
    [JobHead].[Company] as [JobHead_Company],
    [JobHead].[JobNum] as [JobHead_JobNum],
    [JobAsmbl].[AssemblySeq] as [JobAsmbl_AssemblySeq]
FROM Erp.JobHead AS [JobHead]
INNER JOIN Erp.JobAsmbl AS [JobAsmbl] ON ...

-- Tool Output:
-- [JobHead_JobHead_Company], [JobHead_JobHead_JobNum], [JobAsmbl_JobAsmbl_AssemblySeq]
-- Tool References: JobHead.JobHead_Company, JobAsmbl.JobAsmbl_AssemblySeq ✅
```

```sql
-- ❌ WRONG Source:
SELECT 
    [JobHead].[Company] as [Company],        -- Tool creates [JobHead_Company]
    [JobHead].[JobNum] as [JobNum]           -- Tool creates [JobHead_JobNum]
    
-- Tool will reference: JobHead.Company, JobHead.JobNum
-- But output fields are: [JobHead_Company], [JobHead_JobNum] ❌ MISMATCH!
```

---

## **Rule 3: New Calculated Fields**

**Pattern:** `CASE ... END as [Calculated_Name]` (No prefix needed)

```sql
-- ✅ CORRECT Source:
SELECT 
    CASE WHEN [JobHead].[JobComplete] = 1 THEN 1 ELSE 0 END as [Calculated_IsComplete],
    CASE WHEN [JobAsmbl].[AssemblySeq] = 0 THEN 1 ELSE 0 END as [Calculated_MtlIssued]

-- Tool Output: [Calculated_IsComplete], [Calculated_MtlIssued]
-- Tool References: TableAlias.Calculated_IsComplete ✅
```

---

## **Rule 4: Extract Complex Subqueries to Separate CTEs**

**Pattern:** `[CTEAlias].[PreviousField] as [CTEAlias_PreviousField]`

```sql
-- ✅ CORRECT Source:
JobStatusWithStatus AS (
    SELECT 
        -- Pass through base fields with CTE prefix
        [StatusBase].[JobHead_Company] as [StatusBase_JobHead_Company],
        [StatusBase].[JobAsmbl_AssemblySeq] as [StatusBase_JobAsmbl_AssemblySeq],
        
        -- Pass through calculated fields with CTE prefix  
        [StatusBase].[Calculated_MtlIssued] as [StatusBase_Calculated_MtlIssued],
        
        -- New calculation (no prefix needed)
        CASE WHEN ... END as [Calculated_Status]
    FROM JobStatusBase as [StatusBase]
)

-- Tool Output:
-- [StatusBase_StatusBase_JobHead_Company], [StatusBase_Calculated_Status]
-- Tool References: StatusBase.StatusBase_JobHead_Company ✅
```

---

## **Rule 5: Passed-Through Fields from Previous CTEs**

**Pattern:** Use the pre-applied prefix in your source WHERE clauses

```sql
-- ✅ CORRECT Source:
TopStatus AS (
    SELECT ...
    FROM JobStatusWithStatus as [WithStatus1]
    WHERE [WithStatus1].[StatusBase_JobAsmbl_AssemblySeq] = 0
    --                  ↑ Use the pre-applied prefix
)

-- Tool Output WHERE: WithStatus1.StatusBase_JobAsmbl_AssemblySeq = 0 ✅
```

```sql
-- ❌ WRONG Source:
WHERE [WithStatus1].[JobAsmbl_AssemblySeq] = 0  -- No prefix

-- Tool Output WHERE: WithStatus1.JobAsmbl_AssemblySeq = 0
-- But actual field is: [StatusBase_JobAsmbl_AssemblySeq] ❌ MISMATCH!
```

---

## **Rule 6: WHERE Clause References**

**Pattern:** Both sides must use pre-applied prefixes

```sql
-- ✅ CORRECT Source:
FROM TopStatus as [TopLevel]
LEFT JOIN AsmStatus as [AsmLevel] 
    ON [TopLevel].[WithStatus1_StatusBase_JobHead_JobNum] = [AsmLevel].[WithStatus2_StatusBase_JobHead_JobNum]
    --           ↑ Pre-applied prefix                              ↑ Pre-applied prefix

-- Tool Output JOIN: 
-- TopLevel.WithStatus1_StatusBase_JobHead_JobNum = AsmLevel.WithStatus2_StatusBase_JobHead_JobNum ✅
```

---

## **Rule 7: JOIN References**

**Build field names progressively through CTEs:**

```sql
-- CTE 1: Base tables
[JobHead].[Company] as [JobHead_Company]

-- CTE 2: Reference CTE 1  
[StatusBase].[JobHead_Company] as [StatusBase_JobHead_Company]

-- CTE 3: Reference CTE 2
[WithStatus1].[StatusBase_JobHead_Company] as [WithStatus1_StatusBase_JobHead_Company]

-- Final SELECT: Reference CTE 3
[TopLevel].[WithStatus1_StatusBase_JobHead_Company] as [TopLevel_WithStatus1_StatusBase_JobHead_Company]
```

**Field Evolution Chain:**
```
JobHead_Company 
→ StatusBase_JobHead_Company 
→ WithStatus1_StatusBase_JobHead_Company 
→ TopLevel_WithStatus1_StatusBase_JobHead_Company
```

---

## **Complete Example Template:**

```sql
WITH BaseData AS (
    SELECT 
        [Table1].[Field1] as [Table1_Field1],              -- Rule 1: Base fields
        [Table2].[Field2] as [Table2_Field2],              -- Rule 1: Base fields
        CASE WHEN ... END as [Calculated_Something]        -- Rule 2: New calculations
    FROM Schema.Table1 AS [Table1]
    JOIN Schema.Table2 AS [Table2] ON ...
),

ProcessedData AS (
    SELECT 
        [Base].[Table1_Field1] as [Base_Table1_Field1],         -- Rule 3: Pass-through with prefix
        [Base].[Calculated_Something] as [Base_Calculated_Something], -- Rule 3: Even calculated gets prefix
        CASE WHEN ... END as [Calculated_NewField]              -- Rule 2: New calculation
    FROM BaseData as [Base]
    WHERE [Base].[Table1_Field1] IS NOT NULL                    -- Rule 4: WHERE uses prefix
)

SELECT 
    [Proc].[Base_Table1_Field1] as [Proc_Base_Table1_Field1]    -- Rule 3: Continue chain
FROM ProcessedData as [Proc]
WHERE [Proc].[Base_Calculated_Something] = 1                    -- Rule 4: WHERE uses prefix
```

---

## **Rule 8: Field Name Chain Pattern**

**Pattern:** Replace nested subqueries within CTEs with separate named CTEs to avoid JOIN parsing issues.

### **The Problem: Subquery JOIN Limitations**

The SQL-to-BAQ tool has a **critical limitation** with nested subqueries in complex JOINs. It incorrectly moves JOIN conditions between tables, creating invalid references.

```sql
-- ❌ PROBLEMATIC: Nested subquery confuses tool parser
DetailComplete AS (
    SELECT 
        [JobHead6].[Company] as [JobHead6_Company],
        [JobHead6].[JobNum] as [JobHead6_JobNum]
    FROM Erp.JobHead as [JobHead6]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl6] ON [JobHead6].[Company] = [JobAsmbl6].[Company] AND [JobHead6].[JobNum] = [JobAsmbl6].[JobNum]
    INNER JOIN (
        SELECT 
            [JobOperSub].[Company] as [JobOperSub_Company],
            MAX([JobOperSub].[OprSeq]) as [Calculated_LastOpNotInsp]
        FROM Erp.JobOper as [JobOperSub]
        WHERE [JobOperSub].[OpCode] <> '9-OP'
        GROUP BY [JobOperSub].[Company], [JobOperSub].[JobNum], [JobOperSub].[AssemblySeq]
    ) as [LastOp] ON [JobHead6].[Company] = [LastOp].[JobOperSub_Company] 
                 AND [JobAsmbl6].[AssemblySeq] = [LastOp].[JobOperSub_AssemblySeq]  -- This condition gets moved!
)
```

**Tool Conversion Issue:**
```sql
-- Tool incorrectly moves JOIN condition to wrong table:
inner join Erp.JobAsmbl as [JobAsmbl6] on 
    JobHead6.Company = JobAsmbl6.Company
    and JobHead6.JobNum = JobAsmbl6.JobNum
    and ( JobAsmbl6.AssemblySeq = LastOp.JobOperSub_AssemblySeq  )  -- WRONG! Forward reference
inner join (select ...) as [LastOp] on ...  -- LastOp defined AFTER being referenced
```

### **Tested Solutions:**

1. **❌ Context Prefixing Failed:** Tried `as [JobHead6_LastOp]` - tool still moved JOIN conditions
2. **✅ Separate CTEs Work:** Extracting subquery to named CTE resolves the issue

### **The Solution:**

```sql
-- ✅ CORRECT: Separate CTEs with clear dependencies
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

DetailComplete AS (
    SELECT 
        [JobHead6].[Company] as [JobHead6_Company],
        [JobHead6].[JobNum] as [JobHead6_JobNum], 
        [JobAsmbl6].[AssemblySeq] as [JobAsmbl6_AssemblySeq],
        SUM([LaborDtl1].[LaborQty]) as [Calculated_TotalLaborQty],
        [JobHead6].[ProdQty] as [JobHead6_ProdQty]
    FROM Erp.JobHead as [JobHead6]
    INNER JOIN Erp.JobAsmbl as [JobAsmbl6] ON [JobHead6].[Company] = [JobAsmbl6].[Company] AND [JobHead6].[JobNum] = [JobAsmbl6].[JobNum]
    INNER JOIN LastOpNotInspection as [LastOpNotInspection1] ON [JobHead6].[Company] = [LastOpNotInspection1].[JobOperSub_Company] 
                                                            AND [JobHead6].[JobNum] = [LastOpNotInspection1].[JobOperSub_JobNum] 
                                                            AND [JobAsmbl6].[AssemblySeq] = [LastOpNotInspection1].[JobOperSub_AssemblySeq]
    INNER JOIN Erp.LaborDtl as [LaborDtl1] ON [LastOpNotInspection1].[JobOperSub_Company] = [LaborDtl1].[Company] 
                                          AND [LastOpNotInspection1].[JobOperSub_JobNum] = [LaborDtl1].[JobNum] 
                                          AND [LastOpNotInspection1].[Calculated_LastOpNotInsp] = [LaborDtl1].[OprSeq]
    WHERE [JobHead6].[JobClosed] = 0 AND [JobHead6].[JobFirm] = 1
    GROUP BY [JobHead6].[Company], [JobHead6].[JobNum], [JobAsmbl6].[AssemblySeq], [JobHead6].[ProdQty]
)
```

### **Why This Works:**

1. **Clear Dependencies**: Tool processes CTEs in linear order without confusion
2. **Simple JOINs**: No nested subqueries to misparse  
3. **Proper References**: All CTE references are to previously defined CTEs
4. **Consistent Prefixing**: Each CTE follows established alias patterns

### **Rule 7 Guidelines:**

- ✅ **Extract** all nested subqueries with aggregations into separate named CTEs
- ✅ **Use** descriptive CTE names that indicate purpose (LastOpNotInspection vs LastOp)
- ✅ **Apply** consistent prefixing to all extracted CTE fields
- ✅ **Reference** extracted CTEs with numbered aliases (LastOpNotInspection1)
- ✅ **Order** CTEs so dependencies are defined before use
- ✅ **Start FROM the CTE** when possible to avoid multi-table AssemblySeq conflicts
- ✅ **Use WHERE clause** for complex field matching that confuses JOIN parser
- ❌ **Avoid** any nested SELECT statements within JOIN conditions
- ❌ **Don't** embed aggregations or complex logic inside JOINs
- ❌ **Never** create forward references to subquery aliases
- ❌ **Avoid** overlapping field references (like AssemblySeq) across multiple JOINs

### **Critical JOIN Pattern Discovery:**

**✅ Successful Pattern (works):**
```sql
-- Start FROM the CTE, join to base tables
FROM LastOpNotInspection as [LastOpNotInspection1]
INNER JOIN Erp.JobHead as [JobHead6] ON [LastOpNotInspection1].[JobOperSub_Company] = [JobHead6].[Company]
```

**❌ Problematic Pattern (fails):**
```sql
-- Start FROM base table, creates overlapping AssemblySeq references
FROM Erp.JobHead as [JobHead6]
INNER JOIN Erp.JobAsmbl as [JobAsmbl6] ON [JobHead6].[Company] = [JobAsmbl6].[Company]
INNER JOIN LastOpNotInspection as [LastOpNotInspection1] ON [JobAsmbl6].[AssemblySeq] = [LastOpNotInspection1].[JobOperSub_AssemblySeq]  -- Tool moves this condition!
```

### **WHERE Clause Workaround:**

When you must have overlapping field references but can't restructure the query, move the problematic condition to WHERE clause:

**✅ Working Solution:**
```sql
-- Simplified JOIN - only use non-conflicting fields
LEFT JOIN DetailComplete as [DetailComplete1] ON [JobHead8].[Company] = [DetailComplete1].[JobHead6_Company] 
                                              AND [JobHead8].[JobNum] = [DetailComplete1].[JobHead6_JobNum]
-- Move problematic AssemblySeq condition to WHERE clause
WHERE [JobHead8].[JobClosed] = 0 
  AND [JobHead8].[JobFirm] = 1
  AND ([DetailComplete1].[JobAsmbl6_AssemblySeq] IS NULL OR [JobAsmbl8].[AssemblySeq] = [DetailComplete1].[JobAsmbl6_AssemblySeq])
```

**Why this works:**
- JOIN parser only sees simple table-to-table relationships
- WHERE clause handles complex field matching after JOIN structure is established
- LEFT JOIN logic preserved with NULL check in WHERE condition

The tool's parser has issues when the same field name (`AssemblySeq`) appears in multiple JOIN conditions across different table relationships.

**Critical Finding:** The tool's JOIN parser cannot handle complex nested subqueries regardless of alias naming strategies. Separate CTEs with simplified JOINs and WHERE clause workarounds are the only reliable solution for maintaining tool compatibility.