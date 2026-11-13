-- Part 2
USE hw6;

-- Problem 3
SELECT '=== Part 2 Problem 3 ===' AS section;
CREATE TABLE IF NOT EXISTS GameTablePart (
  review_id BIGINT,
  reviewer_id STRING,
  product_id STRING,
  reviewer_name STRING,
  helpful_votes BIGINT,
  total_votes BIGINT,
  review_text STRING,
  summary STRING,
  review_date STRING,
  unix_review_time BIGINT
)
PARTITIONED BY (star_rating INT)
STORED AS ORC
TBLPROPERTIES ('transactional'='false');

SHOW CREATE TABLE GameTablePart;
DESCRIBE FORMATTED GameTablePart;

-- Problem 4
SELECT '=== Part 2 Problem 4 ===' AS section;
INSERT OVERWRITE TABLE GameTablePart PARTITION (star_rating=1)
SELECT review_id, reviewer_id, product_id, reviewer_name, helpful_votes,
       total_votes, review_text, summary, review_date, unix_review_time
FROM GameTable
WHERE star_rating=1;

INSERT OVERWRITE TABLE GameTablePart PARTITION (star_rating=2)
SELECT review_id, reviewer_id, product_id, reviewer_name, helpful_votes,
       total_votes, review_text, summary, review_date, unix_review_time
FROM GameTable
WHERE star_rating=2;

SHOW PARTITIONS GameTablePart;

SELECT COUNT(*) AS source_low_rating_rows FROM GameTable WHERE star_rating IN (1, 2);
SELECT COUNT(*) AS partitioned_rows FROM GameTablePart;

-- Problem 5
SELECT '=== Part 2 Problem 5 ===' AS section;
SELECT star_rating, SUM(helpful_votes) AS sum_helpful_votes,
       SUM(total_votes) AS sum_total_votes
FROM GameTablePart
GROUP BY star_rating
ORDER BY sum_total_votes DESC, star_rating;
