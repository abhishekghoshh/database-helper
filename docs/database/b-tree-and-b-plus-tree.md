# B-Tree and B+ Tree


## Papers Published

- [The Ubiquitous B-Tree](https://carlosproal.com/ir/papers/p121-comer.pdf)




## Medium

- [B-Trees](https://medium.com/the-developers-diary/b-trees-bfc04edeff72)




## Why B-Trees and B+ Trees?

Database indexes need a data structure that:
- ✅ Supports fast search (O(log n))
- ✅ Supports fast insert/delete
- ✅ Works efficiently with disk I/O (minimizes disk reads)
- ✅ Maintains sorted order
- ✅ Handles large datasets

**B-Trees and B+ Trees** are specifically designed for disk-based storage systems and are the industry standard for database indexing.

## B-Tree Structure

**What is a B-Tree?**

A **B-Tree** (Balanced Tree) is a self-balancing, multi-way tree data structure designed specifically for storage systems that read and write large blocks of data. Invented by Rudolf Bayer and Ed McCreight in 1972 at Boeing Research Labs, B-Trees revolutionized database and file system design.

**Core Concept:**

Unlike binary trees (which have max 2 children), B-Trees can have **many children per node** (hundreds or even thousands). This "bushy" structure reduces tree height dramatically, which is crucial for disk-based systems where each level traversal requires a disk read.

**Why "B" in B-Tree?**

The "B" stands for **"Balanced"**, though some attribute it to "Boeing" (where it was invented) or "Bayer" (one of the inventors). The key insight is keeping the tree balanced at all times.

**Fundamental Characteristics:**

A B-Tree is a self-balancing tree data structure that maintains sorted data and allows searches, insertions, and deletions in O(log n) time. It's optimized for systems that read and write large blocks of data (like databases, file systems).

**What Makes B-Trees Special for Databases:**

1. **Block-Oriented Design**: Each node = one disk page/block (typically 4KB-16KB)
   - Minimizes expensive disk I/O operations
   - One disk read loads an entire node (with many keys)

2. **High Fan-out**: Each node can have dozens to hundreds of children
   - Reduces tree height: log_base_M(N) where M is large
   - Example: 1 million records in a tree of height 3 with fan-out 100

3. **Self-Balancing**: Automatically maintains balance on insert/delete
   - All leaf nodes always at same depth
   - Ensures consistent O(log n) performance

**B-Tree Properties (Formal Definition):**

For a B-Tree of **order m** (maximum number of children):

1. **Node Capacity:**
   - Each node contains at most **m-1 keys**
   - Each node (except root) contains at least **⌈m/2⌉ - 1 keys**
   - Root has at least 1 key (unless tree is empty)

2. **Children:**
   - Each internal node with k keys has **k+1 children**
   - Each node (except root) has at least **⌈m/2⌉ children**
   - All leaves are at the same level

3. **Ordering:**
   - Keys within a node are sorted: K₁ < K₂ < ... < Kₙ
   - All keys in subtree[i] are less than K[i]
   - All keys in subtree[i+1] are greater than K[i]

4. **Data Storage:**
   - **Keys and data stored in ALL nodes** (internal + leaf)
   - Each key has associated data (or pointer to data)

5. **Balance:**
   - All leaf nodes are at the same depth
   - Tree is always perfectly balanced

**B-Tree Order Examples:**

```
Order 3 (minimum degree = 2):
- Max keys per node: 2
- Min keys per node: 1 (except root)
- Max children: 3
- Min children: 2 (except root)

Order 5 (minimum degree = 3):
- Max keys per node: 4
- Min keys per node: 2 (except root)
- Max children: 5
- Min children: 3 (except root)

Order 100 (common in databases):
- Max keys per node: 99
- Min keys per node: 49 (except root)
- Max children: 100
- Min children: 50 (except root)
```

**Why Order Matters:**

Higher order = bushier tree = fewer levels = fewer disk reads!

```
Storing 1 million records:

Order 3 (binary-like):
- Height: ~20 levels
- Disk reads for search: 20

Order 100 (database typical):
- Height: ~3 levels
- Disk reads for search: 3

Result: 6-7x fewer disk reads!
```

**B-Tree Structure Diagram:**

```
B-Tree of order 3 (max 3 children per node):

                        [40, 70]  ← Root: Contains data
                     /      |      \
                    /       |       \
                   /        |        \
          [10, 20, 30]  [50, 60]  [80, 90, 100]
              ↑             ↑            ↑
         Contains data  Contains data  Contains data
         
Keys: 10, 20, 30, 40, 50, 60, 70, 80, 90, 100
All keys stored in tree nodes (internal + leaf)
```

**Detailed B-Tree Node:**

```
┌────────────────────────────────────────────┐
│            B-Tree Node                     │
├────────────────────────────────────────────┤
│ n: 2  (number of keys)                     │
│ keys: [40, 70]                             │
│ data: [ptr_to_row_40, ptr_to_row_70]      │
│ children: [child_0, child_1, child_2]      │
│                                            │
│ child_0: all keys < 40                     │
│ child_1: all keys between 40 and 70       │
│ child_2: all keys > 70                     │
└────────────────────────────────────────────┘
```

**B-Tree Search Process:**

```
Search for key = 60:

Step 1: Start at root [40, 70]
        60 > 40 and 60 < 70
        → Go to middle child
        
Step 2: At node [50, 60]
        Found 60!
        → Return data associated with 60
        
Total disk reads: 2 nodes
```

## B+ Tree Structure

**What is a B+ Tree?**

A **B+ Tree** is an evolution of the B-Tree, specifically optimized for database systems and file systems. It was developed in the late 1970s as an improvement over B-Trees for disk-based indexing. Nearly **all modern databases** (MySQL InnoDB, PostgreSQL, Oracle, SQL Server, MongoDB) use B+ Trees for their indexes.

**The Key Innovation:**

B+ Trees make a **critical architectural change**: they **separate index navigation from data storage**.

- **Internal nodes**: Only store keys (for navigation)
- **Leaf nodes**: Store both keys AND data (or pointers to data)
- **Leaf nodes are linked**: Form a doubly-linked list

This seemingly simple change provides massive benefits for database operations.

**Why B+ Trees Dominate Databases:**

1. **Range Queries are Lightning Fast:**
   ```
   B-Tree: For range query [20, 80], must:
   - Tree traversal for 20
   - Tree traversal for 25
   - Tree traversal for 30
   - ... (separate traversal for EACH value)
   
   B+ Tree: For range query [20, 80], must:
   - Tree traversal to find 20 (once)
   - Linear scan through linked leaf nodes
   - Stop when reaching value > 80
   
   Result: 1 tree traversal + sequential reads vs N tree traversals!
   ```

2. **Sequential Scans are Free:**
   - Linked leaves allow full table scans without tree traversal
   - Perfect for `SELECT *` or `WHERE date BETWEEN '2024-01-01' AND '2024-12-31'`

3. **Internal Nodes are Compact:**
   - No data in internal nodes = more keys fit per node
   - More keys per node = higher fan-out = shorter tree
   - Example: If data is 100 bytes and key is 8 bytes:
     - B-Tree node (4KB): ~37 entries
     - B+ Tree internal node (4KB): ~500 entries
   - Result: **B+ Tree can be significantly shorter!**

4. **Better Caching:**
   - Internal nodes (frequently accessed) are smaller → fit better in memory cache
   - Leaf nodes (less frequently accessed) stay on disk

**B+ Tree Properties (Formal Definition):**

For a B+ Tree of **order m**:

1. **Internal Nodes:**
   - Contain **only keys** (no data/values)
   - Each internal node has at most **m children**
   - Each internal node (except root) has at least **⌈m/2⌉ children**
   - Internal node with k keys has **k children** (different from B-Tree!)
   - Keys act as "signposts" to navigate to correct child

2. **Leaf Nodes:**
   - Contain **both keys and data** (or pointers to data records)
   - Each leaf node contains at most **m-1 key-value pairs**
   - Each leaf node (except root) contains at least **⌈(m-1)/2⌉ key-value pairs**
   - All leaf nodes are at the **same level** (balanced)
   - Leaf nodes form a **doubly-linked list** (crucial for range queries!)

3. **Key Distribution:**
   - A key in internal node represents the **minimum key in its right subtree**
   - Keys in leaf nodes are the actual searchable keys
   - **Keys may be duplicated** (appear in both internal and leaf nodes)

4. **Data Storage:**
   - **ALL data is in leaf nodes**
   - Internal nodes are purely for navigation
   - This is the fundamental difference from B-Tree

5. **Ordering:**
   - Keys within each node are sorted
   - Leaf nodes maintain sorted order left-to-right
   - Linked list of leaves can be traversed in sorted order

**Structural Comparison - Same Data:**

```
B-Tree (Order 3):
                [50]
              /      \
         [30,40]    [60,70]
        /  |  \     /  |  \
     data data data ...

All nodes contain data!


B+ Tree (Order 3):
                [30, 50]              ← Internal: only keys
              /    |     \
            /      |      \
      [10,20] → [30,40] → [50,60,70] ← Leaves: keys + data, linked!
       data      data       data

Only leaves contain data!
Leaves are linked (→) for range scans!
```

**Why Databases Choose B+ Trees:**

| Operation | B-Tree | B+ Tree |
|-----------|---------|----------|
| **Point Search** | O(log n) - Same | O(log n) - Same |
| **Range Query** | O(k × log n) - Multiple traversals | O(log n + k) - One traversal + linear scan ✅ |
| **Full Scan** | O(n × log n) - Must visit all nodes | O(n) - Just traverse leaves ✅ |
| **Cache Efficiency** | Lower - Data in all nodes | Higher - Compact internal nodes ✅ |
| **Fan-out** | Lower - Data takes space | Higher - Only keys in internal nodes ✅ |
| **Concurrency** | Lower - Data scattered | Higher - Leaf-level locking ✅ |

**Real-World Database Example:**

**MySQL InnoDB (B+ Tree Order ~1200):**

```
Assumptions:
- Page size: 16KB (InnoDB default)
- Key size: 8 bytes (BIGINT)
- Pointer size: 6 bytes
- Data row: ~100 bytes

Internal Node:
- ~1200 keys fit per page
- Fan-out: 1200

Leaf Node:
- ~100 rows fit per page
- Contains actual table data

Tree Height for 1 Billion Rows:
- Level 1 (root): 1 node = 1200 pointers
- Level 2: 1200 nodes = 1.44M pointers
- Level 3 (leaves): 1.44M nodes = 1B+ rows

Result: 3 disk reads to find ANY row in 1 billion records!
```

**B+ Tree Order Configuration:**

```
Order 4 (minimum practical):
- Internal: Max 4 children, 3 keys
- Leaf: Max 3 key-value pairs
- Good for: Teaching, small datasets

Order 100 (typical database):
- Internal: Max 100 children, 99 keys
- Leaf: Max 99 key-value pairs
- Good for: Production databases, 4KB pages

Order 1200 (InnoDB on 16KB pages):
- Internal: Max 1200 children, 1199 keys
- Leaf: Max ~100 rows (depends on row size)
- Good for: Large-scale databases, optimal I/O
```

**When Leaf Nodes Fill Up - The Linked List Saves The Day:**

```
Original:
[10,20] → [30,40] → [50,60]

After inserting 35:
[10,20] → [30] → [35,40] → [50,60]
           ↑  split!  ↑
           
Parent gets updated with new separator key,
but linked list maintains sequential access!
Range query [25, 45] still works perfectly!
```

**B+ Tree Structure Diagram:**

```
B+ Tree of order 3:

                        [40, 70]  ← Root: Keys only (no data)
                     /      |      \
                    /       |       \
                   /        |        \
              [10, 20, 30] [50, 60] [80, 90, 100]  ← Internal: Keys only
              /  |  |  \    /   \     /   |   |  \
             /   |  |   \  /     \   /    |   |   \
    [10,d] [20,d] [30,d] [40,d] [50,d] [60,d] [70,d] [80,d] [90,d] [100,d]
    ↑                     ↑                          ↑
    Leaf nodes with data, linked together →  →  →  →  →  →
```

**Detailed B+ Tree Node:**

**Internal Node:**
```
┌────────────────────────────────────────────┐
│        B+ Tree Internal Node               │
├────────────────────────────────────────────┤
│ n: 2  (number of keys)                     │
│ keys: [40, 70]                             │
│ children: [child_0, child_1, child_2]      │
│                                            │
│ NO DATA - keys used for navigation only    │
│                                            │
│ child_0: all keys < 40                     │
│ child_1: all keys between 40 and 70       │
│ child_2: all keys >= 70                    │
└────────────────────────────────────────────┘
```

**Leaf Node:**
```
┌────────────────────────────────────────────┐
│        B+ Tree Leaf Node                   │
├────────────────────────────────────────────┤
│ n: 3  (number of keys)                     │
│ keys: [50, 60, 70]                         │
│ data: [ptr_row_50, ptr_row_60, ptr_row_70] │
│ next: pointer to next leaf node →         │
│ prev: pointer to prev leaf node ←         │
│                                            │
│ ALL DATA stored here!                      │
└────────────────────────────────────────────┘
```

**B+ Tree Search Process:**

```
Search for key = 60:

Step 1: Start at root [40, 70]
        60 > 40 and 60 < 70
        → Go to middle child
        
Step 2: At internal node [50, 60]
        60 >= 60
        → Go to right child
        
Step 3: At leaf node [60, 70, 80]
        Found 60!
        → Return data associated with 60
        
Total disk reads: 3 nodes (but leaf has all data)
```

## B-Tree vs B+ Tree Comparison

| Feature | B-Tree | B+ Tree |
|---------|--------|---------|
| **Data location** | All nodes (internal + leaf) | Leaf nodes only |
| **Internal nodes** | Store keys + data | Store keys only (no data) |
| **Leaf nodes** | Not linked | Linked (doubly-linked list) |
| **Keys per node** | Fewer (data takes space) | More (only keys in internal) |
| **Tree height** | Slightly shorter | Slightly taller |
| **Range queries** | Requires tree traversal | Fast (follow leaf links) |
| **Search time** | O(log n) | O(log n) |
| **Use case** | General purpose | Databases, filesystems |

## Why Databases Prefer B+ Trees

1. **✅ Better for Range Queries**
   - Leaf nodes are linked → Sequential scan without tree traversal
   - Example: `WHERE age BETWEEN 20 AND 30` → Find 20, then follow links

2. **✅ More Keys in Internal Nodes**
   - No data in internal nodes → More keys fit per node
   - Shorter tree → Fewer disk reads

3. **✅ Better for Full Scan**
   - Scan all data: Just traverse leaf level
   - B-Tree: Must traverse entire tree

4. **✅ Consistent Search Time**
   - Always go to leaf level → Predictable performance
   - B-Tree: May find data at any level → Unpredictable

## C Implementation (Complete Production-Ready Code)

### Complete B-Tree Implementation

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ORDER 5  // Maximum children per node (minimum degree t = 3)
#define MAX_KEYS (ORDER - 1)
#define MIN_KEYS ((ORDER / 2) - 1)

// B-Tree node structure
typedef struct BTreeNode {
    int isLeaf;                          // 1 if leaf, 0 if internal
    int numKeys;                         // Current number of keys
    int keys[MAX_KEYS];                  // Keys array
    void *data[MAX_KEYS];                // Data pointers (in all nodes)
    struct BTreeNode *children[ORDER];   // Child pointers
} BTreeNode;

// Create a new B-Tree node
BTreeNode* createBTreeNode(int isLeaf) {
    BTreeNode *node = (BTreeNode*)malloc(sizeof(BTreeNode));
    node->isLeaf = isLeaf;
    node->numKeys = 0;
    for (int i = 0; i < ORDER; i++) {
        node->children[i] = NULL;
    }
    for (int i = 0; i < MAX_KEYS; i++) {
        node->data[i] = NULL;
    }
    return node;
}

// Search for a key in B-Tree
void* bTreeSearch(BTreeNode *node, int key) {
    if (node == NULL) return NULL;
    
    int i = 0;
    // Find first key >= search key
    while (i < node->numKeys && key > node->keys[i]) {
        i++;
    }
    
    // Key found in this node (data can be at ANY level)
    if (i < node->numKeys && key == node->keys[i]) {
        return node->data[i];
    }
    
    // If leaf, key not found
    if (node->isLeaf) {
        return NULL;
    }
    
    // Recurse to appropriate child
    return bTreeSearch(node->children[i], key);
}

// Split a full child of node at index i
void bTreeSplitChild(BTreeNode *parent, int i) {
    BTreeNode *fullChild = parent->children[i];
    BTreeNode *newChild = createBTreeNode(fullChild->isLeaf);
    
    int midIndex = MIN_KEYS;
    newChild->numKeys = MIN_KEYS;
    
    // Copy upper half keys and data to new node
    for (int j = 0; j < MIN_KEYS; j++) {
        newChild->keys[j] = fullChild->keys[j + midIndex + 1];
        newChild->data[j] = fullChild->data[j + midIndex + 1];
    }
    
    // If not leaf, copy children pointers
    if (!fullChild->isLeaf) {
        for (int j = 0; j <= MIN_KEYS; j++) {
            newChild->children[j] = fullChild->children[j + midIndex + 1];
        }
    }
    
    fullChild->numKeys = MIN_KEYS;
    
    // Shift parent's children to make space
    for (int j = parent->numKeys; j > i; j--) {
        parent->children[j + 1] = parent->children[j];
    }
    parent->children[i + 1] = newChild;
    
    // Move middle key up to parent
    for (int j = parent->numKeys - 1; j >= i; j--) {
        parent->keys[j + 1] = parent->keys[j];
        parent->data[j + 1] = parent->data[j];
    }
    parent->keys[i] = fullChild->keys[midIndex];
    parent->data[i] = fullChild->data[midIndex];
    parent->numKeys++;
}

// Insert into a non-full node
void bTreeInsertNonFull(BTreeNode *node, int key, void *data) {
    int i = node->numKeys - 1;
    
    if (node->isLeaf) {
        // Shift keys to make space
        while (i >= 0 && key < node->keys[i]) {
            node->keys[i + 1] = node->keys[i];
            node->data[i + 1] = node->data[i];
            i--;
        }
        node->keys[i + 1] = key;
        node->data[i + 1] = data;
        node->numKeys++;
    } else {
        // Find child to insert into
        while (i >= 0 && key < node->keys[i]) {
            i--;
        }
        i++;
        
        // If child is full, split it
        if (node->children[i]->numKeys == MAX_KEYS) {
            bTreeSplitChild(node, i);
            if (key > node->keys[i]) {
                i++;
            }
        }
        bTreeInsertNonFull(node->children[i], key, data);
    }
}

// Insert a key into B-Tree
void bTreeInsert(BTreeNode **root, int key, void *data) {
    if (*root == NULL) {
        *root = createBTreeNode(1);
        (*root)->keys[0] = key;
        (*root)->data[0] = data;
        (*root)->numKeys = 1;
        return;
    }
    
    // If root is full, split it
    if ((*root)->numKeys == MAX_KEYS) {
        BTreeNode *newRoot = createBTreeNode(0);
        newRoot->children[0] = *root;
        bTreeSplitChild(newRoot, 0);
        *root = newRoot;
    }
    
    bTreeInsertNonFull(*root, key, data);
}

// Find predecessor key (largest key in left subtree)
int bTreeGetPredecessor(BTreeNode *node) {
    while (!node->isLeaf) {
        node = node->children[node->numKeys];
    }
    return node->keys[node->numKeys - 1];
}

// Find successor key (smallest key in right subtree)
int bTreeGetSuccessor(BTreeNode *node) {
    while (!node->isLeaf) {
        node = node->children[0];
    }
    return node->keys[0];
}

// Merge a child with its sibling
void bTreeMerge(BTreeNode *node, int idx) {
    BTreeNode *child = node->children[idx];
    BTreeNode *sibling = node->children[idx + 1];
    
    // Pull key from current node and merge with right sibling
    child->keys[MIN_KEYS] = node->keys[idx];
    child->data[MIN_KEYS] = node->data[idx];
    
    // Copy keys from sibling
    for (int i = 0; i < sibling->numKeys; i++) {
        child->keys[i + MIN_KEYS + 1] = sibling->keys[i];
        child->data[i + MIN_KEYS + 1] = sibling->data[i];
    }
    
    // Copy child pointers if not leaf
    if (!child->isLeaf) {
        for (int i = 0; i <= sibling->numKeys; i++) {
            child->children[i + MIN_KEYS + 1] = sibling->children[i];
        }
    }
    
    child->numKeys += sibling->numKeys + 1;
    
    // Move keys in parent
    for (int i = idx + 1; i < node->numKeys; i++) {
        node->keys[i - 1] = node->keys[i];
        node->data[i - 1] = node->data[i];
    }
    
    // Move child pointers in parent
    for (int i = idx + 2; i <= node->numKeys; i++) {
        node->children[i - 1] = node->children[i];
    }
    
    node->numKeys--;
    free(sibling);
}

// Borrow from previous sibling
void bTreeBorrowFromPrev(BTreeNode *node, int idx) {
    BTreeNode *child = node->children[idx];
    BTreeNode *sibling = node->children[idx - 1];
    
    // Move all keys in child forward
    for (int i = child->numKeys - 1; i >= 0; i--) {
        child->keys[i + 1] = child->keys[i];
        child->data[i + 1] = child->data[i];
    }
    
    // Move child pointers
    if (!child->isLeaf) {
        for (int i = child->numKeys; i >= 0; i--) {
            child->children[i + 1] = child->children[i];
        }
    }
    
    // Move key from parent to child
    child->keys[0] = node->keys[idx - 1];
    child->data[0] = node->data[idx - 1];
    
    // Move key from sibling to parent
    node->keys[idx - 1] = sibling->keys[sibling->numKeys - 1];
    node->data[idx - 1] = sibling->data[sibling->numKeys - 1];
    
    // Move child pointer
    if (!child->isLeaf) {
        child->children[0] = sibling->children[sibling->numKeys];
    }
    
    child->numKeys++;
    sibling->numKeys--;
}

// Borrow from next sibling
void bTreeBorrowFromNext(BTreeNode *node, int idx) {
    BTreeNode *child = node->children[idx];
    BTreeNode *sibling = node->children[idx + 1];
    
    // Move key from parent to child
    child->keys[child->numKeys] = node->keys[idx];
    child->data[child->numKeys] = node->data[idx];
    
    // Move child pointer
    if (!child->isLeaf) {
        child->children[child->numKeys + 1] = sibling->children[0];
    }
    
    // Move key from sibling to parent
    node->keys[idx] = sibling->keys[0];
    node->data[idx] = sibling->data[0];
    
    // Shift keys in sibling
    for (int i = 1; i < sibling->numKeys; i++) {
        sibling->keys[i - 1] = sibling->keys[i];
        sibling->data[i - 1] = sibling->data[i];
    }
    
    // Shift child pointers in sibling
    if (!sibling->isLeaf) {
        for (int i = 1; i <= sibling->numKeys; i++) {
            sibling->children[i - 1] = sibling->children[i];
        }
    }
    
    child->numKeys++;
    sibling->numKeys--;
}

// Fill child at idx if it has fewer than MIN_KEYS
void bTreeFill(BTreeNode *node, int idx) {
    // If previous sibling has more than MIN_KEYS, borrow from it
    if (idx != 0 && node->children[idx - 1]->numKeys > MIN_KEYS) {
        bTreeBorrowFromPrev(node, idx);
    }
    // If next sibling has more than MIN_KEYS, borrow from it
    else if (idx != node->numKeys && node->children[idx + 1]->numKeys > MIN_KEYS) {
        bTreeBorrowFromNext(node, idx);
    }
    // Merge with sibling
    else {
        if (idx != node->numKeys) {
            bTreeMerge(node, idx);
        } else {
            bTreeMerge(node, idx - 1);
        }
    }
}

// Delete key from leaf node
void bTreeRemoveFromLeaf(BTreeNode *node, int idx) {
    for (int i = idx + 1; i < node->numKeys; i++) {
        node->keys[i - 1] = node->keys[i];
        node->data[i - 1] = node->data[i];
    }
    node->numKeys--;
}

// Delete key from internal node
void bTreeRemoveFromNonLeaf(BTreeNode *node, int idx) {
    int key = node->keys[idx];
    
    if (node->children[idx]->numKeys > MIN_KEYS) {
        int pred = bTreeGetPredecessor(node->children[idx]);
        node->keys[idx] = pred;
        bTreeDeleteInternal(node->children[idx], pred);
    }
    else if (node->children[idx + 1]->numKeys > MIN_KEYS) {
        int succ = bTreeGetSuccessor(node->children[idx + 1]);
        node->keys[idx] = succ;
        bTreeDeleteInternal(node->children[idx + 1], succ);
    }
    else {
        bTreeMerge(node, idx);
        bTreeDeleteInternal(node->children[idx], key);
    }
}

// Internal delete helper
void bTreeDeleteInternal(BTreeNode *node, int key) {
    int idx = 0;
    while (idx < node->numKeys && node->keys[idx] < key) {
        idx++;
    }
    
    if (idx < node->numKeys && node->keys[idx] == key) {
        if (node->isLeaf) {
            bTreeRemoveFromLeaf(node, idx);
        } else {
            bTreeRemoveFromNonLeaf(node, idx);
        }
    } else if (!node->isLeaf) {
        int isInSubtree = (idx == node->numKeys);
        
        if (node->children[idx]->numKeys <= MIN_KEYS) {
            bTreeFill(node, idx);
        }
        
        if (isInSubtree && idx > node->numKeys) {
            bTreeDeleteInternal(node->children[idx - 1], key);
        } else {
            bTreeDeleteInternal(node->children[idx], key);
        }
    }
}

// Delete a key from B-Tree
void bTreeDelete(BTreeNode **root, int key) {
    if (*root == NULL) return;
    
    bTreeDeleteInternal(*root, key);
    
    // If root is empty after deletion, make its only child the new root
    if ((*root)->numKeys == 0) {
        BTreeNode *tmp = *root;
        if ((*root)->isLeaf) {
            *root = NULL;
        } else {
            *root = (*root)->children[0];
        }
        free(tmp);
    }
}

// Print B-Tree (in-order traversal)
void bTreePrint(BTreeNode *node, int level) {
    if (node == NULL) return;
    
    int i;
    for (i = 0; i < node->numKeys; i++) {
        if (!node->isLeaf) {
            bTreePrint(node->children[i], level + 1);
        }
        for (int j = 0; j < level; j++) printf("  ");
        printf("%d\n", node->keys[i]);
    }
    if (!node->isLeaf) {
        bTreePrint(node->children[i], level + 1);
    }
}
```

### Complete B+ Tree Implementation

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ORDER 4  // Maximum children per node
#define MAX_KEYS (ORDER - 1)
#define MIN_KEYS (ORDER / 2)

// B+ Tree node structure
typedef struct BPlusNode {
    int isLeaf;                          // 1 if leaf, 0 if internal
    int numKeys;                         // Current number of keys
    int keys[MAX_KEYS];                  // Keys array
    void *data[MAX_KEYS];                // Data (only in leaf nodes)
    struct BPlusNode *children[ORDER];   // Children (only in internal nodes)
    struct BPlusNode *next;              // Next leaf (linked list)
    struct BPlusNode *prev;              // Previous leaf (doubly-linked)
    struct BPlusNode *parent;            // Parent pointer (for splits)
} BPlusNode;

// B+ Tree structure
typedef struct BPlusTree {
    BPlusNode *root;
    BPlusNode *firstLeaf;  // Pointer to leftmost leaf for sequential scan
} BPlusTree;

// Create a new B+ Tree node
BPlusNode* createBPlusNode(int isLeaf) {
    BPlusNode *node = (BPlusNode*)malloc(sizeof(BPlusNode));
    node->isLeaf = isLeaf;
    node->numKeys = 0;
    node->next = NULL;
    node->prev = NULL;
    node->parent = NULL;
    
    for (int i = 0; i < ORDER; i++) {
        node->children[i] = NULL;
    }
    for (int i = 0; i < MAX_KEYS; i++) {
        node->data[i] = NULL;
    }
    
    return node;
}

// Create a new B+ Tree
BPlusTree* createBPlusTree() {
    BPlusTree *tree = (BPlusTree*)malloc(sizeof(BPlusTree));
    tree->root = NULL;
    tree->firstLeaf = NULL;
    return tree;
}

// Search for a key in B+ Tree (always goes to leaf)
void* bPlusSearch(BPlusTree *tree, int key) {
    if (tree->root == NULL) return NULL;
    
    BPlusNode *current = tree->root;
    
    // Traverse down to leaf level
    while (!current->isLeaf) {
        int i = 0;
        while (i < current->numKeys && key >= current->keys[i]) {
            i++;
        }
        current = current->children[i];
    }
    
    // Search in leaf node
    for (int i = 0; i < current->numKeys; i++) {
        if (current->keys[i] == key) {
            return current->data[i];
        }
    }
    
    return NULL;  // Not found
}

// Range query: Returns all keys between keyStart and keyEnd
void bPlusRangeQuery(BPlusTree *tree, int keyStart, int keyEnd, 
                     void (*callback)(int key, void *data)) {
    if (tree->root == NULL) return;
    
    BPlusNode *current = tree->root;
    
    // Find starting leaf
    while (!current->isLeaf) {
        int i = 0;
        while (i < current->numKeys && keyStart >= current->keys[i]) {
            i++;
        }
        current = current->children[i];
    }
    
    // Scan leaf nodes using linked list
    while (current != NULL) {
        for (int i = 0; i < current->numKeys; i++) {
            if (current->keys[i] >= keyStart && current->keys[i] <= keyEnd) {
                callback(current->keys[i], current->data[i]);
            }
            if (current->keys[i] > keyEnd) {
                return;
            }
        }
        current = current->next;  // Follow leaf link
    }
}

// Find leaf node where key should be inserted
BPlusNode* bPlusFindLeaf(BPlusNode *node, int key) {
    if (node->isLeaf) {
        return node;
    }
    
    int i = 0;
    while (i < node->numKeys && key >= node->keys[i]) {
        i++;
    }
    
    return bPlusFindLeaf(node->children[i], key);
}

// Insert into a leaf node
void bPlusInsertIntoLeaf(BPlusNode *leaf, int key, void *data) {
    int i = leaf->numKeys - 1;
    
    // Shift keys and data to make space
    while (i >= 0 && key < leaf->keys[i]) {
        leaf->keys[i + 1] = leaf->keys[i];
        leaf->data[i + 1] = leaf->data[i];
        i--;
    }
    
    leaf->keys[i + 1] = key;
    leaf->data[i + 1] = data;
    leaf->numKeys++;
}

// Split a leaf node
void bPlusSplitLeaf(BPlusTree *tree, BPlusNode *leaf, int key, void *data) {
    // Create new leaf
    BPlusNode *newLeaf = createBPlusNode(1);
    
    // Temporary arrays for sorting
    int tempKeys[ORDER];
    void *tempData[ORDER];
    
    // Copy existing keys and insert new key in sorted order
    int i = 0, j = 0;
    while (j < leaf->numKeys) {
        if (i == j && key < leaf->keys[j]) {
            tempKeys[i] = key;
            tempData[i] = data;
            i++;
        }
        tempKeys[i] = leaf->keys[j];
        tempData[i] = leaf->data[j];
        i++;
        j++;
    }
    if (i == j) {
        tempKeys[i] = key;
        tempData[i] = data;
        i++;
    }
    
    // Split point
    int split = (ORDER) / 2;
    
    // First half stays in original leaf
    leaf->numKeys = split;
    for (i = 0; i < split; i++) {
        leaf->keys[i] = tempKeys[i];
        leaf->data[i] = tempData[i];
    }
    
    // Second half goes to new leaf
    newLeaf->numKeys = ORDER - split;
    for (i = split, j = 0; i < ORDER; i++, j++) {
        newLeaf->keys[j] = tempKeys[i];
        newLeaf->data[j] = tempData[i];
    }
    
    // Update leaf links
    newLeaf->next = leaf->next;
    if (leaf->next != NULL) {
        leaf->next->prev = newLeaf;
    }
    leaf->next = newLeaf;
    newLeaf->prev = leaf;
    
    // Insert into parent
    int newKey = newLeaf->keys[0];
    
    if (leaf->parent == NULL) {
        // Create new root
        BPlusNode *newRoot = createBPlusNode(0);
        newRoot->keys[0] = newKey;
        newRoot->children[0] = leaf;
        newRoot->children[1] = newLeaf;
        newRoot->numKeys = 1;
        
        leaf->parent = newRoot;
        newLeaf->parent = newRoot;
        tree->root = newRoot;
    } else {
        bPlusInsertIntoParent(tree, leaf->parent, newKey, newLeaf);
    }
}

// Insert into internal node
void bPlusInsertIntoNode(BPlusNode *node, int key, BPlusNode *rightChild) {
    int i = node->numKeys - 1;
    
    // Shift keys and children to make space
    while (i >= 0 && key < node->keys[i]) {
        node->keys[i + 1] = node->keys[i];
        node->children[i + 2] = node->children[i + 1];
        i--;
    }
    
    node->keys[i + 1] = key;
    node->children[i + 2] = rightChild;
    rightChild->parent = node;
    node->numKeys++;
}

// Split internal node
void bPlusSplitInternal(BPlusTree *tree, BPlusNode *node, int key, BPlusNode *rightChild) {
    BPlusNode *newNode = createBPlusNode(0);
    
    // Temporary arrays
    int tempKeys[ORDER];
    BPlusNode *tempChildren[ORDER + 1];
    
    // Copy existing and insert new in sorted order
    int i = 0, j = 0;
    for (i = 0; i < node->numKeys; i++) {
        if (j == i && key < node->keys[i]) {
            tempKeys[j] = key;
            tempChildren[j + 1] = rightChild;
            j++;
        }
        tempKeys[j] = node->keys[i];
        tempChildren[j] = node->children[i];
        j++;
    }
    tempChildren[j] = node->children[i];
    
    if (j == i) {
        tempKeys[j] = key;
        tempChildren[j + 1] = rightChild;
        j++;
    }
    
    // Split point
    int split = ORDER / 2;
    
    // First half
    node->numKeys = split;
    for (i = 0; i < split; i++) {
        node->keys[i] = tempKeys[i];
        node->children[i] = tempChildren[i];
        tempChildren[i]->parent = node;
    }
    node->children[i] = tempChildren[i];
    tempChildren[i]->parent = node;
    
    // Second half
    newNode->numKeys = ORDER - split - 1;
    for (i = split + 1, j = 0; i < ORDER; i++, j++) {
        newNode->keys[j] = tempKeys[i];
        newNode->children[j] = tempChildren[i];
        tempChildren[i]->parent = newNode;
    }
    newNode->children[j] = tempChildren[i];
    tempChildren[i]->parent = newNode;
    
    // Key to move up
    int upKey = tempKeys[split];
    
    if (node->parent == NULL) {
        // Create new root
        BPlusNode *newRoot = createBPlusNode(0);
        newRoot->keys[0] = upKey;
        newRoot->children[0] = node;
        newRoot->children[1] = newNode;
        newRoot->numKeys = 1;
        
        node->parent = newRoot;
        newNode->parent = newRoot;
        tree->root = newRoot;
    } else {
        bPlusInsertIntoParent(tree, node->parent, upKey, newNode);
    }
}

// Insert into parent (handles splits)
void bPlusInsertIntoParent(BPlusTree *tree, BPlusNode *parent, int key, BPlusNode *rightChild) {
    if (parent->numKeys < MAX_KEYS) {
        bPlusInsertIntoNode(parent, key, rightChild);
    } else {
        bPlusSplitInternal(tree, parent, key, rightChild);
    }
}

// Main insert function
void bPlusInsert(BPlusTree *tree, int key, void *data) {
    // Empty tree
    if (tree->root == NULL) {
        BPlusNode *leaf = createBPlusNode(1);
        leaf->keys[0] = key;
        leaf->data[0] = data;
        leaf->numKeys = 1;
        tree->root = leaf;
        tree->firstLeaf = leaf;
        return;
    }
    
    // Find leaf to insert
    BPlusNode *leaf = bPlusFindLeaf(tree->root, key);
    
    // If leaf has space
    if (leaf->numKeys < MAX_KEYS) {
        bPlusInsertIntoLeaf(leaf, key, data);
    } else {
        // Split leaf
        bPlusSplitLeaf(tree, leaf, key, data);
    }
}

// Delete from leaf
void bPlusDeleteFromLeaf(BPlusNode *leaf, int key) {
    int i = 0;
    while (i < leaf->numKeys && leaf->keys[i] != key) {
        i++;
    }
    
    if (i == leaf->numKeys) return;  // Key not found
    
    // Shift keys and data
    for (int j = i; j < leaf->numKeys - 1; j++) {
        leaf->keys[j] = leaf->keys[j + 1];
        leaf->data[j] = leaf->data[j + 1];
    }
    leaf->numKeys--;
}

// Borrow from left sibling (leaf)
void bPlusBorrowFromLeftLeaf(BPlusNode *leaf, BPlusNode *leftSibling, int parentIdx) {
    BPlusNode *parent = leaf->parent;
    
    // Shift all keys in leaf to the right
    for (int i = leaf->numKeys; i > 0; i--) {
        leaf->keys[i] = leaf->keys[i - 1];
        leaf->data[i] = leaf->data[i - 1];
    }
    
    // Move last key from left sibling to first position of leaf
    leaf->keys[0] = leftSibling->keys[leftSibling->numKeys - 1];
    leaf->data[0] = leftSibling->data[leftSibling->numKeys - 1];
    leaf->numKeys++;
    leftSibling->numKeys--;
    
    // Update parent key
    parent->keys[parentIdx] = leaf->keys[0];
}

// Borrow from right sibling (leaf)
void bPlusBorrowFromRightLeaf(BPlusNode *leaf, BPlusNode *rightSibling, int parentIdx) {
    BPlusNode *parent = leaf->parent;
    
    // Move first key from right sibling to last position of leaf
    leaf->keys[leaf->numKeys] = rightSibling->keys[0];
    leaf->data[leaf->numKeys] = rightSibling->data[0];
    leaf->numKeys++;
    
    // Shift all keys in right sibling to the left
    for (int i = 0; i < rightSibling->numKeys - 1; i++) {
        rightSibling->keys[i] = rightSibling->keys[i + 1];
        rightSibling->data[i] = rightSibling->data[i + 1];
    }
    rightSibling->numKeys--;
    
    // Update parent key
    parent->keys[parentIdx + 1] = rightSibling->keys[0];
}

// Merge with left sibling (leaf)
void bPlusMergeWithLeftLeaf(BPlusTree *tree, BPlusNode *leaf, BPlusNode *leftSibling, int parentIdx) {
    BPlusNode *parent = leaf->parent;
    
    // Copy all keys from leaf to left sibling
    for (int i = 0; i < leaf->numKeys; i++) {
        leftSibling->keys[leftSibling->numKeys + i] = leaf->keys[i];
        leftSibling->data[leftSibling->numKeys + i] = leaf->data[i];
    }
    leftSibling->numKeys += leaf->numKeys;
    
    // Update leaf links
    leftSibling->next = leaf->next;
    if (leaf->next != NULL) {
        leaf->next->prev = leftSibling;
    }
    
    // Remove key from parent
    for (int i = parentIdx; i < parent->numKeys - 1; i++) {
        parent->keys[i] = parent->keys[i + 1];
        parent->children[i + 1] = parent->children[i + 2];
    }
    parent->numKeys--;
    
    free(leaf);
    
    // Handle parent underflow
    if (parent->numKeys < MIN_KEYS && parent != tree->root) {
        bPlusHandleUnderflow(tree, parent);
    } else if (parent->numKeys == 0) {
        tree->root = leftSibling;
        leftSibling->parent = NULL;
        free(parent);
    }
}

// Handle underflow in internal nodes
void bPlusHandleUnderflow(BPlusTree *tree, BPlusNode *node) {
    // Implementation for internal node underflow handling
    // Similar to leaf underflow but for internal nodes
    // This would involve borrowing or merging with siblings
}

// Delete a key from B+ Tree
void bPlusDelete(BPlusTree *tree, int key) {
    if (tree->root == NULL) return;
    
    BPlusNode *leaf = bPlusFindLeaf(tree->root, key);
    bPlusDeleteFromLeaf(leaf, key);
    
    // Handle underflow if necessary
    if (leaf->numKeys < MIN_KEYS && leaf != tree->root) {
        BPlusNode *parent = leaf->parent;
        
        // Find position in parent
        int idx = 0;
        while (idx <= parent->numKeys && parent->children[idx] != leaf) {
            idx++;
        }
        
        // Try to borrow from left sibling
        if (idx > 0 && parent->children[idx - 1]->numKeys > MIN_KEYS) {
            bPlusBorrowFromLeftLeaf(leaf, parent->children[idx - 1], idx - 1);
        }
        // Try to borrow from right sibling
        else if (idx < parent->numKeys && parent->children[idx + 1]->numKeys > MIN_KEYS) {
            bPlusBorrowFromRightLeaf(leaf, parent->children[idx + 1], idx);
        }
        // Merge with left sibling
        else if (idx > 0) {
            bPlusMergeWithLeftLeaf(tree, leaf, parent->children[idx - 1], idx - 1);
        }
        // Merge with right sibling
        else {
            bPlusMergeWithLeftLeaf(tree, parent->children[idx + 1], leaf, idx);
        }
    }
    
    // If root is empty, update tree
    if (tree->root->numKeys == 0 && !tree->root->isLeaf) {
        BPlusNode *oldRoot = tree->root;
        tree->root = tree->root->children[0];
        tree->root->parent = NULL;
        free(oldRoot);
    }
}

// Print B+ Tree level by level
void bPlusPrint(BPlusNode *node, int level) {
    if (node == NULL) return;
    
    for (int j = 0; j < level; j++) printf("  ");
    printf("Level %d [%s]: ", level, node->isLeaf ? "LEAF" : "INTERNAL");
    
    for (int i = 0; i < node->numKeys; i++) {
        printf("%d ", node->keys[i]);
    }
    printf("\n");
    
    if (!node->isLeaf) {
        for (int i = 0; i <= node->numKeys; i++) {
            bPlusPrint(node->children[i], level + 1);
        }
    }
}

// Full sequential scan (uses linked leaves)
void bPlusFullScan(BPlusTree *tree, void (*callback)(int key, void *data)) {
    BPlusNode *leaf = tree->firstLeaf;
    
    while (leaf != NULL) {
        for (int i = 0; i < leaf->numKeys; i++) {
            callback(leaf->keys[i], leaf->data[i]);
        }
        leaf = leaf->next;
    }
}
```

## Advantages and Disadvantages

**B-Tree Advantages:**
- ✅ Data can be found at any level (potentially faster for some searches)
- ✅ Slightly shorter tree height
- ✅ Good for random access patterns

**B-Tree Disadvantages:**
- ❌ Poor for range queries (no leaf links)
- ❌ Fewer keys per internal node (data uses space)
- ❌ Inconsistent search time (data at different levels)

**B+ Tree Advantages:**
- ✅ Excellent for range queries (linked leaves)
- ✅ More keys per internal node (smaller tree)
- ✅ Faster full scans (just traverse leaf level)
- ✅ Consistent search time (always to leaf)
- ✅ Better cache locality (sequential leaf access)

**B+ Tree Disadvantages:**
- ❌ Always must go to leaf (one extra level sometimes)
- ❌ Keys duplicated (in internal + leaf nodes)
