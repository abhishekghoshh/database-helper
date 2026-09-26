# JSON Support

## JSON

PostgreSQL's `JSON` type stores JSON text exactly as it was input, byte-for-byte, including whitespace and key ordering. It validates that the input is well-formed JSON but does not parse it into any internal binary structure — every query that inspects the JSON has to re-parse the raw text.

```sql
CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    payload JSON NOT NULL
);

INSERT INTO events (event_type, payload)
VALUES ('user.signup', '{"userId": 42, "plan": "pro", "tags": ["trial", "referred"]}');
```

`JSON` is appropriate when you mostly store-and-retrieve the document as-is (e.g. an audit log where preserving the exact original text matters) and rarely query into its structure.

## JSONB

`JSONB` stores JSON in a decomposed **binary** format: whitespace is discarded, keys are de-duplicated (last value wins), and key order is not preserved. Because it's already parsed, `JSONB` supports efficient querying, indexing (including GIN indexes), and containment operators — at the cost of slightly slower input (it must be parsed on write) and slightly larger storage.

```sql
CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL
);

CREATE INDEX idx_events_payload ON events USING GIN (payload);
```

**`JSON` vs `JSONB`**

| Aspect | `JSON` | `JSONB` |
|---|---|---|
| Storage format | Exact text copy | Parsed, decomposed binary |
| Preserves key order / whitespace / duplicate keys | Yes | No (last duplicate key wins, order not preserved) |
| Write speed | Faster (no parsing) | Slightly slower (must parse on write) |
| Query/read speed | Slower (re-parses every time) | Faster (already parsed) |
| Indexing support | None | GIN indexes on the whole document or specific paths |
| Recommended default | Rarely — only when exact text fidelity is required | Yes — the practical default for almost all use cases |

## JSON Operators

PostgreSQL provides dedicated operators for extracting values and testing structure without needing string functions.

```sql
-- ->  : get JSON object field as JSON/JSONB
-- ->> : get JSON object field as text
-- #>  : get JSON object at a path, as JSON/JSONB
-- #>> : get JSON object at a path, as text
SELECT payload -> 'plan' AS plan_json,      -- "pro"        (JSON value)
       payload ->> 'plan' AS plan_text,     -- pro          (text)
       payload #>> '{tags,0}' AS first_tag  -- trial        (text at path)
FROM events
WHERE id = 1;

-- Containment: does the left JSONB contain the right JSONB?
SELECT * FROM events WHERE payload @> '{"plan": "pro"}';

-- Existence: does the JSONB object contain this top-level key?
SELECT * FROM events WHERE payload ? 'tags';
```

## Querying JSON Fields

Because `->>` extracts JSON values as text, they can be used directly in `WHERE`, `ORDER BY`, and even joined against relational columns like any other predicate.

```sql
-- Find all "pro" plan signups
SELECT id, payload ->> 'userId' AS user_id
FROM events
WHERE event_type = 'user.signup'
  AND payload ->> 'plan' = 'pro';

-- Query a nested array element with a GIN-backed containment check (uses the index)
SELECT id FROM events
WHERE payload @> '{"tags": ["referred"]}';

-- Cast an extracted text value to a real type for numeric comparisons
SELECT id FROM events
WHERE (payload ->> 'amount')::numeric > 100;
```

A GIN index on the `payload` column (`USING GIN (payload)`) lets containment queries (`@>`) use an index scan instead of evaluating every row, which is the main reason `JSONB` is preferred whenever the JSON needs to be searched.

## Updating JSON Data

PostgreSQL supports partial, in-place updates to `JSONB` values without needing to overwrite the entire document from the application.

```sql
-- jsonb_set(target, path, new_value, create_missing)
UPDATE events
SET payload = jsonb_set(payload, '{plan}', '"enterprise"', true)
WHERE id = 1;

-- Merge (concatenate) additional keys into the document
UPDATE events
SET payload = payload || '{"upgraded": true}'::jsonb
WHERE id = 1;

-- Remove a key
UPDATE events
SET payload = payload - 'tags'
WHERE id = 1;
```

Real-life scenario: a `product_attributes` `JSONB` column lets an e-commerce catalog store wildly different attribute sets per category (a shirt has `size`/`color`, a laptop has `ram`/`cpu`) without a sparse, ever-growing set of nullable columns or a full EAV (entity-attribute-value) schema — while still allowing indexed queries like "find all products where `attributes @> '{"color": "red"}'`.

#### Interview Questions

1. **What is the fundamental storage difference between `JSON` and `JSONB` in PostgreSQL?**
   `JSON` stores the exact input text verbatim (preserving whitespace, key order, and duplicate keys), re-parsing it on every read. `JSONB` stores a parsed, decomposed binary representation (no whitespace, de-duplicated keys, order not preserved), which is faster to query and supports indexing at the cost of slightly slower writes.
2. **Why would you almost always choose `JSONB` over `JSON` in a new schema?**
   `JSONB` supports efficient querying via operators like `@>`, `?`, and `->>`, and can be indexed with GIN indexes for fast containment lookups. `JSON`'s only real advantage — preserving the exact original text/formatting — is rarely a requirement, so `JSONB`'s query performance advantage usually wins.
3. **What is the difference between the `->` and `->>` operators?**
   `->` returns the field as a JSON/JSONB value (so it can be further navigated or compared to other JSON), while `->>` returns the field as plain text, which is what you need for string comparisons, casting to other types, or displaying the value.
4. **How does the `@>` containment operator work, and why does it benefit from a GIN index?**
   `@>` checks whether the JSONB document on the left contains the structure on the right (e.g. `payload @> '{"plan": "pro"}'` matches any document with that key/value present anywhere satisfying containment rules). A GIN index on the column indexes the individual keys/values inside the JSONB, so PostgreSQL can look up matching documents directly instead of evaluating the containment check against every row.
5. **When would you choose a `JSONB` column over fully normalizing data into relational columns/tables?**
   When the schema is genuinely dynamic or sparse per row (e.g. product attributes that vary wildly by category) and adding a new relational column or junction table for every possible attribute would be impractical. It's a trade-off: you gain schema flexibility but lose some of the type safety, constraint enforcement, and joinability that normalized columns provide.
6. **How would you update a single nested field inside a `JSONB` column without overwriting the whole document?**
   Use `jsonb_set(column, '{path,to,field}', new_value, true)`, which returns a new JSONB value with only that path replaced (or created, if the last argument is `true`), leaving the rest of the document untouched; the result still needs to be written back with an `UPDATE ... SET column = jsonb_set(...)`.
