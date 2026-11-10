-- Part 1
CREATE DATABASE IF NOT EXISTS hw6;
USE hw6;

CREATE TABLE IF NOT EXISTS GameInput (
  record STRING
)
STORED AS TEXTFILE
TBLPROPERTIES ('transactional'='false');

LOAD DATA LOCAL INPATH '${hiveconf:DATA_PATH}' OVERWRITE INTO TABLE GameInput;

-- Problem 1
CREATE TABLE IF NOT EXISTS GameTable (
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
STORED AS ORC
TBLPROPERTIES ('transactional'='false');

INSERT OVERWRITE TABLE GameTable
SELECT CAST(j.review_id AS BIGINT), j.reviewer_id, j.product_id,
       j.reviewer_name, CAST(j.star_rating AS DOUBLE),
       CAST(get_json_object(j.helpful, '$[0]') AS BIGINT),
       CAST(get_json_object(j.helpful, '$[1]') AS BIGINT),
       j.review_text, j.summary, j.review_date,
       CAST(j.unix_review_time AS BIGINT)
FROM GameInput source
LATERAL VIEW json_tuple(source.record,
  'review_id', 'reviewerID', 'asin', 'reviewerName', 'overall', 'helpful',
  'reviewText', 'summary', 'reviewTime', 'unixReviewTime') j AS
  review_id, reviewer_id, product_id, reviewer_name, star_rating, helpful,
  review_text, summary, review_date, unix_review_time;

DESCRIBE FORMATTED GameTable;
SELECT * FROM GameTable ORDER BY review_id LIMIT 5;
SELECT COUNT(*) AS loaded_rows, COUNT(DISTINCT review_id) AS unique_review_ids
FROM GameTable;

-- Problem 2
SELECT product_id, COUNT(*) AS review_count, AVG(star_rating) AS average_star_rating
FROM GameTable
GROUP BY product_id
ORDER BY product_id;

-- Problem 3
SELECT star_rating, SUM(helpful_votes) AS sum_helpful_votes,
       SUM(total_votes) AS sum_total_votes
FROM GameTable
GROUP BY star_rating
ORDER BY star_rating;
