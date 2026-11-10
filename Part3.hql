-- Part 3
USE hw6;

-- Problem 6
-- Choice for bucketing: unix_review_time
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

-- (Loading data into the bucketed table for Problem 7)
SET hive.enforce.bucketing = true;

INSERT OVERWRITE TABLE GameTableBuck
SELECT * FROM GameTable;

-- Problem 7
-- Finding min and max review_date for each bucket.
-- Hive assigns buckets using pmod(hash(column), num_buckets).
SELECT pmod(hash(unix_review_time), 3) AS bucket_id,
       MIN(review_date) AS min_review_date,
       MAX(review_date) AS max_review_date
FROM GameTableBuck
GROUP BY pmod(hash(unix_review_time), 3)
ORDER BY bucket_id;


-- Problem 8
SELECT product_id,
       AVG(helpful_votes) AS avg_helpful_votes,
       AVG(total_votes) AS avg_total_votes
FROM GameTableBuck
GROUP BY product_id
HAVING AVG(helpful_votes) > 1;

