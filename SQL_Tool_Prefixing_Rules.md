# **SQL-to-BAQ Import Source File Prefixing Rules for Tool Compatibility**

## **Core Rule: Pre-Apply Single Prefix Strategy**

The tool adds the table/CTE alias as a prefix to output field names, then references those prefixed names in WHERE/JOIN clauses. To make this work, **pre-apply the prefix in your source file**.

---

## **Quick Reference:**
0. **Unique Alias Strategy**: Use sequential numbering to prevent table alias conflicts (JobHead1, JobHead2, JobHead3, etc.)
1. **Base fields**: `[Alias].[Field] as [Alias_Field]`
2. **New calculations**: `CASE ... as [Calculated_Name]`  
3. **Pass-through**: `[CTE].[PrevField] as [CTE_PrevField]`
4. **WHERE/JOIN**: Use the pre-applied prefix names
5. **Build progressively**: Each CTE adds its alias to field names

**Key insight**: Your tool expects to find the field names it references, so pre-build those exact names in your SELECT clauses!

---

## **Rule 0: Unique Alias Strategy**

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

## **Rule 1: Base Table Fields**

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

## **Rule 2: New Calculated Fields**

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

## **Rule 3: Passed-Through Fields from Previous CTEs**

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

## **Rule 4: WHERE Clause References**

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

## **Rule 5: JOIN References**

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

## **Rule 6: Field Name Chain Pattern**

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