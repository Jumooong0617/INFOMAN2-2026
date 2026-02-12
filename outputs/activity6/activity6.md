## Query Analysis and Optimization


### Scenario 1: The Slow Author Profile Page

**Before Query Plan and Execution times**
```txt
                                             QUERY PLAN
-------------------------------------------------------------------------------------------------------------
 Sort  (cost=625.61..625.68 rows=26 width=52) (actual time=10.043..10.046 rows=26.00 loops=1)
   Sort Key: date DESC
   Sort Method: quicksort  Memory: 26kB
   Buffers: shared hit=3 read=500
   ->  Seq Scan on posts  (cost=0.00..625.00 rows=26 width=52) (actual time=1.407..9.415 rows=26.00 loops=1)
         Filter: (author_id = 16)
         Rows Removed by Filter: 9974
         Buffers: shared read=500
 Planning:
   Buffers: shared hit=87 read=26
 Planning Time: 25.391 ms
 Execution Time: 12.128 ms

```

**Query:**
```sql
CREATE INDEX idx_auhor_id on posts(author_id);

                                                      QUERY PLAN
----------------------------------------------------------------------------------------------------------------------
 Index Scan using posts_pkey on posts  (cost=0.29..8.30 rows=1 width=48) (actual time=0.137..0.139 rows=1.00 loops=1)
   Index Cond: (id = 16)
   Index Searches: 1
   Buffers: shared hit=1 read=2
 Planning:
   Buffers: shared hit=63 read=20 dirtied=2
 Planning Time: 36.785 ms
 Execution Time: 2.183 ms
(8 rows)
```

**Analysis Questions:**
*   What is the primary node causing the slowness in the initial execution plan?  
<u>The query was slow because PostgreSQL performed a sequential scan of all 10,000 rows in the `posts` table to retrieve only 26 matching records. This occurred because there was no index on the `author_id` column.</u>

*   How can you optimize both the `WHERE` clause filtering and the `ORDER BY` operation with a single change?  
<u>You can optimize both operations by creating an index on the author_id column: CREATE INDEX idx_author_id ON posts(author_id), which improves the filtering performance significantly. To further optimize we can create another index on the date coloumn tp eliminate the sort operation entirely and provide an even better performance.</u>

*   After adding the index on author_id, the query time dropped from about 12 ms to around 4–5 ms. The plan changed to a Bitmap Heap Scan, and the database only scans the 26 matching rows instead of all 10,000. The sort step remains, but its impact is minimal since it runs on a small result set.</u>



### Scenario 2: The Unsearchable Blog

**Before Query Plan and Execution times**
```txt
                                               QUERY PLAN
--------------------------------------------------------------------------------------------------------
 Seq Scan on posts  (cost=0.00..625.00 rows=101 width=48) (actual time=0.019..3.977 rows=99.00 loops=1)
   Filter: ((title)::text ~~ '%Molestiae%'::text)
   Rows Removed by Filter: 9901
   Buffers: shared hit=500
 Planning:
   Buffers: shared hit=6 dirtied=1
 Planning Time: 1.357 ms
 Execution Time: 4.006 ms
(8 rows)
```
**Query:**
```sql
CREATE INDEX idx_posts_title ON posts(title);
activity6_db=# EXPLAIN ANALYZE SELECT id, title FROM posts WHERE title LIKE '%Molestiae%';
                                               QUERY PLAN
--------------------------------------------------------------------------------------------------------
 Seq Scan on posts  (cost=0.00..625.00 rows=101 width=48) (actual time=0.030..3.926 rows=99.00 loops=1)
   Filter: ((title)::text ~~ '%Molestiae%'::text)
   Rows Removed by Filter: 9901
   Buffers: shared hit=500
 Planning:
   Buffers: shared hit=16 read=1
 Planning Time: 2.546 ms
 Execution Time: 3.958 ms
(8 rows)
```

**Analysis Questions:**
*   First, try adding a standard B-Tree index on the `title` column. Run `EXPLAIN ANALYZE` again. Did the planner use your index? Why or why not?
<u>No. PostgreSQL did not use the B-Tree index and instead performed a sequential scan. This is because a LIKE pattern that begins with a leading wildcard (%database%) is not indexable using a standard B-Tree index. The planner must evaluate the predicate against every row, resulting in a full table scan.</u>

