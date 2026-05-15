# LSM Tree (Log-Structured Merge-tree)




## Medium

- [SSTables and LSM Trees](https://medium.com/the-developers-diary/sstables-and-lsm-trees-2e4b6c8be251)
- [LSM Trees: the Go-To Data Structure for Databases, Search Engines, and More](https://medium.com/@dwivedi.ankit21/lsm-trees-the-go-to-data-structure-for-databases-search-engines-and-more-c3a48fa469d2)
- [Design Metrics Aggregation System | LSM Tree | Storage Engine](https://medium.com/@eugene-s/design-metrics-aggregation-system-lsm-tree-storage-engine-d52a6d10ac21)



## Introduction

The Log-Structured Merge-tree (LSM-tree) is a data structure designed to provide high write throughput while maintaining good read performance. It was introduced by Patrick O'Neil and others in 1996 and has become the foundation for many modern databases, particularly those optimized for write-heavy workloads.

The key insight behind LSM-trees is that sequential disk writes are significantly faster than random writes. By batching writes in memory and periodically flushing them to disk in sorted order, LSM-trees convert random writes into sequential writes, dramatically improving write performance.

---

## Theory

### The Problem LSM Trees Solve

Traditional databases like PostgreSQL use B-trees for indexing. B-trees are excellent for read-heavy workloads because they maintain data in sorted order on disk, allowing efficient binary search. However, B-trees have a significant drawback for writes: updating a B-tree requires reading a page from disk, modifying it, and writing it back. This results in random I/O operations, which are slow on both HDDs and SSDs.

Consider what happens when you insert a new record into a B-tree:

1. Read the appropriate leaf page from disk
2. Find the insertion point
3. If the page has space, insert and write the page back
4. If the page is full, split it and update parent pages

Each of these operations involves random disk access. When handling thousands or millions of writes per second, this becomes a significant bottleneck.

LSM-trees take a completely different approach: instead of modifying data in place, they append all writes to a log and periodically merge sorted files in the background. This trades some read performance for dramatically better write performance.

### Core Concepts

**Immutability**: Once data is written to disk in an LSM-tree, it is never modified in place. Updates and deletes create new entries rather than modifying existing ones. This simplifies concurrency, enables efficient sequential writes, and makes crash recovery straightforward.

**Write Buffering**: Incoming writes are first collected in an in-memory buffer (called a MemTable). This allows the database to batch many small writes into larger sequential writes to disk.

**Sorted Runs**: When data is flushed from memory to disk, it's written as a sorted file (called an SSTable or Sorted String Table). Multiple sorted files exist at different levels, and background processes merge them to maintain read efficiency.

**Compaction**: As more SSTables accumulate, read performance degrades because queries might need to check many files. Compaction merges multiple SSTables into fewer, larger ones, removing obsolete entries in the process.

---

## Architecture

### High-Level Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              MEMORY                                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                         MemTable                                 │    │
│  │   (In-memory sorted structure - Red-Black Tree / Skip List)     │    │
│  │                                                                  │    │
│  │   Newest writes go here first                                   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Immutable MemTable(s)                         │    │
│  │   (Being flushed to disk, still readable)                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────────────┤
│                               DISK                                       │
│                                                                          │
│  Level 0 (L0):  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                     │
│  (Unsorted,     │SST-1 │ │SST-2 │ │SST-3 │ │SST-4 │   ← Direct flushes  │
│   may overlap)  └──────┘ └──────┘ └──────┘ └──────┘     from MemTable   │
│                                                                          │
│  Level 1 (L1):  ┌────────────────────────────────────────────────┐      │
│  (Sorted,       │              SST-A   SST-B   SST-C              │      │
│   non-overlap)  └────────────────────────────────────────────────┘      │
│                                                                          │
│  Level 2 (L2):  ┌────────────────────────────────────────────────────┐  │
│  (Larger,       │         SST-X    SST-Y    SST-Z    SST-W           │  │
│   non-overlap)  └────────────────────────────────────────────────────┘  │
│                                                                          │
│  Level 3 (L3):  ┌────────────────────────────────────────────────────────┐
│  (Even larger,  │      SST-1    SST-2    SST-3    SST-4    SST-5       │ │
│   non-overlap)  └────────────────────────────────────────────────────────┘
│                                                                          │
│                 ... more levels as data grows ...                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Details

#### 1. Write-Ahead Log (WAL)

Before any write reaches the MemTable, it's first appended to the Write-Ahead Log. The WAL is a simple append-only file that ensures durability. If the database crashes before MemTable contents are flushed to disk, the WAL can be replayed to recover the lost data.

```
┌─────────────────────────────────────────────────────────────┐
│                    Write-Ahead Log (WAL)                     │
├─────────────────────────────────────────────────────────────┤
│ [Seq:1] PUT key1 -> value1                                  │
│ [Seq:2] PUT key2 -> value2                                  │
│ [Seq:3] DELETE key1                                         │
│ [Seq:4] PUT key3 -> value3                                  │
│ [Seq:5] PUT key1 -> value1_updated                          │
│ ...                                                          │
└─────────────────────────────────────────────────────────────┘
```

The WAL is sequential append-only, making it extremely fast to write. It doesn't need to be sorted or indexed since it's only used for crash recovery, not for queries.

#### 2. MemTable

The MemTable is an in-memory sorted data structure that holds recent writes. Common implementations use:

- **Red-Black Trees**: Self-balancing binary search trees with O(log n) insert and lookup
- **Skip Lists**: Probabilistic data structure with O(log n) operations on average, easier to implement concurrent access

When a write comes in:
1. Append to WAL (for durability)
2. Insert into MemTable (for serving reads)

The MemTable has a size threshold (e.g., 64MB). When it reaches this threshold, it becomes "immutable" — no new writes go to it, but reads can still access it while it's being flushed to disk. A new, empty MemTable is created for incoming writes.

#### 3. SSTables (Sorted String Tables)

SSTables are the on-disk components of an LSM-tree. Each SSTable is:

- **Immutable**: Once written, never modified
- **Sorted**: Keys are stored in sorted order
- **Self-contained**: Contains all data needed to read it (data blocks, index, metadata)

SSTable structure:

```
┌─────────────────────────────────────────────────────────────┐
│                         SSTable File                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │                   Data Blocks                      │      │
│  │  ┌─────────────────────────────────────────────┐  │      │
│  │  │ Block 1: key1->val1, key2->val2, key3->val3 │  │      │
│  │  ├─────────────────────────────────────────────┤  │      │
│  │  │ Block 2: key4->val4, key5->val5, key6->val6 │  │      │
│  │  ├─────────────────────────────────────────────┤  │      │
│  │  │ Block 3: key7->val7, key8->val8, key9->val9 │  │      │
│  │  └─────────────────────────────────────────────┘  │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │                   Index Block                      │      │
│  │  Block 1: starts at key1, offset 0               │      │
│  │  Block 2: starts at key4, offset 4096            │      │
│  │  Block 3: starts at key7, offset 8192            │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │                  Bloom Filter                      │      │
│  │  (Probabilistic filter to avoid unnecessary       │      │
│  │   disk reads for keys that don't exist)           │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │                    Metadata                        │      │
│  │  Min key: key1, Max key: key9                     │      │
│  │  Creation time, Compression type, etc.            │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │                     Footer                         │      │
│  │  Offsets to index, bloom filter, metadata          │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Data Blocks**: Contain the actual key-value pairs, typically compressed. Block size is usually 4KB-64KB.

**Index Block**: Maps key ranges to data block offsets, enabling binary search to find the right block.

**Bloom Filter**: A probabilistic data structure that can tell you whether a key definitely doesn't exist (with 100% accuracy) or might exist (with some false positive rate). This avoids reading data blocks for keys that aren't in the SSTable.

**Metadata**: Information like min/max keys, creation timestamp, compression algorithm, and statistics.

#### 4. Levels

SSTables are organized into levels:

**Level 0 (L0)**: SSTables flushed directly from MemTable. These files may have overlapping key ranges because each MemTable is flushed independently without considering other L0 files.

**Level 1+ (L1, L2, ...)**: SSTables at these levels are the result of compaction. Within each level, key ranges don't overlap — each key exists in exactly one SSTable at each level. Each level is typically 10x larger than the previous level.

```
Level Structure Example:

L0:  [1-100]  [50-150]  [80-200]  [10-90]   ← Overlapping ranges
      ↓ Compaction merges into L1
L1:  [1-50] [51-100] [101-150] [151-200]   ← Non-overlapping, sorted ranges
      ↓ Compaction merges into L2  
L2:  [1-100] [101-200] [201-300] [301-400] ← Larger files, non-overlapping
```

---

## Deep Dive: SSTables (Sorted String Tables)

### What is an SSTable?

An SSTable (Sorted String Table) is an immutable, on-disk file format that stores a sequence of key-value pairs sorted by key. The concept was popularized by Google's Bigtable paper in 2006 and has since become the fundamental building block of LSM-tree based storage engines.

The name "Sorted String Table" comes from the original design where keys and values were strings, though modern implementations support arbitrary byte sequences. The "sorted" property is crucial — it enables efficient binary search for lookups and efficient merge operations during compaction.

### Why SSTables Are Immutable

Immutability is a core design principle of SSTables, and it provides several important benefits:

**Simplified Concurrency**: When files never change after being written, readers don't need locks. Multiple threads can read the same SSTable simultaneously without any coordination. Writers create new files rather than modifying existing ones.

**Crash Safety**: An SSTable is either fully written or not present at all. There's no risk of partial writes or corrupted pages. If a crash occurs during SSTable creation, the incomplete file is simply discarded on recovery.

**Efficient Caching**: Since the content never changes, operating system page cache and application-level caches remain valid indefinitely. There's no cache invalidation complexity.

**Simple Backup and Replication**: Copying immutable files is straightforward. You can back up SSTables by simply copying them, and they can be transferred to replicas without coordination.

**Compression Friendly**: An entire SSTable can be analyzed to choose optimal compression parameters. Compression dictionaries can be built from the full content.

### SSTable File Format (Detailed)

While exact formats vary between implementations (LevelDB, RocksDB, Cassandra), the general structure is consistent:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SSTable File Layout                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ╔═══════════════════════════════════════════════════════════════════╗  │
│  ║                         DATA BLOCKS                                ║  │
│  ║                                                                    ║  │
│  ║  ┌──────────────────────────────────────────────────────────────┐ ║  │
│  ║  │ Block 0 (4KB-64KB compressed)                                │ ║  │
│  ║  │  ┌────────────────────────────────────────────────────────┐  │ ║  │
│  ║  │  │ Shared key prefix length | Unshared key length | Value │  │ ║  │
│  ║  │  │ Entry 1: [0|5|100] "apple" -> "red fruit..."           │  │ ║  │
│  ║  │  │ Entry 2: [3|4|85] "tion" -> "..." (key: "appleton")    │  │ ║  │
│  ║  │  │ Entry 3: [0|6|120] "banana" -> "yellow fruit..."       │  │ ║  │
│  ║  │  │ ...                                                     │  │ ║  │
│  ║  │  │ [Restart points array] [Restart count]                 │  │ ║  │
│  ║  │  └────────────────────────────────────────────────────────┘  │ ║  │
│  ║  │  [Block checksum - CRC32]                                    │ ║  │
│  ║  └──────────────────────────────────────────────────────────────┘ ║  │
│  ║                                                                    ║  │
│  ║  ┌──────────────────────────────────────────────────────────────┐ ║  │
│  ║  │ Block 1                                                      │ ║  │
│  ║  │  Entry N: "cherry" -> "..."                                  │ ║  │
│  ║  │  Entry N+1: "date" -> "..."                                  │ ║  │
│  ║  │  ...                                                          │ ║  │
│  ║  └──────────────────────────────────────────────────────────────┘ ║  │
│  ║                                                                    ║  │
│  ║  ... more data blocks ...                                         ║  │
│  ║                                                                    ║  │
│  ╠═══════════════════════════════════════════════════════════════════╣  │
│  ║                        FILTER BLOCK                                ║  │
│  ║  (Bloom filters for each data block or for entire file)          ║  │
│  ║                                                                    ║  │
│  ║  Block 0 filter: [bit array - 2KB]                               ║  │
│  ║  Block 1 filter: [bit array - 2KB]                               ║  │
│  ║  ...                                                              ║  │
│  ║  OR: Full file Bloom filter [bit array - proportional to keys]   ║  │
│  ╠═══════════════════════════════════════════════════════════════════╣  │
│  ║                      META INDEX BLOCK                              ║  │
│  ║  (Index of metadata sections)                                     ║  │
│  ║                                                                    ║  │
│  ║  "filter.bloom" -> offset, size                                   ║  │
│  ║  "properties" -> offset, size                                     ║  │
│  ║  "compression_dict" -> offset, size (if present)                  ║  │
│  ╠═══════════════════════════════════════════════════════════════════╣  │
│  ║                        INDEX BLOCK                                 ║  │
│  ║  (Maps keys to data block locations)                              ║  │
│  ║                                                                    ║  │
│  ║  Entry: separator_key >= last_key_of_block, block_handle          ║  │
│  ║                                                                    ║  │
│  ║  "banana"  -> Block 0, offset 0, size 4096                        ║  │
│  ║  "date"    -> Block 1, offset 4096, size 4096                     ║  │
│  ║  "fig"     -> Block 2, offset 8192, size 3584                     ║  │
│  ║  ...                                                              ║  │
│  ╠═══════════════════════════════════════════════════════════════════╣  │
│  ║                         FOOTER                                     ║  │
│  ║  (Fixed size, always at end of file)                              ║  │
│  ║                                                                    ║  │
│  ║  Meta index block handle: offset, size                            ║  │
│  ║  Index block handle: offset, size                                 ║  │
│  ║  Padding (to fixed size)                                          ║  │
│  ║  Magic number (for format verification)                           ║  │
│  ╚═══════════════════════════════════════════════════════════════════╝  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Block Internals

Data blocks are where key-value pairs are actually stored. They're designed for both space efficiency and quick access.

#### Prefix Compression

Consecutive keys in sorted order often share common prefixes. For example:

```
user:1000:profile
user:1000:settings  
user:1000:sessions
user:1001:profile
user:1001:settings
```

Storing each key fully would be wasteful. Instead, prefix compression stores:

```
Entry format: [shared_prefix_len | unshared_len | value_len | unshared_key_bytes | value_bytes]

Key "user:1000:profile"   -> [0  | 18 | ...] "user:1000:profile" ...
Key "user:1000:settings"  -> [10 |  8 | ...] "settings" ...     (shares "user:1000:")
Key "user:1000:sessions"  -> [10 |  8 | ...] "sessions" ...     (shares "user:1000:")
Key "user:1001:profile"   -> [5  | 13 | ...] "1001:profile" ... (shares "user:")
Key "user:1001:settings"  -> [10 |  8 | ...] "settings" ...     (shares "user:1001:")
```

This can reduce key storage by 50-80% for keys with common prefixes.

#### Restart Points

Prefix compression creates a dependency chain — to read key N, you need to read keys 0 through N-1 to reconstruct the full key. This would make random access O(n) within a block.

Restart points break this chain. Every K entries (typically every 16), the full key is stored without prefix compression. These restart points are indexed at the end of the block:

```
Block with restart interval = 4:

Entry 0:  [0|10|...] "apple" (full key - restart point)
Entry 1:  [3| 7|...] "tion"  (prefix compressed)
Entry 2:  [3| 5|...] "ause"  (prefix compressed)  
Entry 3:  [3| 6|...] "ostate" (prefix compressed)
Entry 4:  [0|6|...] "banana" (full key - restart point)  ← Restart
Entry 5:  [4|2|...] "nd"     (prefix compressed)
Entry 6:  [4|4|...] "nner"   (prefix compressed)
Entry 7:  [4|5|...] "nnock"  (prefix compressed)
Entry 8:  [0|6|...] "cherry" (full key - restart point)  ← Restart
...

Restart points array: [0, 4, 8, ...]
Restart count: 3
```

To find a key, binary search the restart points first (O(log R) where R is number of restarts), then linear scan within the restart interval (O(K) where K is restart interval). Total: O(log R + K) which is essentially O(log N) for the block.

#### Block Compression

Each data block is compressed independently using algorithms like:

- **Snappy**: Fast compression/decompression, moderate ratio (~2-4x)
- **LZ4**: Very fast, good for read-heavy workloads
- **Zstd**: Excellent ratio (~4-10x), configurable speed/ratio tradeoff
- **Zlib**: Traditional choice, good ratio, slower than modern alternatives

Compressing individual blocks rather than the entire file allows random access — you only decompress the blocks you need to read.

```
Block Compression Example:

Original block (16KB of key-value data)
        │
        ▼ Compression (e.g., Zstd level 3)
        │
Compressed block (4KB)
        │
        ▼ Optional: Add compression type byte
        │
[Type: Zstd][Compressed data: 4KB][CRC32 checksum]
```

### Index Block Structure

The index block enables efficient lookup of which data block contains a given key. Each entry in the index contains:

1. **Separator key**: A key that is greater than or equal to the last key in the corresponding data block, and less than the first key in the next data block
2. **Block handle**: The offset and size of the data block in the file

```
Index Block Lookup Example:

Index entries:
  "banana"  -> Block 0 at offset 0, size 4096
  "date"    -> Block 1 at offset 4096, size 4096  
  "grapefruit" -> Block 2 at offset 8192, size 3584

Searching for "cherry":
  1. Binary search index: "cherry" < "date" but > "banana"
  2. Therefore, "cherry" is in Block 1 (if it exists)
  3. Read Block 1 from offset 4096

Searching for "elderberry":
  1. Binary search index: "elderberry" > "date" but < "grapefruit"
  2. Therefore, "elderberry" is in Block 2 (if it exists)
  3. Read Block 2 from offset 8192
```

For very large SSTables, the index itself might be too large to fit in memory or a single block. Multi-level indexes (index of index blocks) solve this:

```
Top-level index:
  "mango" -> Index Block A
  "zebra" -> Index Block B

Index Block A:
  "banana" -> Data Block 0
  "date" -> Data Block 1
  ...
  
Index Block B:
  "orange" -> Data Block N
  "peach" -> Data Block N+1
  ...
```

### Properties Block (Metadata)

The properties block stores information about the SSTable:

```
SSTable Properties:

# File Information
data_size: 104857600          # Size of data blocks (100 MB)
index_size: 1048576           # Size of index (1 MB)
filter_size: 262144           # Size of bloom filter (256 KB)
raw_key_size: 52428800        # Total size of all keys
raw_value_size: 78643200      # Total size of all values

# Entry Statistics
num_entries: 1000000          # Number of key-value pairs
num_data_blocks: 25000        # Number of data blocks
num_deletions: 50000          # Number of tombstones

# Key Range
min_key: "user:0000000001"
max_key: "user:0001000000"
min_timestamp: 1640000000000
max_timestamp: 1640100000000

# Compression
compression: zstd
compression_ratio: 0.38       # Compressed/Uncompressed

# Creation Info
creation_time: 2024-01-15T10:30:00Z
file_version: 2
```

This metadata enables quick decisions about whether to search an SSTable without reading any data blocks.

### SSTable Creation Process

When a MemTable is flushed or compaction produces new files, SSTable creation follows this process:

```
SSTable Creation Flow:

┌─────────────────────────────────────────────────────────────────────┐
│ 1. Open new file for writing                                        │
│    - Create temporary file (e.g., "000123.sst.tmp")                 │
│    - Buffer writes for efficiency                                    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Write data blocks                                                 │
│    - Iterate through sorted key-value pairs                         │
│    - Build block with prefix compression                            │
│    - When block reaches size limit:                                 │
│      a. Compress the block                                          │
│      b. Calculate checksum                                          │
│      c. Write to file                                               │
│      d. Add entry to index                                          │
│      e. Add keys to Bloom filter                                    │
│      f. Start new block                                             │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. Write filter block (Bloom filters)                               │
│    - Serialize the bloom filter data                                │
│    - Write to file                                                   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. Write meta index block                                           │
│    - Record offsets of filter, properties, etc.                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. Write index block                                                 │
│    - Write all index entries accumulated during data block writes   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 6. Write footer                                                      │
│    - Meta index offset and size                                      │
│    - Index offset and size                                          │
│    - Magic number                                                    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 7. Finalize                                                          │
│    - Flush all buffers                                               │
│    - fsync to ensure durability                                      │
│    - Rename temp file to final name ("000123.sst")                  │
│    - Atomic rename ensures complete file or nothing                  │
└─────────────────────────────────────────────────────────────────────┘
```

### SSTable Lookup Process

Reading from an SSTable involves multiple steps, but optimizations make common cases fast:

```
SSTable Lookup for key "user:12345":

Step 1: Quick checks (in memory)
├── Is key < min_key? → Definitely not here, skip
├── Is key > max_key? → Definitely not here, skip
└── Check Bloom filter → Definitely not here OR maybe here

Step 2: Index lookup (usually cached)
├── Binary search index block for key  
├── Find: "user:10000" -> Block 5, "user:20000" -> Block 6
└── Key "user:12345" falls in Block 5

Step 3: Read data block
├── Check block cache → If hit, use cached block
├── If miss: Read Block 5 from disk (offset, size from index)
├── Decompress block
└── Cache decompressed block for future reads

Step 4: Search within block  
├── Binary search restart points
├── Linear scan from appropriate restart point
└── Return value if found, or "not found"
```

### SSTable Merging (Compaction Detail)

When multiple SSTables are compacted, they're merged using a k-way merge algorithm:

```
Merging 3 SSTables:

SST-1:  [a:1] [c:3] [e:5] [g:7]
SST-2:  [b:2] [c:4] [f:6]           (c:4 is newer than c:3)
SST-3:  [a:0] [d:4] [e:TOMBSTONE]   (a:0 is older, e deleted)

Merge Process:
┌─────────────────────────────────────────────────────────────────┐
│                     K-Way Merge Iterator                         │
│                                                                  │
│  Priority Queue (min-heap by key, then by SST recency):         │
│                                                                  │
│  Initial: [(a,SST-1), (a,SST-3), (b,SST-2), (c,SST-1)...]       │
│                                                                  │
│  Pop (a, SST-1): Output a:1                                     │
│  Pop (a, SST-3): Skip (same key, older)                         │
│  Pop (b, SST-2): Output b:2                                     │
│  Pop (c, SST-1): Skip (c from SST-2 is newer)                   │
│  Pop (c, SST-2): Output c:4                                     │
│  Pop (d, SST-3): Output d:4                                     │
│  Pop (e, SST-1): Skip (e has tombstone in SST-3)                │
│  Pop (e, SST-3): Is tombstone, drop if bottom level             │
│  Pop (f, SST-2): Output f:6                                     │
│  Pop (g, SST-1): Output g:7                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

Output SSTable:  [a:1] [b:2] [c:4] [d:4] [f:6] [g:7]
(e was deleted, old a and c versions were dropped)
```

### SSTable Naming and Organization

SSTables are typically named with a sequence number and organized into levels:

```
Database Directory Structure:

/db/
├── MANIFEST-000015              # Current database state
├── CURRENT                      # Points to current MANIFEST
├── LOG                          # Operating log
├── 000010.log                   # Write-ahead log
├── 000011.sst                   # Level 0 SSTable
├── 000012.sst                   # Level 0 SSTable  
├── 000013.sst                   # Level 1 SSTable
├── 000014.sst                   # Level 1 SSTable
├── 000015.sst                   # Level 2 SSTable
└── ...

MANIFEST tracks which SSTables belong to which level:
  Level 0: [000011.sst, 000012.sst]
  Level 1: [000013.sst, 000014.sst]
  Level 2: [000015.sst]
```

### SSTable Size Considerations

Choosing the right SSTable size involves trade-offs:

**Smaller SSTables (e.g., 8-32 MB):**
- Faster compaction (less data to read/write)
- More files to manage
- More Bloom filters to check
- Better for workloads with locality

**Larger SSTables (e.g., 128-512 MB):**
- Fewer files to manage
- Better compression ratios
- Longer compaction pauses
- Better for sequential access patterns

**Typical configurations:**
- LevelDB default: 2 MB
- RocksDB default: 64 MB
- Cassandra default: 160 MB (configurable)

### SSTable Statistics and Monitoring

Production systems track SSTable metrics:

```
Per-SSTable Metrics:
├── Size (bytes on disk)
├── Uncompressed size
├── Number of entries
├── Number of deletions (tombstones)
├── Number of reads served
├── Bloom filter efficiency (false positive rate)
├── Age (time since creation)
└── Read latency distribution

Aggregate Metrics:
├── Total number of SSTables
├── SSTables per level
├── Total disk usage
├── Compaction pending bytes
├── Read amplification (avg SSTables checked per read)
└── Write amplification (total bytes written / user bytes)
```

### Comparison: SSTable vs Other File Formats

| Aspect | SSTable | B-tree Files | Append-Only Log |
|--------|---------|--------------|-----------------|
| Mutability | Immutable | Mutable in-place | Append-only |
| Key Order | Sorted | Sorted (tree structure) | Insertion order |
| Point Lookup | O(log n) binary search | O(log n) tree traversal | O(n) scan |
| Range Scan | Excellent (sequential) | Good | Poor |
| Space Efficiency | Good (compression) | Moderate | Grows indefinitely |
| Write Pattern | Bulk sequential | Random | Sequential append |
| Concurrency | Lock-free reads | Requires locking | Lock-free reads |

---

## Write Operations

### Write Path Flow

```
                          Write Request (PUT key -> value)
                                      │
                                      ▼
                    ┌─────────────────────────────────┐
                    │  1. Append to Write-Ahead Log   │
                    │     (Ensures durability)        │
                    └─────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────┐
                    │  2. Insert into MemTable        │
                    │     (In-memory sorted tree)     │
                    └─────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────┐
                    │  3. Return success to client    │
                    │     (Write is durable now)      │
                    └─────────────────────────────────┘
                                      │
                        (Background, asynchronous)
                                      ▼
                    ┌─────────────────────────────────┐
                    │  4. When MemTable is full:      │
                    │     - Mark as immutable         │
                    │     - Create new MemTable       │
                    │     - Flush to L0 SSTable       │
                    │     - Delete old WAL segment    │
                    └─────────────────────────────────┘
```

### Step-by-Step Write Process

**Step 1: Write to WAL**

The write is first appended to the Write-Ahead Log. This is a sequential write to the end of a file, which is extremely fast. The WAL entry includes:
- Sequence number (monotonically increasing)
- Operation type (PUT or DELETE)
- Key and value

Once the WAL write is acknowledged (fsync'd to disk), the write is durable. Even if the system crashes, it can be recovered from the WAL.

**Step 2: Insert into MemTable**

The key-value pair is inserted into the in-memory MemTable. Since the MemTable is a sorted structure (skip list or red-black tree), insertion takes O(log n) time. This is an in-memory operation, so it's very fast.

If the key already exists in the MemTable, the new value simply overwrites it. The MemTable only maintains the latest value for each key.

**Step 3: Return to Client**

At this point, the write is complete from the client's perspective. The data is:
- Durable (in the WAL)
- Queryable (in the MemTable)

**Step 4: Background Flush**

When the MemTable reaches its size threshold:

1. The current MemTable is marked as "immutable" — it can still be read but accepts no new writes
2. A new, empty MemTable is created for incoming writes
3. A new WAL segment is started
4. A background thread flushes the immutable MemTable to disk as a new L0 SSTable
5. Once the SSTable is written, the old WAL segment can be deleted

### Write Amplification

One important characteristic of LSM-trees is **write amplification** — the ratio of bytes written to storage versus bytes written by the application. Due to compaction, the same data may be written multiple times as it moves through levels.

For example, with a typical 10x size ratio between levels:
- Data is written to L0 when flushed from MemTable
- Later compacted into L1 (write #2)
- Later compacted into L2 (write #3)
- And so on...

This means the write amplification can be 10-30x in practice. However, since all writes are sequential, the overall throughput is still much better than B-trees for write-heavy workloads.

---

## Read Operations

### Read Path Flow

```
                           Read Request (GET key)
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│   MemTable    │          │   Immutable   │          │    SSTables   │
│  (in-memory)  │          │   MemTables   │          │   (on-disk)   │
└───────┬───────┘          └───────┬───────┘          └───────┬───────┘
        │                          │                          │
        ▼                          ▼                          ▼
    Found? ─────Yes────────────────┼──────────────────────────┤
        │                          │                          │
        No                     Found? ─────Yes────────────────┤
        │                          │                          │
        ▼                          No                         │
      Continue                     │                          │
        │                          ▼                          │
        └──────────────────► Search SSTables ◄────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
              ┌─────────┐    ┌─────────┐    ┌─────────┐
              │   L0    │    │   L1    │    │   L2    │  ...
              │SSTables │    │SSTables │    │SSTables │
              └────┬────┘    └────┬────┘    └────┬────┘
                   │              │              │
            Check all L0    Binary search  Binary search
            (may overlap)   to find file   to find file
                   │              │              │
                   ▼              ▼              ▼
              ┌─────────────────────────────────────┐
              │     For each candidate SSTable:     │
              │  1. Check Bloom Filter              │
              │  2. If might exist: binary search   │
              │     index block                     │
              │  3. Read and search data block      │
              └─────────────────────────────────────┘
                                   │
                                   ▼
                           Return result
                    (most recent value found)
```

### Step-by-Step Read Process

**Step 1: Check MemTable**

The read first checks the active MemTable. Since it's an in-memory sorted structure, lookup is O(log n). If the key is found, return the value immediately. If a tombstone (deletion marker) is found, return "not found."

**Step 2: Check Immutable MemTables**

If not found in the active MemTable, check any immutable MemTables (those being flushed). These are also in memory, so this is fast. Check them from newest to oldest.

**Step 3: Search SSTables by Level**

If still not found, search the on-disk SSTables, starting from the newest level (L0) and progressing to older levels.

**For Level 0:**
L0 SSTables may have overlapping key ranges, so you must potentially check all of them. For each SSTable:

1. Check if the key is within the SSTable's min/max key range (from metadata)
2. Check the Bloom filter — if it says "definitely not present," skip this SSTable
3. If the Bloom filter says "might be present," binary search the index block to find the right data block
4. Read and decompress the data block
5. Binary search within the block for the key

**For Level 1 and above:**
SSTables at these levels have non-overlapping key ranges. Use binary search on SSTable metadata to find the one SSTable that might contain the key, then search within it.

**Step 4: Return Result**

Return the first value found (from the newest source). If no value is found at any level, return "not found."

### Read Amplification

LSM-trees have **read amplification** — a single read might need to check multiple SSTables. In the worst case:
- Check MemTable
- Check N L0 SSTables
- Check one SSTable per level (L1, L2, ...)

Mitigation strategies:
- **Bloom filters**: Avoid reading SSTables that definitely don't contain the key
- **Block cache**: Keep frequently accessed data blocks in memory
- **Key-range metadata**: Skip SSTables where the key is outside min/max range
- **Compaction**: Reduce number of SSTables to search

---

## Update Operations

### How Updates Work

Updates in LSM-trees are simple: they're just writes. There's no "update in place" operation. When you update a key:

1. Write the new value to the WAL
2. Insert the new key-value pair into the MemTable
3. The new entry has a higher sequence number than the old one

When reading, the system always returns the entry with the highest sequence number, which is the most recent value.

```
Timeline of updates to key "user:123":

Time T1:  Write (user:123 -> {name: "Alice", age: 25})  [Seq: 100]
          └── Goes to MemTable, eventually flushed to L2

Time T2:  Write (user:123 -> {name: "Alice", age: 26})  [Seq: 500]
          └── Goes to MemTable, eventually flushed to L1

Time T3:  Write (user:123 -> {name: "Alice", age: 27})  [Seq: 800]
          └── Currently in MemTable

Read at T3:
  1. Check MemTable → Found! Seq: 800, age: 27 ← Return this
  2. (Don't need to check SSTables)

Read at T2.5 (if MemTable was just flushed):
  1. Check MemTable → Not found
  2. Check L0 → Not found  
  3. Check L1 → Found! Seq: 500, age: 26 ← Return this
  4. (Don't check L2, already found)
```

### Space Overhead

Since updates create new entries rather than modifying old ones, multiple versions of the same key may exist across different SSTables. This creates temporary space overhead.

The compaction process eventually merges these entries, keeping only the latest version. Until compaction runs, you may have:
- The current value in MemTable or L0
- One or more obsolete values in lower levels

This is the price of immutability but enables the high write performance that LSM-trees are known for.

---

## Write Conflict Resolution Using Timestamps

### The Conflict Problem in LSM Trees

In any storage system that allows concurrent writes, conflicts can occur when multiple writers attempt to update the same key simultaneously. LSM-trees handle this elegantly using timestamps (or sequence numbers) without requiring locks or coordination between writers.

### How LSM Trees Avoid Traditional Locking

Traditional databases often use locks to prevent concurrent modifications to the same data:

```
Traditional Locking Approach (B-trees):

Writer A                          Writer B
   │                                  │
   ▼                                  ▼
Lock(key: user:123)              Lock(key: user:123)
   │                                  │
   ▼                                  ▼
Write value                       BLOCKED
   │                               (waiting)
   ▼                                  │
Unlock                                │
   │                                  ▼
                                  Acquire lock
                                      │
                                      ▼
                                  Write value
                                      │
                                      ▼
                                  Unlock
```

This creates contention. Writers wait for each other, reducing throughput.

LSM-trees take a fundamentally different approach: **they don't prevent concurrent writes at all**. Instead, every write is assigned a unique timestamp, and conflicts are resolved at read time using a "last write wins" (LWW) strategy.

```
LSM-Tree Approach (No Locking):

Writer A                          Writer B
   │                                  │
   ▼                                  ▼
Assign timestamp: 1000           Assign timestamp: 1001
   │                                  │
   ▼                                  ▼
Append to WAL                    Append to WAL
   │                                  │
   ▼                                  ▼
Insert to MemTable               Insert to MemTable
   │                                  │
   ▼                                  ▼
Done!                            Done!

Both writes succeed without waiting!
Conflict resolved at read time: timestamp 1001 wins
```

### Timestamp and Sequence Number Mechanics

Each entry in an LSM-tree is associated with a **timestamp** or **sequence number** that determines its version. Different databases use different terminology and granularity:

#### Sequence Numbers (LevelDB, RocksDB)

LevelDB and RocksDB use monotonically increasing 64-bit sequence numbers:

```
Write Entry Structure:

┌─────────────────────────────────────────────────────────────────────┐
│                          Internal Key                                │
├─────────────────────────────────────────────────────────────────────┤
│  User Key          │  Sequence Number (64-bit)  │  Type (8-bit)    │
│  "user:123"        │  1708300000000001          │  PUT (0x01)      │
└─────────────────────────────────────────────────────────────────────┘

Type values:
  0x00 = DELETE (tombstone)
  0x01 = PUT (value)
  0x02 = MERGE (for merge operators)
```

The sequence number is assigned by a single writer thread or using atomic increment operations. Even if multiple threads write concurrently, each gets a unique sequence number.

#### Timestamps (Cassandra, HBase)

Cassandra and HBase use timestamps, typically microsecond-precision Unix time:

```
Cell Structure in Cassandra:

┌─────────────────────────────────────────────────────────────────────┐
│                              Cell                                    │
├─────────────────────────────────────────────────────────────────────┤
│  Column Name  │  Value         │  Timestamp (microseconds)  │ TTL  │
│  "email"      │  "a@b.com"     │  1708300000000000          │ 0    │
└─────────────────────────────────────────────────────────────────────┘
```

Timestamps can be:
- **Server-assigned**: The database assigns the current time
- **Client-provided**: The application specifies the timestamp

### Last Write Wins (LWW) Resolution

The fundamental conflict resolution rule is simple: **the entry with the highest timestamp wins**.

```
Conflict Resolution Example:

Two concurrent writes to the same key:

Writer A (timestamp: 1000):  user:123 -> {balance: 100}
Writer B (timestamp: 1001):  user:123 -> {balance: 200}

After both writes complete, the MemTable might contain:
┌──────────────────────────────────────────────────────┐
│                      MemTable                         │
├──────────────────────────────────────────────────────┤
│  user:123 @ ts:1001 -> {balance: 200}                │
│  user:123 @ ts:1000 -> {balance: 100}                │
└──────────────────────────────────────────────────────┘

When reading user:123:
  → Find entry with ts:1001 (highest timestamp)
  → Return {balance: 200}
  
Writer B wins because it has the higher timestamp.
```

### Sorting Keys by Timestamp

To enable efficient timestamp-based resolution, LSM-trees often sort by (key, timestamp_descending):

```
Sorting Order in SSTables:

┌─────────────────────────────────────────────────────────────────────┐
│                   SSTable (sorted order)                             │
├─────────────────────────────────────────────────────────────────────┤
│  (user:100, ts:500)  -> value_A                                     │
│  (user:100, ts:300)  -> value_B    ← older version of same key      │
│  (user:101, ts:800)  -> value_C                                     │
│  (user:101, ts:400)  -> value_D    ← older version of same key      │
│  (user:102, ts:600)  -> value_E                                     │
└─────────────────────────────────────────────────────────────────────┘

When searching for user:100:
  → Binary search finds (user:100, ts:500) first
  → This is the highest timestamp for user:100
  → Return value_A immediately, no need to check older versions
```

### Multi-Version Concurrency Control (MVCC)

Many LSM-tree databases support MVCC, where readers can access historical versions:

```
MVCC Read Example:

Current state:
  user:123 @ ts:1000 -> {balance: 100}
  user:123 @ ts:800  -> {balance: 75}
  user:123 @ ts:500  -> {balance: 50}

Transaction started at timestamp 800 reads user:123:
  → Scan for user:123 with ts <= 800
  → Return {balance: 75}  (the value visible at ts:800)

Current read (no snapshot):
  → Return {balance: 100}  (the latest value)

This allows consistent point-in-time queries.
```

### Handling Clock Skew in Distributed Systems

In distributed LSM-tree databases (Cassandra, CockroachDB), different nodes may have slightly different clocks. This can cause unexpected conflict resolution:

```
Clock Skew Problem:

Node A (clock accurate):     timestamp = 1000
Node B (clock 5 seconds fast): timestamp = 1005

Both nodes write user:123 at the "same" real time.

Node B wins because its clock is ahead, even though
from a real-world perspective, the writes were simultaneous.
```

#### Solutions to Clock Skew

**1. Hybrid Logical Clocks (HLC)**

Used by CockroachDB and others. Combines physical time with a logical counter:

```
HLC Structure:
┌─────────────────────────────────────────┐
│  Physical Time (wall clock)  │ Logical │
│  1708300000                  │ 001     │
└─────────────────────────────────────────┘

When an event happens:
  - Use max(local_physical_time, last_seen_physical_time)
  - If physical times are equal, increment logical counter
  
This ensures:
  - Causally related events are correctly ordered
  - Clock skew doesn't cause old values to overwrite new ones
```

**2. Vector Clocks**

Track causality by maintaining a vector of counters for each node:

```
Vector Clock Example:

Node A writes: user:123 -> value_A, clock = {A:1, B:0}
Node B writes: user:123 -> value_B, clock = {A:0, B:1}

These clocks are not comparable (neither dominates the other).
This is a TRUE CONFLICT requiring application-level resolution.

If Node A later reads Node B's write and then writes again:
  clock = {A:2, B:1}  ← This dominates {A:0, B:1}, so it wins
```

**3. Last Write Wins with Lamport Timestamps**

Simple approach: each write increments the timestamp beyond any previously seen value:

```
Lamport Timestamp:

Node A sees timestamp 1000, writes with timestamp 1001
Node B sees timestamp 1005 from Node A, writes with timestamp 1006

Even if Node B's wall clock says 1000, it uses 1006
because it knows about timestamp 1005.
```

### Conflict Resolution at Compaction Time

During compaction, the conflict resolution becomes permanent:

```
Compaction Conflict Resolution:

Input SSTables:
  SST-1: user:123 @ ts:1000 -> {balance: 100}
  SST-2: user:123 @ ts:1001 -> {balance: 200}
  SST-3: user:123 @ ts:800  -> {balance: 50}

Compaction Process:
  1. Merge all entries for user:123
  2. Sort by timestamp descending: [ts:1001, ts:1000, ts:800]
  3. Keep only the highest timestamp version (unless MVCC retention)
  
Output SSTable:
  user:123 @ ts:1001 -> {balance: 200}
  
Older versions (ts:1000, ts:800) are garbage collected.
```

### Application-Level Conflict Resolution

While LWW is the default, some applications need custom conflict resolution:

#### 1. Merge Operators (RocksDB)

Instead of replacing values, merge them:

```
Merge Operator Example (Counter):

Initial: counter:page_views @ ts:100 -> 500

Write 1: MERGE counter:page_views @ ts:200 -> +10
Write 2: MERGE counter:page_views @ ts:201 -> +5

Resolution:
  Apply merges in timestamp order: 500 + 10 + 5 = 515
  
Result: counter:page_views -> 515
```

#### 2. Conflict-Free Replicated Data Types (CRDTs)

Data structures designed to merge automatically without conflicts:

```
CRDT Example (G-Counter - Grow-only Counter):

Node A: {A: 5, B: 0} = 5 total
Node B: {A: 0, B: 3} = 3 total

Merge: {A: 5, B: 3} = 8 total

Both increments are preserved, order doesn't matter.
```

#### 3. Read Repair with User Resolution

Cassandra's approach for last-write-wins conflicts:

```
Read Repair:

Client reads user:123 from 3 replicas:
  Replica 1: {balance: 100} @ ts:1000
  Replica 2: {balance: 200} @ ts:1001
  Replica 3: {balance: 100} @ ts:1000

Coordinator sees conflict:
  → Returns ts:1001 version to client (LWW)
  → Background: repairs Replica 1 and 3 to have ts:1001 version
```

### Timestamp Best Practices

**1. Use Server-Side Timestamps When Possible**

Client clocks are unreliable. Server-assigned timestamps ensure consistency:

```go
// Bad: Client-provided timestamp
db.Put("user:123", value, time.Now().UnixNano())  // Client clock may be wrong

// Good: Server-assigned timestamp
db.Put("user:123", value)  // Server assigns timestamp internally
```

**2. Include Timestamps in Application Data for Debugging**

Store when the write logically occurred, separate from the LSM timestamp:

```json
{
  "user_id": "123",
  "balance": 100,
  "updated_at": "2024-02-15T10:30:00Z",  // Application timestamp
  "updated_by": "service-A"
}
// LSM internal timestamp: 1708300000000001
```

**3. Consider Idempotency for Retries**

If a write fails and is retried, it may get a different timestamp:

```
First attempt:   ts:1000, FAILED (network error, but may have committed)
Retry:           ts:1001, SUCCESS

Both writes might exist! Design operations to be idempotent:
  ✗ Bad:  INCREMENT balance BY 100
  ✓ Good: SET balance TO 200 (idempotent, retry-safe)
```

### Trade-offs of Timestamp-Based Resolution

| Aspect | Advantage | Disadvantage |
|--------|-----------|--------------|
| **Concurrency** | No locks, high throughput | Lost updates possible |
| **Simplicity** | Easy to implement | May not match business logic |
| **Ordering** | Deterministic resolution | Clock skew can cause issues |
| **Network Partitions** | Writes succeed even during partitions | Conflicts resolved after healing |
| **Debugging** | Clear "winner" for each conflict | Hard to understand why value changed |

---

## Delete Operations

### Tombstones

Deleting a key in an LSM-tree doesn't immediately remove it from disk. Instead, the deletion is recorded as a special marker called a **tombstone**.

```
Delete key "user:123":

1. Write tombstone to WAL:
   [Seq: 900] DELETE user:123

2. Insert tombstone into MemTable:
   user:123 -> TOMBSTONE (Seq: 900)
```

### Why Tombstones Are Necessary

Since SSTables are immutable, we can't modify them to remove a deleted key. And since reads check sources from newest to oldest, we need a way to indicate that older values should be ignored.

When a read encounters a tombstone:
1. Stop searching (the key was deleted)
2. Return "not found" to the client

Without the tombstone, a read would continue to older SSTables and potentially find an obsolete value that should have been deleted.

```
Without tombstones (WRONG):
  L0: (empty)
  L1: user:123 -> {name: "Alice"}  ← This was deleted!
  
  GET user:123
  → Check L0: not found
  → Check L1: found!
  → Return {name: "Alice"}  ← WRONG! This key was deleted.

With tombstones (CORRECT):
  L0: user:123 -> TOMBSTONE
  L1: user:123 -> {name: "Alice"}
  
  GET user:123
  → Check L0: found TOMBSTONE
  → Return "not found"  ← CORRECT!
```

### Tombstone Cleanup

Tombstones can't be removed immediately because they need to "shadow" older values in lower levels. A tombstone can only be safely deleted when:

1. It's been compacted to the lowest level, AND
2. All SSTables in lower levels that might contain the key have been processed

In practice, tombstones are cleaned up during compaction when the compaction reaches the bottom level and no older values can exist.

### Range Deletes

Some LSM-tree implementations support **range tombstones** for deleting a range of keys efficiently:

```
DELETE FROM users WHERE id >= 1000 AND id < 2000

Instead of writing 1000 individual tombstones:
  Range tombstone: [1000, 2000) -> DELETED

Reads check if the key falls within any range tombstone.
```

This is more efficient for bulk deletes but adds complexity to the read path.

---

## Compaction

### Why Compaction Is Necessary

Without compaction, LSM-trees would become increasingly inefficient:

1. **Read amplification increases**: More SSTables to search
2. **Space amplification increases**: Multiple copies of the same key across levels
3. **Tombstone accumulation**: Deleted keys continue consuming space

Compaction merges multiple SSTables into fewer, larger ones, removing obsolete entries in the process.

### Compaction Process

```
                    Compaction (L0 → L1 example)
                    
Before Compaction:
                    
L0:  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
     │ a-f  │ │ c-k  │ │ b-h  │ │ e-m  │  ← 4 overlapping SSTables
     └──────┘ └──────┘ └──────┘ └──────┘
     
L1:  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
     │ a-d  │ │ e-h  │ │ i-l  │ │ m-p  │  ← 4 non-overlapping SSTables
     └──────┘ └──────┘ └──────┘ └──────┘


Compaction Steps:

1. Select L0 files to compact (e.g., all 4)
   Key range: a-m

2. Find overlapping L1 files (a-d, e-h, i-l, m-p)
   All 4 overlap with a-m

3. Read all selected files, merge-sort by key:
   
   ┌─────────────────────────────────────────────────────────┐
   │                    Merge Iterator                        │
   │                                                          │
   │  Inputs: L0-1, L0-2, L0-3, L0-4, L1-1, L1-2, L1-3, L1-4 │
   │                                                          │
   │  For each key, keep only the newest version              │
   │  Skip tombstones shadowing nothing (bottom level)        │
   │                                                          │
   └─────────────────────────────────────────────────────────┘

4. Write new SSTables to L1:

After Compaction:

L0:  (empty - all files were compacted)
     
L1:  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
     │ a-c  │ │ d-f  │ │ g-i  │ │ j-l  │ │ m-p  │  ← New, merged files
     └──────┘ └──────┘ └──────┘ └──────┘ └──────┘

5. Delete old SSTable files
```

### Compaction Strategies

#### Size-Tiered Compaction (STCS)

Used by: Cassandra (default), HBase, RocksDB (universal compaction)

**How it works:**
- Group SSTables of similar size together
- When enough same-size SSTables accumulate (e.g., 4), merge them into one larger SSTable
- Results in tiers of exponentially larger SSTable sizes

```
Tier 1 (small):   [SST] [SST] [SST] [SST]  → Compact when 4 accumulate
                           ↓
Tier 2 (medium):  [    SST    ] [    SST    ] [    SST    ] [    SST    ]
                                    ↓
Tier 3 (large):   [         SST         ] [         SST         ]
```

**Pros:**
- Simple to implement
- Good write amplification
- Better for write-heavy workloads

**Cons:**
- Higher space amplification (2x in worst case)
- Less predictable read performance
- Temporary space needed during compaction

#### Leveled Compaction (LCS)

Used by: LevelDB, RocksDB (default), Cassandra (optional)

**How it works:**
- Organize SSTables into levels with size limits
- Each level (except L0) has non-overlapping key ranges
- When a level exceeds its size limit, compact into the next level
- Level N+1 is typically 10x larger than level N

```
L0: [SST] [SST] [SST] [SST]     (overlapping, max 4 files)
         ↓ Compact when full
L1: [  SST  |  SST  |  SST  ]   (10 MB total, non-overlapping)
         ↓ Compact when full
L2: [     SST     |     SST     |     SST     ]   (100 MB total)
         ↓ Compact when full
L3: [          SST          |          SST          ]   (1 GB total)
```

**Pros:**
- Better space amplification (typically 10-20%)
- More predictable read performance
- Better for read-heavy or balanced workloads

**Cons:**
- Higher write amplification (10-30x)
- More I/O overhead

#### FIFO Compaction

Used by: RocksDB (for TTL data)

**How it works:**
- Simply delete oldest SSTables when space limit is reached
- No merging, just deletion
- Suitable for time-series data with TTL

**Pros:**
- Minimal write amplification
- Very simple

**Cons:**
- Only works for append-only, TTL-based data
- No deduplication of keys

### Compaction Trade-offs Summary

| Strategy | Write Amp | Space Amp | Read Amp | Best For |
|----------|-----------|-----------|----------|----------|
| Size-Tiered | Low (4-8x) | High (50-100%) | High | Write-heavy |
| Leveled | High (10-30x) | Low (10-20%) | Low | Read-heavy, balanced |
| FIFO | Minimal | Minimal | Medium | TTL time-series |

---

## Bloom Filters in LSM Trees

### What Is a Bloom Filter?

A Bloom filter is a space-efficient probabilistic data structure that answers the question: "Is this element in the set?"

- If it says "No" → The element is **definitely not** in the set (100% accurate)
- If it says "Yes" → The element **might be** in the set (may be a false positive)

This property makes Bloom filters perfect for LSM-trees: we can quickly skip SSTables that definitely don't contain a key.

### How Bloom Filters Work

```
Building a Bloom Filter:

1. Create a bit array of size m (e.g., 1 million bits)
   [0][0][0][0][0][0][0][0][0][0]...[0]

2. Choose k hash functions (e.g., 3)

3. For each key in the SSTable:
   - Compute h1(key), h2(key), h3(key)
   - Set bits at those positions to 1

   Insert "apple":
   h1("apple") = 42, h2("apple") = 789, h3("apple") = 123456
   [0]...[1]...[0]...[0]...[1]...[0]...[1]...[0]
        ^42             ^789           ^123456

   Insert "banana":
   h1("banana") = 100, h2("banana") = 789, h3("banana") = 500
   [0]...[1]...[1]...[1]...[1]...[0]...[1]...[0]
        ^42  ^100     ^500 ^789        ^123456


Querying a Bloom Filter:

Query "apple":
  h1("apple") = 42    → bit[42] = 1 ✓
  h2("apple") = 789   → bit[789] = 1 ✓
  h3("apple") = 123456 → bit[123456] = 1 ✓
  All bits set → "Might exist"

Query "cherry":
  h1("cherry") = 42   → bit[42] = 1 ✓
  h2("cherry") = 999  → bit[999] = 0 ✗
  Not all bits set → "Definitely doesn't exist"
```

### Impact on Read Performance

Without Bloom filters, a read might need to search every SSTable:

```
GET key "xyz":
  Check SSTable 1: Read index, read data block → Not found
  Check SSTable 2: Read index, read data block → Not found
  Check SSTable 3: Read index, read data block → Not found
  ...
  Each check = disk I/O!
```

With Bloom filters:

```
GET key "xyz":
  Check SSTable 1: Bloom filter says definitely no → Skip
  Check SSTable 2: Bloom filter says maybe → Check → Not found  
  Check SSTable 3: Bloom filter says definitely no → Skip
  Check SSTable 4: Bloom filter says definitely no → Skip
  Check SSTable 5: Bloom filter says maybe → Check → Found!
  
  Reduced from 5 disk reads to 2!
```

### Tuning Bloom Filters

The false positive rate depends on:
- **m**: Size of bit array (more bits = fewer false positives)
- **k**: Number of hash functions (optimal is ~0.7 * m/n)
- **n**: Number of elements inserted

Typical configurations:
- 10 bits per element → ~1% false positive rate
- 15 bits per element → ~0.1% false positive rate

Most LSM-tree implementations let you configure bits per key based on your read patterns and memory budget.

---

## Advantages of LSM Trees

### 1. Extremely High Write Throughput

The primary advantage of LSM-trees is write performance. By converting random writes into sequential writes:

- **MemTable writes are in-memory** (microseconds)
- **WAL writes are sequential append** (fast on all storage)
- **SSTable flushes are sequential writes** (optimal for both HDDs and SSDs)

Benchmarks typically show LSM-trees handling 10-100x more writes per second than B-trees for write-heavy workloads.

### 2. Efficient Use of Storage

Sequential writes are gentle on SSDs:
- Fewer write cycles (less wear)
- Better write amplification at the storage level
- No need for expensive random write operations

For HDDs, sequential writes avoid expensive seek times entirely.

### 3. Excellent Compression

Since SSTables are written in sorted order:
- Similar keys are adjacent (great for prefix compression)
- Similar values may be adjacent (better compression ratios)
- Compression is applied at block level

LSM-trees often achieve 3-10x better compression than B-trees storing the same data.

### 4. Simple Crash Recovery

Recovery is straightforward:
1. Load all valid SSTables (they're immutable, so either valid or not)
2. Replay the WAL to reconstruct the MemTable
3. Done

No complex transaction log parsing or page repair needed.

### 5. Efficient Range Scans

Since data is sorted:
- Range queries are efficient (iterate through sorted keys)
- No need to follow pointers like in B-trees
- Good cache locality within and across data blocks

### 6. Predictable Latency (with caveats)

Without compaction running, read and write latencies are predictable. The write path is always the same: WAL + MemTable.

---

## Disadvantages of LSM Trees

### 1. Read Amplification

A single read may need to check:
- Active MemTable
- Immutable MemTables
- Multiple L0 SSTables
- One SSTable per level

Even with Bloom filters and caches, this is more work than B-trees, which can satisfy most reads with 2-4 page reads.

### 2. Write Amplification

Due to compaction, the same data may be written multiple times:
- First to WAL
- Then to L0 SSTable
- Then to L1, L2, L3... as it's compacted

This increases storage I/O and SSD wear, though it's composed of efficient sequential writes.

### 3. Space Amplification

Multiple versions of keys exist temporarily:
- Current values in MemTable/L0
- Old values in lower levels
- Tombstones waiting to be cleaned up

This can be 10-50% overhead depending on update/delete patterns and compaction strategy.

### 4. Unpredictable Latency Spikes

When compaction runs, it competes for I/O bandwidth:
- Read latencies may increase
- Write latencies may spike if MemTable fills during heavy compaction

This can cause p99 latency issues in latency-sensitive applications.

### 5. Complexity

LSM-trees have many tunable parameters:
- MemTable size
- L0 file limit
- Level size ratios
- Compaction strategy
- Bloom filter configuration
- Block size and compression

Getting optimal performance requires understanding these trade-offs.

### 6. Not Ideal for Small Updates

If you're performing many small updates to existing keys, the update pattern creates a lot of tombstones and superseded values that must be compacted away. B-trees handle in-place updates more efficiently for this pattern.

---

## Real-World Use Cases

### Databases Using LSM Trees

| Database | Use Case | Notes |
|----------|----------|-------|
| **LevelDB** | Embedded key-value store | Created by Google, foundational implementation |
| **RocksDB** | Embedded high-performance store | Facebook's fork of LevelDB, heavily optimized |
| **Cassandra** | Distributed wide-column store | LSM for individual nodes, tunable compaction |
| **HBase** | Hadoop-based wide-column store | LSM + HDFS for scalable analytics |
| **ScyllaDB** | Cassandra-compatible, C++ rewrite | Extreme performance optimization |
| **CockroachDB** | Distributed SQL | Uses RocksDB/Pebble for storage layer |
| **TiKV** | Distributed key-value for TiDB | Uses RocksDB |
| **InfluxDB** | Time-series database | Custom LSM implementation |
| **Badger** | Pure Go key-value store | LSM with optimizations for SSDs |

### Ideal Workload Patterns

**Write-Heavy Applications:**
- Logging and event ingestion
- Time-series data collection
- Message queues and streaming
- Sensor data and IoT

**Append-Mostly Patterns:**
- Audit logs
- Transaction history
- Activity feeds
- Blockchain storage

**Large-Scale Key-Value Storage:**
- Session stores
- Cache backends
- Feature stores for ML
- Configuration management

---

## LSM Tree vs B-Tree Comparison

```
                    LSM-Tree                           B-Tree
                    
Write Path:    ┌─────────────────┐             ┌─────────────────┐
               │ Append to WAL   │             │ Find leaf page  │
               │ Insert MemTable │             │ Read from disk  │
               │ (In-memory ops) │             │ Modify in place │
               │                 │             │ Write back      │
               │ Sequential!     │             │ Random I/O      │
               └─────────────────┘             └─────────────────┘

Read Path:     ┌─────────────────┐             ┌─────────────────┐
               │ Check MemTable  │             │ Traverse tree   │
               │ Check L0        │             │ (2-4 page reads)│
               │ Check L1, L2... │             │                 │
               │ (Multiple files)│             │ Direct access   │
               └─────────────────┘             └─────────────────┘

Space:         Multiple versions               Single copy
               exist temporarily               of each key
               
Compaction:    Background merging              None needed
               required                        (in-place updates)
```

### When to Choose LSM-Tree

- Write throughput is the primary concern
- Sequential I/O patterns are preferred (HDDs or optimizing SSD lifespan)
- Data is append-heavy with few updates
- Compression efficiency matters
- Range scans are common

### When to Choose B-Tree

- Read latency is critical
- Workload is read-heavy or balanced
- Many small updates to existing keys
- Predictable latency is essential
- Storage overhead must be minimized

---

## Implementation Tips

### Memory Configuration

```
MemTable Size:
├── Too small (1-4 MB):
│   └── Frequent flushes, many L0 files, high read amplification
│
├── Sweet spot (32-128 MB):
│   └── Balance between write batching and memory usage
│
└── Too large (512 MB+):
    └── Long recovery time (WAL replay), high memory usage
```

### Compaction Tuning

```
Level Size Ratio (e.g., 10x):
├── Higher ratio (20x):
│   └── Fewer levels, less write amplification, more space overhead
│
├── Default (10x):
│   └── Good balance for most workloads
│
└── Lower ratio (4-5x):
    └── More levels, more write amplification, less space overhead
```

### Bloom Filter Sizing

```
Bits per key:
├── 5 bits: ~10% false positive rate (cheap, less effective)
├── 10 bits: ~1% false positive rate (good default)
├── 15 bits: ~0.1% false positive rate (expensive, very effective)
└── 20 bits: ~0.01% false positive rate (overkill for most)

Memory calculation:
  1 billion keys × 10 bits = 1.25 GB for Bloom filters
```

---

## Summary

LSM-trees are a powerful data structure for write-optimized storage engines. By accepting some read amplification and background compaction overhead, they achieve dramatically better write performance than traditional B-trees.

**Key Takeaways:**

1. **Writes are append-only**: WAL + MemTable + SSTable flushes — all sequential
2. **Reads search multiple sources**: MemTable → L0 → L1 → L2 → ..., mitigated by Bloom filters
3. **Updates/Deletes create new entries**: Older versions cleaned up by compaction
4. **Compaction is essential**: Merges files, removes obsolete data, maintains read performance
5. **Trade-offs are tunable**: Compaction strategy, MemTable size, Bloom filter bits all affect the balance

Understanding LSM-trees is essential for anyone working with modern databases like Cassandra, RocksDB, or LevelDB, or building high-throughput data systems.