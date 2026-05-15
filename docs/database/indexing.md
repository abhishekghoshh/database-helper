# DBMS Indexing to improve search query performance

## Youtube

- [21. Database Indexing: How DBMS Indexing done to improve search query performance? Explained](https://www.youtube.com/watch?v=6ZquiVH8AGU)

- [DB Indexing in System Design Interviews - B-tree, Geospatial, Inverted Index, and more!](https://www.youtube.com/watch?v=BHCSL_ZifI0)
- [How do indexes make databases read faster?](https://www.youtube.com/watch?v=3G293is403I)
- [Database Indexes - You Might Be Using Them Wrong](https://www.youtube.com/watch?v=RufupUDBtYY)
- [Database Indexing for Dumb Developers](https://www.youtube.com/watch?v=lYh6LrSIDvY)
- [How SQL Indexes Actually Work (Step-by-Step)](https://www.youtube.com/watch?v=teMXE6hzva0)
- [SQL Indexes (Visually Explained) | Clustered vs Nonclustered | #SQL Course 35](https://www.youtube.com/watch?v=BxAj3bl00-o)




## Medium

- [Introduction To Database Indexing](https://medium.com/@rtawadrous/introduction-to-database-indexes-9b488e243cc1)
- [Hash Indexing](https://medium.com/the-developers-diary/hash-indexing-42f505f63fa0)



## Theory


### What is Database Indexing?

**Database indexing** is a data structure technique used to quickly locate and access data in a database without scanning every row. An index creates a separate data structure (usually a B-Tree or B+ Tree) that stores a subset of columns with pointers to the actual rows, dramatically improving query performance.

**Analogy**: Think of an index like the index at the back of a textbook. Instead of flipping through every page to find a topic, you look it up in the index which tells you exactly which page to go to.

**Key Benefits:**
- ⚡ **Faster Query Performance**: Reduces query time from O(n) to O(log n)
- 🎯 **Efficient Data Retrieval**: Avoids full table scans
- 📊 **Better Sort Performance**: Pre-sorted index structure
- 🔍 **Optimized Searches**: Especially for WHERE, JOIN, ORDER BY clauses

**Trade-offs:**
- 💾 **Extra Storage**: Indexes consume additional disk space
- ⏱️ **Slower Writes**: INSERT, UPDATE, DELETE operations must update indexes
- 🧠 **Maintenance Overhead**: Indexes need to be rebuilt/reorganized periodically

---

## Question 1: How is Table Data (Rows) Actually Stored?

### Answer:

Database tables store data in fixed-size blocks called **pages** or **blocks**. Understanding this storage mechanism is crucial for understanding how indexing improves performance.

### Data Pages (Database Pages)

**What are Data Pages?**

A **data page** (also called a database page or disk page) is the smallest unit of storage that a database management system uses to read from or write to disk. It's a fixed-size block of contiguous memory, typically 4KB, 8KB, or 16KB depending on the database system.

**Page Structure:**

```
┌─────────────────────────────────────────────────────────┐
│                    DATA PAGE (8KB)                      │
├─────────────────────────────────────────────────────────┤
│  Page Header (96 bytes)                                 │
│  ┌───────────────────────────────────────────────┐     │
│  │ Page ID: 1001                                 │     │
│  │ Page Type: DATA_PAGE                          │     │
│  │ Previous Page: 1000                           │     │
│  │ Next Page: 1002                               │     │
│  │ Free Space Start: 7800                        │     │
│  │ Free Space End: 8000                          │     │
│  │ Number of Records: 45                         │     │
│  │ Checksum: 0xABCD1234                          │     │
│  │ LSN (Log Sequence Number): 12345678           │     │
│  └───────────────────────────────────────────────┘     │
├─────────────────────────────────────────────────────────┤
│  Row Offset Array (90 bytes)                            │
│  ┌───────────────────────────────────────────────┐     │
│  │ Offset[0]: 200   (points to first row)       │     │
│  │ Offset[1]: 350   (points to second row)      │     │
│  │ Offset[2]: 520   (points to third row)       │     │
│  │ ...                                           │     │
│  │ Offset[44]: 7650 (points to 45th row)        │     │
│  └───────────────────────────────────────────────┘     │
│                                                          │
│  WHY OFFSET ARRAY IS NEEDED:                            │
│  • Variable-length rows: Rows can be different sizes    │
│  • Direct access: Jump to any row without scanning      │
│  • Update efficiency: Relocate rows without affecting   │
│    other rows' positions                                │
│  • Deletion handling: Mark slots as deleted, reuse      │
│    space without shifting all rows                      │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  Data Records (7814 bytes)                              │
│  ┌───────────────────────────────────────────────┐     │
│  │ Record 1: [id=1, name='John', age=30, ...]    │     │
│  │ Record 2: [id=2, name='Jane', age=25, ...]    │     │
│  │ Record 3: [id=3, name='Bob', age=35, ...]     │     │
│  │ ...                                           │     │
│  │ Record 45: [id=45, name='Alice', ...]         │     │
│  └───────────────────────────────────────────────┘     │
├─────────────────────────────────────────────────────────┤
│  Free Space (200 bytes)                                 │
│  [Available for new records or updates]                 │
└─────────────────────────────────────────────────────────┘
```

**Page Header Components (Detailed):**

| Component | Size | Description |
|-----------|------|-------------|
| **Page ID** | 4 bytes | Unique identifier for this page |
| **Page Type** | 1 byte | Type: DATA_PAGE, INDEX_PAGE, etc. |
| **Previous Page** | 4 bytes | Pointer to previous page (doubly-linked list) |
| **Next Page** | 4 bytes | Pointer to next page |
| **Free Space Start** | 2 bytes | Byte offset where free space begins |
| **Free Space End** | 2 bytes | Byte offset where free space ends |
| **Number of Records** | 2 bytes | Count of records in this page |
| **Checksum** | 4 bytes | For data integrity verification |
| **LSN** | 8 bytes | Log Sequence Number (for recovery) |
| **Page Level** | 2 bytes | Level in B-Tree (0 for leaf) |
| **Flags** | 2 bytes | Status flags (dirty, compressed, etc.) |
| **Reserved** | ~60 bytes | Database-specific metadata |

**Who Controls Data Pages?**

The **Buffer Manager** (part of the database storage engine) controls data pages:
- Manages page cache (buffer pool) in memory
- Handles page reads from disk
- Handles page writes to disk
- Implements page replacement algorithms (LRU, Clock)
- Ensures page consistency and integrity

### Row Offset Array: Why It's Critical

**The Problem: Variable-Length Rows**

Database rows are **not fixed-size** because of:
- VARCHAR columns (variable-length strings)
- NULL values (may occupy no space)
- TEXT/BLOB columns
- Different character encodings (UTF-8 can use 1-4 bytes per character)

**Example Problem Without Offset Array:**

```
Fixed-size approach (DOESN'T WORK):
┌─────────────────────────────────────────┐
│ Row 1 (150 bytes) | Row 2 (80 bytes)   │
│ Row 3 (200 bytes) | ...                │
└─────────────────────────────────────────┘

❌ Problem: How to find Row 3 quickly?
   - Can't calculate: Position = row_number × row_size
   - Must scan: Row 1 → Row 2 → Row 3
   - O(n) time to access any row!
```

**Solution: Row Offset Array**

```
With Offset Array:
┌─────────────────────────────────────────┐
│ Header                                  │
│ ┌──────────────────────┐                │
│ │ Offset[0] = 200      │ ← Points to Row 1 at byte 200
│ │ Offset[1] = 350      │ ← Points to Row 2 at byte 350
│ │ Offset[2] = 430      │ ← Points to Row 3 at byte 430
│ │ Offset[3] = 630      │ ← Points to Row 4 at byte 630
│ └──────────────────────┘                │
│                                          │
│ Data Area:                               │
│ [byte 200] Row 1 (150 bytes)            │
│ [byte 350] Row 2 (80 bytes)             │
│ [byte 430] Row 3 (200 bytes)            │
│ [byte 630] Row 4 (...)                  │
└─────────────────────────────────────────┘

✅ Advantage: Direct access to Row 3 in O(1):
   1. Read Offset[2] = 430
   2. Jump to byte 430
   3. Read row
```

**Why Row Offset Array is Needed:**

1. **Variable-Length Row Support**
   ```
   Without offsets: Must scan from start
   With offsets: Direct jump to any row
   
   Example with VARCHAR:
   Row 1: id=1, name="Jo" (short)
   Row 2: id=2, name="Christopher Alexander" (long)
   Row 3: id=3, name="Li" (short)
   
   Offset[0] = 200  (Row 1 starts)
   Offset[1] = 220  (Row 2 starts, 20 bytes after)
   Offset[2] = 265  (Row 3 starts, 45 bytes after)
   ```

2. **Fast Random Access**
   ```
   Access row #5:
   - WITHOUT offset array: O(n) - scan rows 0→1→2→3→4→5
   - WITH offset array: O(1) - read Offset[5], jump directly
   ```

3. **Efficient Updates (Row Relocation)**
   ```
   UPDATE users SET name = 'Very Long Name Here' WHERE id = 2;
   
   Old Row 2: 80 bytes
   New Row 2: 150 bytes (doesn't fit in original location!)
   
   Solution:
   1. Move Row 2 to end of page (new location)
   2. Update Offset[1] to new location
   3. Other rows' offsets unchanged!
   
   ┌────────────────────────────────────────┐
   │ Offset[0] = 200  (unchanged)           │
   │ Offset[1] = 7800 (updated!)            │
   │ Offset[2] = 430  (unchanged)           │
   └────────────────────────────────────────┘
   
   No need to shift Row 3, Row 4, Row 5... in memory!
   ```

4. **Efficient Deletion (Slot Reuse)**
   ```
   DELETE FROM users WHERE id = 2;
   
   Method 1 - WITHOUT offset array:
   - Shift all following rows backward
   - Expensive for large pages (thousands of bytes moved)
   
   Method 2 - WITH offset array:
   - Mark Offset[1] as NULL/deleted (-1)
   - Don't move any data
   - Reuse slot for future inserts
   
   ┌────────────────────────────────────────┐
   │ Offset[0] = 200                        │
   │ Offset[1] = -1     (deleted!)          │
   │ Offset[2] = 430                        │
   │ Offset[3] = 630                        │
   └────────────────────────────────────────┘
   
   Space at old Row 2 location becomes free space!
   ```

5. **Maintains Row Order Without Physical Order**
   ```
   Logical order (by primary key):
   Row 0: id=1
   Row 1: id=2
   Row 2: id=3
   
   Physical storage (after updates):
   [byte 200] id=1 (original)
   [byte 350] id=3 (inserted later)
   [byte 430] id=2 (updated, relocated)
   
   Offset array maintains logical order:
   Offset[0] = 200  → id=1
   Offset[1] = 430  → id=2 (points to relocated position)
   Offset[2] = 350  → id=3
   
   Queries still return rows in correct order!
   ```

**Advantages of Row Offset Array:**

| Advantage | Description | Performance Impact |
|-----------|-------------|-------------------|
| **O(1) Row Access** | Direct jump to any row without scanning | 100x faster for large pages |
| **No Data Movement on Update** | Just update offset pointer when row relocates | Saves thousands of memory copies |
| **Fast Deletion** | Mark offset as deleted, don't shift data | O(1) instead of O(n) |
| **Space Reuse** | Deleted slots can be reused by new inserts | Better space utilization |
| **Logical vs Physical Separation** | Rows can be physically scattered but logically ordered | Flexibility in storage |
| **Update-in-Place Optimization** | If new data fits in old location, no relocation needed | Minimal overhead |
| **Compact Array** | Offsets are small (2-4 bytes each) | Minimal space overhead (~0.1% of page) |

**Real-World Performance Example:**

```
Scenario: Page with 100 rows, access row #87

WITHOUT Offset Array:
1. Start at byte 96 (after header)
2. Read row 0 length → skip row 0
3. Read row 1 length → skip row 1
...
87. Read row 86 length → skip row 86
88. Finally read row 87

Time: ~87 reads × 10μs = 870μs

WITH Offset Array:
1. Read Offset[87] = 6543
2. Jump to byte 6543
3. Read row 87

Time: ~2 reads × 10μs = 20μs

Result: 43x faster!
```

**Memory Overhead Calculation:**

```
Page size: 8KB (8192 bytes)
Average row size: 100 bytes
Rows per page: ~80 rows

Offset Array Size:
- 2 bytes per offset × 80 rows = 160 bytes
- Overhead: 160 / 8192 = 1.95% of page

Trade-off:
- Cost: ~2% storage overhead
- Benefit: O(n) → O(1) access, massively faster updates/deletes

Conclusion: Worth it! 2% overhead for 10-100x performance gain
```

**How Databases Use Offset Arrays:**

```
PostgreSQL:
- Array at start of page
- 4-byte offsets (ItemIdData)
- Format: [offset, length, flags]

MySQL InnoDB:
- "Record directory" at end of page
- 2-byte offsets
- Grows backward from page end

SQL Server:
- "Slot array" after page header
- 2-byte offsets
- Supports row versioning

Oracle:
- "Row directory" in page header
- Variable-size offsets
- Supports row chaining
```

### Data Blocks

**What are Data Blocks?**

A **data block** is the physical storage unit on disk, typically managed by the operating system or file system. In many contexts, "block" and "page" are used interchangeably, but there's a subtle difference:

- **Data Block**: Physical storage unit on disk (OS level)
- **Data Page**: Logical storage unit in database (DBMS level)

**Data Block Structure:**

```
Physical Disk Layout:
┌─────────────────────────────────────────────────────────────┐
│                    DISK (Hard Drive / SSD)                  │
├─────────────────────────────────────────────────────────────┤
│  Block 0  │  Block 1  │  Block 2  │  Block 3  │  Block 4   │
│  (4KB)    │  (4KB)    │  (4KB)    │  (4KB)    │  (4KB)     │
├─────────────────────────────────────────────────────────────┤
│           ↓ Database maps pages to blocks                   │
├─────────────────────────────────────────────────────────────┤
│  Page 1   │  Page 2   │  Page 3   │  Index    │  Page 5    │
│  (8KB)    │  (8KB)    │  (8KB)    │  Page     │  (8KB)     │
│  2 blocks │  2 blocks │  2 blocks │  (8KB)    │  2 blocks  │
└─────────────────────────────────────────────────────────────┘

Mapping: Database Page → Physical Blocks
- Page size: 8KB
- Block size: 4KB
- Each page occupies 2 contiguous blocks
```

**Who Controls Data Blocks?**

The **Operating System** and **File System** control data blocks:
- Allocates disk blocks to files
- Manages block I/O operations
- Handles block caching at OS level
- Ensures data persistence

**How Pages Map to Blocks:**

```
Database File: users.dbf
┌──────────────────────────────────────────────┐
│ Page 0 → Blocks 0-1   (Header page)         │
│ Page 1 → Blocks 2-3   (Data page)           │
│ Page 2 → Blocks 4-5   (Data page)           │
│ Page 3 → Blocks 6-7   (Index page)          │
│ ...                                          │
└──────────────────────────────────────────────┘

Mapping maintained by: Storage Manager / File Manager
```

### Complete Storage Hierarchy

```
┌────────────────────────────────────────────────────────┐
│         APPLICATION LAYER                              │
│         SQL Query: SELECT * FROM users WHERE id = 5    │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│         QUERY OPTIMIZER                                │
│         Decides: Use index or full table scan?         │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│         BUFFER MANAGER                                 │
│         ┌────────────────────────────────┐            │
│         │  Buffer Pool (Memory Cache)    │            │
│         │  ┌──────┐ ┌──────┐ ┌──────┐  │            │
│         │  │Page 1│ │Page 5│ │Page 9│  │  ← Hot pages│
│         │  └──────┘ └──────┘ └──────┘  │            │
│         └────────────────────────────────┘            │
│         If page not in buffer → Read from disk        │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│         STORAGE MANAGER                                │
│         Translates: Page ID → Disk Block Address       │
│         Page 5 → File: users.dbf, Offset: 40960 bytes │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│         FILE SYSTEM (OS)                               │
│         Reads blocks from disk file                    │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│         PHYSICAL DISK                                  │
│         Hard Drive / SSD                               │
│         Block 80-81 → Contains Page 5 data             │
└────────────────────────────────────────────────────────┘
```

**Example: Reading a Row**

```sql
SELECT * FROM users WHERE id = 5;
```

**Step-by-step process:**

1. **Query Parser**: Parses SQL query
2. **Query Optimizer**: Checks if index exists on `id` column
   - If YES: Use index to find page number
   - If NO: Full table scan (read all pages)
3. **Buffer Manager**: Check if page is in memory
   - Cache HIT: Return page from buffer pool (fast!)
   - Cache MISS: Read page from disk
4. **Storage Manager**: Translate page ID to disk location
   - Page 5 → File offset: 40960 bytes (5 × 8KB)
5. **File System**: Read 8KB from disk at offset 40960
6. **Buffer Manager**: Store page in buffer pool, return data
7. **Query Executor**: Scan page for record with id=5, return result

**Without Index:**
- Must read ALL pages (e.g., 10,000 pages = 80MB of data)
- Time: ~100-500ms for large tables

**With Index:**
- Index lookup finds page number instantly
- Read only 1-3 pages (8-24KB of data)
- Time: ~1-10ms

---

## Question 2: What Types of Indexing are Present?

### Answer:

### What is Indexing?

**Indexing** is the process of creating a data structure (index) that improves the speed of data retrieval operations on a database table. An index stores a sorted copy of selected columns along with pointers to the actual rows.

### Advantages of Indexing

✅ **Faster Query Performance**
- Reduces query execution time from seconds to milliseconds
- Especially beneficial for large tables (millions of rows)

✅ **Efficient Searching**
- WHERE clause queries execute faster
- Range queries (BETWEEN, >, <) are optimized

✅ **Faster Sorting**
- ORDER BY operations use pre-sorted index
- No need to sort entire table

✅ **Improved JOIN Performance**
- Indexed foreign keys speed up JOIN operations

✅ **Uniqueness Enforcement**
- UNIQUE indexes prevent duplicate values

### Disadvantages of Indexing

❌ **Extra Storage Space**
- Each index requires additional disk space (10-20% of table size)

❌ **Slower Write Operations**
- INSERT: Must add entry to all indexes
- UPDATE: Must update indexes if indexed columns change
- DELETE: Must remove entry from all indexes

❌ **Maintenance Overhead**
- Indexes become fragmented over time
- Need periodic rebuilding/reorganization

❌ **Index Selection Complexity**
- Too many indexes slow down writes significantly
- Wrong indexes waste space without helping queries

### Types of Indexes

#### 1. Clustered Index

**Definition**: A clustered index determines the **physical order** of data rows in a table. The table data is sorted and stored in the order of the clustered index key.

**Key Characteristics:**
- ✅ **One per table**: Only one clustered index allowed (because physical order is unique)
- 📊 **Table is the index**: Leaf nodes contain actual data rows, not pointers
- 🔢 **Physical ordering**: Rows are stored in sorted order on disk
- ⚡ **Fast range queries**: Sequential disk reads

**Structure:**

```
Clustered Index B+ Tree:
                    [Root Node]
                        50
                    /        \
                   /          \
          [Internal Node]   [Internal Node]
             20    35           65    80
            /  |   |  \         /  |   |  \
           /   |   |   \       /   |   |   \
    [Leaf: Actual Data Rows - Stored in sorted order]
    
    [10,John,30] → [15,Jane,25] → [20,Bob,35] → [25,Alice,28] →
    [35,Tom,40]  → [40,Sara,22] → [50,Mike,33] → [60,Lisa,29]  →
    [65,Dave,45] → [70,Emma,31] → [80,Paul,27] → [90,Kate,38]
    
    ↑ Leaf nodes contain the ACTUAL table data, sorted by index key
```

**Example:**

```sql
-- Create clustered index on primary key
CREATE TABLE users (
    id INT PRIMARY KEY,  -- Automatically creates clustered index
    name VARCHAR(100),
    age INT
);

-- Data is physically stored sorted by id:
-- Page 1: id 1-100
-- Page 2: id 101-200
-- Page 3: id 201-300
-- ...
```

**Advantages:**
- ✅ Extremely fast for range queries (e.g., `WHERE id BETWEEN 100 AND 200`)
- ✅ Data is already sorted (no sorting needed for ORDER BY on indexed column)
- ✅ Faster for queries returning large result sets

**Disadvantages:**
- ❌ Only one per table
- ❌ Slower INSERT/UPDATE if data isn't inserted in index order
- ❌ Page splits occur when inserting into middle of sorted data

#### 2. Non-Clustered Index (Secondary Index)

**Definition**: A non-clustered index creates a **separate structure** from the table data. It contains index keys and pointers (row locators) to the actual data rows.

**Key Characteristics:**
- ✅ **Multiple per table**: Can have many non-clustered indexes
- 🔗 **Separate structure**: Index stored separately from table data
- 📍 **Contains pointers**: Leaf nodes contain row pointers, not actual data
- 🎯 **Flexible**: Can index any column(s)

**Structure:**

```
Non-Clustered Index B+ Tree (on 'name' column):
                    [Root Node]
                       'Jane'
                    /          \
                   /            \
          [Internal Node]    [Internal Node]
           'Alice' 'Dave'      'Mike' 'Tom'
           /   |    |   \      /   |   |   \
          /    |    |    \    /    |   |    \
    [Leaf: Index Keys + Pointers to Actual Rows]
    
    ['Alice', ptr→Row3] → ['Bob', ptr→Row1]   → ['Dave', ptr→Row4]  →
    ['Emma', ptr→Row7]  → ['Jane', ptr→Row2]  → ['John', ptr→Row5]  →
    ['Kate', ptr→Row9]  → ['Lisa', ptr→Row8]  → ['Mike', ptr→Row6]  →
    ['Paul', ptr→Row10] → ['Sara', ptr→Row11] → ['Tom', ptr→Row12]
    
    ↑ Leaf nodes contain index key + pointer to actual row location
    
    Actual Table Data (stored in clustered index or heap order):
    Row1: [20, 'Bob',   35]
    Row2: [15, 'Jane',  25]
    Row3: [25, 'Alice', 28]
    Row4: [65, 'Dave',  45]
    ...
```

**Example:**

```sql
-- Create non-clustered index on name column
CREATE INDEX idx_name ON users(name);

-- Index is separate from table data
-- When querying: SELECT * FROM users WHERE name = 'Alice'
-- 1. Search index for 'Alice' → Get pointer to Row3
-- 2. Use pointer to fetch actual row data
```

**Advantages:**
- ✅ Multiple indexes possible on same table
- ✅ Can optimize different query patterns
- ✅ Doesn't affect physical data ordering

**Disadvantages:**
- ❌ Requires extra disk space (separate structure)
- ❌ Two lookups: Index lookup + data fetch (bookmark lookup)
- ❌ Slower than clustered index for range queries

### Clustered vs Non-Clustered Index Comparison

| Aspect | Clustered Index | Non-Clustered Index |
|--------|----------------|---------------------|
| **Number per table** | One only | Multiple (typically up to 999) |
| **Data storage** | Leaf nodes contain actual rows | Leaf nodes contain pointers to rows |
| **Physical order** | Determines row order on disk | Doesn't affect row order |
| **Space** | No extra space (table itself) | Extra space for separate structure |
| **Speed** | Faster for range queries | Faster for specific lookups |
| **INSERT impact** | Can cause page splits | Less impact on inserts |
| **Common use** | Primary key | Foreign keys, search columns |

### Other Index Types

#### 3. Unique Index

Ensures all values in the indexed column(s) are distinct.

```sql
CREATE UNIQUE INDEX idx_email ON users(email);
-- Prevents duplicate emails
```

#### 4. Composite Index (Multi-Column Index)

Index on multiple columns, useful for queries filtering on multiple fields.

```sql
CREATE INDEX idx_name_age ON users(name, age);
-- Optimizes: WHERE name = 'John' AND age = 30
```

**Column Order Matters:**
- Index on (name, age) helps: `WHERE name = 'John'` or `WHERE name = 'John' AND age = 30`
- Does NOT help: `WHERE age = 30` (first column not used)

#### 5. Covering Index

Index that includes all columns needed by a query, avoiding table lookup.

```sql
CREATE INDEX idx_covering ON users(name) INCLUDE (age, email);
-- Query: SELECT name, age, email WHERE name = 'John'
-- All data retrieved from index, no table access needed!
```

#### 6. Filtered Index (Partial Index)

Index on subset of rows matching a condition.

```sql
CREATE INDEX idx_active_users ON users(name) WHERE status = 'active';
-- Only indexes active users, smaller and faster
```

#### 7. Full-Text Index

Specialized index for text search operations.

```sql
CREATE FULLTEXT INDEX idx_description ON products(description);
-- Enables: WHERE MATCH(description) AGAINST ('wireless mouse')
```

#### 8. Hash Index

Uses a hash function to map keys to bucket locations. Only supports **equality lookups** (`=`), not range queries.

```sql
-- In PostgreSQL:
CREATE INDEX idx_email_hash ON users USING HASH (email);
-- Fast for: WHERE email = 'john@example.com'
-- Cannot use for: WHERE email > 'j%' (range queries not supported)
```

**Best for**: Exact-match lookups on high-cardinality columns where range queries are not needed.

#### 9. Geospatial Index (R-Tree)

Indexes 2D/3D spatial data using R-Tree structures. Used for location-based queries.

```sql
-- In MySQL:
CREATE SPATIAL INDEX idx_location ON stores(coordinates);
-- Enables: Find all stores within 5km of a point

-- In PostGIS (PostgreSQL):
CREATE INDEX idx_geo ON locations USING GIST (geom);
-- Enables: ST_DWithin(geom, ST_MakePoint(-73.99, 40.73), 5000)
```

**Best for**: "Find nearby" queries, geofencing, map applications.

#### 10. Bitmap Index

Stores a bitmap (bit array) for each distinct value in a column. Each bit represents a row — `1` if the row has that value, `0` otherwise.

```sql
-- In Oracle:
CREATE BITMAP INDEX idx_status ON orders(status);
-- Column values: 'pending', 'shipped', 'delivered'

-- Bitmap representation:
-- 'pending':   1 0 0 1 0 1 0 0 ...
-- 'shipped':   0 1 0 0 0 0 1 0 ...
-- 'delivered': 0 0 1 0 1 0 0 1 ...
```

**Best for**: Low-cardinality columns (few distinct values like gender, status, boolean flags). Very efficient for data warehousing and OLAP queries with multiple AND/OR conditions.

---

## Question 3: Understanding Data Structures Used for Indexing

### Answer:

For detailed B-Tree and B+ Tree internals, structure diagrams, comparisons, and complete C implementations, see [B-Tree and B+ Tree](b-tree-and-b-plus-tree.md).

---

## Additional Important Questions

### Q4: When Should You Create an Index?

**Create an index when:**

✅ **Column frequently used in WHERE clause**
```sql
-- Query: SELECT * FROM users WHERE email = 'john@example.com'
CREATE INDEX idx_email ON users(email);
```

✅ **Column used in JOIN operations**
```sql
-- Query: SELECT * FROM orders JOIN users ON orders.user_id = users.id
CREATE INDEX idx_user_id ON orders(user_id);
```

✅ **Column used in ORDER BY**
```sql
-- Query: SELECT * FROM products ORDER BY price
CREATE INDEX idx_price ON products(price);
```

✅ **Table is large** (>100,000 rows)
- Small tables: Full scan is often faster than index

**Do NOT create index when:**

❌ **Table is small** (<1,000 rows)
❌ **Column has low cardinality** (few distinct values)
   - Example: gender (M/F) - only 2 values, index not helpful
❌ **Column frequently updated**
   - Every update must update index
❌ **Table has heavy INSERT/UPDATE workload**
   - Indexes slow down writes

**Common Index Mistakes:**

| Mistake | Problem | Solution |
|---------|---------|----------|
| **Over-indexing** | Every column indexed → slow writes, wasted space | Only index columns used in queries |
| **Unused indexes** | Indexes that no query ever uses | Audit with `pg_stat_user_indexes` or `sys.dm_db_index_usage_stats` |
| **Wrong composite order** | `INDEX(a, b)` helps `WHERE a = ?` but NOT `WHERE b = ?` alone | Put most selective / most queried column first |
| **Not monitoring** | Queries doing full scans despite indexes | Use `EXPLAIN` / `EXPLAIN ANALYZE` to verify index usage |
| **Redundant indexes** | `INDEX(a)` is redundant if `INDEX(a, b)` exists | Remove the shorter index |

---

### Q5: How Does the Query Optimizer Use Indexes?

**Query Optimization Process:**

```sql
-- Query
SELECT * FROM users WHERE age > 25 AND city = 'NYC';

-- Optimizer checks:
1. Indexes available?
   - idx_age on (age)
   - idx_city on (city)
   - idx_age_city on (age, city)  ← Composite

2. Selectivity analysis:
   - age > 25: Returns 70% of rows (not selective)
   - city = 'NYC': Returns 5% of rows (highly selective)
   - Both: Returns 3% of rows

3. Cost estimation:
   - Full table scan: Read all 1,000 pages
   - Use idx_age: Read index + fetch 700 pages (not good)
   - Use idx_city: Read index + fetch 50 pages (good!)
   - Use idx_age_city: Read index + fetch 30 pages (best!)

4. Decision: Use idx_age_city (lowest cost)
```

**View optimizer decision:**
```sql
EXPLAIN SELECT * FROM users WHERE age > 25 AND city = 'NYC';
```

---

### Q6: What is Index Fragmentation and Maintenance?

**Index Fragmentation:**

Over time, indexes become fragmented due to INSERT/UPDATE/DELETE operations:

```
Healthy Index Page:
┌────────────────────────────────┐
│ [10] [20] [30] [40] [50] [60]  │ ← Full page, sequential
└────────────────────────────────┘

Fragmented Index Page (after many operations):
┌────────────────────────────────┐
│ [10] [__] [30] [__] [50] [__]  │ ← Gaps, wasted space
└────────────────────────────────┘
```

**Page Splits:**

When inserting into a full page:
```
Before (full):
Page 1: [10, 20, 30, 40]  ← Full

Insert 25:
Page 1: [10, 20]           ← Split
Page 2: [25, 30, 40]       ← New page

Result: Pages not contiguous, poor sequential read performance
```

**Maintenance Operations:**

**1. Rebuild Index:**
```sql
ALTER INDEX idx_name REBUILD;
-- Completely recreates index, removes fragmentation
-- Offline operation (locks table)
```

**2. Reorganize Index:**
```sql
ALTER INDEX idx_name REORGANIZE;
-- Defragments leaf level, compacts pages
-- Online operation (minimal locking)
```

**3. Update Statistics:**
```sql
UPDATE STATISTICS users;
-- Refreshes optimizer statistics
-- Helps optimizer make better decisions
```

---

### Summary

**Key Takeaways:**

1. **Data Storage**: Database uses pages (8KB blocks) to store data, managed by buffer manager
2. **Index Types**: Clustered (physical order) vs Non-Clustered (separate structure with pointers)
3. **Data Structures**: B+ Trees are optimal for databases due to linked leaves and range query efficiency
4. **Index Strategy**: Create indexes on frequently queried columns, but balance against write performance
5. **Maintenance**: Regularly rebuild/reorganize indexes to prevent fragmentation

**Performance Impact:**

| Operation | Without Index | With Index | Improvement |
|-----------|--------------|------------|-------------|
| **Point query** | O(n) - scan all rows | O(log n) - tree search | 100-1000x faster |
| **Range query** | O(n) - scan all rows | O(log n + k) - k results | 50-500x faster |
| **Sort** | O(n log n) - sort data | O(1) - already sorted | 10-100x faster |
| **INSERT** | O(1) - append | O(log n) - update index | 2-5x slower |