*    The business team agrees that searching by a *prefix* is acceptable for the first version. Rewrite the query to use a prefix search (e.g., `database%`). 
<u>EXPLAIN ANALYZE SELECT id, title FROM posts WHERE title LIKE 'database%'; </u>>
```sql
                                                             QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using idx_posts_title on posts  (cost=0.29..523.28 rows=101 width=44) (actual time=2.173..4.238 rows=99.00 loops=1)
   Filter: ((title)::text ~~ '%Molestiae%'::text)
   Rows Removed by Filter: 9901
   Heap Fetches: 20
   Index Searches: 1
   Buffers: shared hit=2 read=84
 Planning Time: 0.225 ms
 Execution Time: 4.268 ms
(8 rows)
```

*   Does the index work for the prefix-style query? Explain the difference in the execution plan.
<u>Yes, the index works for the prefix-style query. When the search pattern does not start with %, PostgreSQL can use the B-Tree index on title, resulting in an Index Only Scan instead of a sequential scan. This allows the database to locate matching rows using the index rather than scanning the entire table, which improves performance.</u>

### Scenario 3: The Monthly Performance Report

**Before Query Plan and Execution times**
```txt
EXPLAIN ANALYZE SELECT date FROM posts WHERE EXTRACT(YEAR FROM date) = 2015 AND EXTRACT(MONTH FROM date) = 1;

                                              QUERY PLAN
-------------------------------------------------------------------------------------------------------
 Seq Scan on posts  (cost=0.00..700.00 rows=1 width=4) (actual time=0.236..5.382 rows=22.00 loops=1)
   Filter: ((EXTRACT(year FROM date) = '2015'::numeric) AND (EXTRACT(month FROM date) = '1'::numeric))
   Rows Removed by Filter: 9978
   Buffers: shared hit=500
 Planning:
   Buffers: shared hit=6 dirtied=1
 Planning Time: 1.355 ms
 Execution Time: 5.409 ms
(8 rows)
```


**Query:**
```sql
EXPLAIN ANALYZE SELECT date FROM posts WHERE date >= '2015-01-01' AND date <  '2015-02-01';
                                              QUERY PLAN
------------------------------------------------------------------------------------------------------
 Seq Scan on posts  (cost=0.00..650.00 rows=16 width=4) (actual time=0.465..4.426 rows=14.00 loops=1)
   Filter: ((date >= '2000-01-01'::date) AND (date < '2000-02-01'::date))
   Rows Removed by Filter: 9986
   Buffers: shared hit=500
 Planning Time: 0.155 ms
 Execution Time: 4.458 ms
(6 rows)
```

**Analysis Questions:**
*   This query is not S-ARGable. What does that mean in the context of this query? Why can't the query planner use a simple index on the `date` column effectively?
<u>It is not S-ARGable because the date column is wrapped in functions (EXTRACT), forcing PostgreSQL to evaluate the expression for every row. This prevents efficient use of an index on date, resulting in a sequential scan.</u>

*   Rewrite the query to use a direct date range comparison, making it S-ARGable.
```sql
EXPLAIN ANALYZE SELECT date FROM posts WHERE date >= '2015-01-01' AND date <  '2015-02-01';
```
*   Create an appropriate index to support your rewritten query.
```sql
CREATE INDEX idx_posts_date ON posts (date);
EXPLAIN ANALYZE SELECT date FROM posts WHERE date >= '2015-01-01' AND date <  '2015-02-01';
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using idx_posts_date on posts  (cost=0.29..8.61 rows=16 width=4) (actual time=0.396..0.402 rows=22.00 loops=1)
   Index Cond: ((date >= '2015-01-01'::date) AND (date < '2015-02-01'::date))
   Heap Fetches: 0
   Index Searches: 1
   Buffers: shared hit=1 read=2
 Planning:
   Buffers: shared hit=74 read=1
 Planning Time: 4.509 ms
 Execution Time: 0.486 ms
(9 rows)
```
*   Compare the performance of the original query and your optimized version.
<u>The original query used a sequential scan with an execution time of approximately 5.41 ms. After rewriting the predicate to a S-ARGable date range and creating an index on date, PostgreSQL used an Index Only Scan, reducing the execution time to approximately 0.49 ms, which is a significant performance improvement.</u>

---