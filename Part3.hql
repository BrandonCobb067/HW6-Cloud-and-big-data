USE hw6;

SELECT '=== Part 3 Problem 6 ===' AS section;
CREATE TABLE IF NOT EXISTS GameTableBuck (
  review_id BIGINT,
  reviewer_id STRING,
  product_id STRING,
  reviewer_name STRING,
  star_rating DOUBLE,
  helpful_votes BIGINT,
  total_votes BIGINT,
  review_text STRING,
  summary STRING,
  review_date STRING,
  unix_review_time BIGINT
)
CLUSTERED BY (unix_review_time) INTO 3 BUCKETS
STORED AS ORC
TBLPROPERTIES ('transactional'='false');

SHOW CREATE TABLE GameTableBuck;
DESCRIBE FORMATTED GameTableBuck;

SET hive.enforce.bucketing = true;

INSERT OVERWRITE TABLE GameTableBuck
SELECT * FROM GameTable;

SELECT '=== Part 3 Problem 7 ===' AS section;
SELECT REGEXP_EXTRACT(INPUT__FILE__NAME, '([^/]+)$', 1) AS bucket_file,
       MIN(CAST(FROM_UNIXTIME(UNIX_TIMESTAMP(review_date, 'MM d, yyyy'), 'yyyy-MM-dd') AS DATE)) AS min_review_date,
       MAX(CAST(FROM_UNIXTIME(UNIX_TIMESTAMP(review_date, 'MM d, yyyy'), 'yyyy-MM-dd') AS DATE)) AS max_review_date,
       COUNT(*) AS review_count
FROM GameTableBuck
GROUP BY REGEXP_EXTRACT(INPUT__FILE__NAME, '([^/]+)$', 1)
ORDER BY bucket_file;

SELECT '=== Part 3 Problem 8 ===' AS section;
SELECT product_id,
       AVG(helpful_votes) AS avg_helpful_votes,
       AVG(total_votes) AS avg_total_votes
FROM GameTableBuck
GROUP BY product_id
HAVING AVG(helpful_votes) > 1
ORDER BY product_id;
