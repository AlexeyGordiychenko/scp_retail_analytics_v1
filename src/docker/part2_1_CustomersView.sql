CREATE OR REPLACE FUNCTION analyzed_period() RETURNS TIMESTAMP AS $$
	BEGIN
		RETURN (SELECT MAX(analysis_formation) FROM analysis_date);
	END;
$$ LANGUAGE PLPGSQL;

DROP TABLE IF EXISTS segments CASCADE;

CREATE TABLE segments 
(
	segment BIGINT PRIMARY KEY,
	average_check VARCHAR NOT NULL,
	frequency_of_purchases VARCHAR NOT NULL,
	churn_probability VARCHAR NOT NULL
);

CALL import('segments', '/home/Segments.tsv', E'\t');
--CALL import_data ('Segments', '/tmp/Segments.csv', ',');

---Функция, возвращающая таблицу со всеми транзакциями клиентов---

CREATE OR REPLACE FUNCTION customer_transactions() 
RETURNS TABLE (customer_id BIGINT, 
				transaction_id BIGINT, 
				customer_card_id BIGINT, 
				transaction_summ NUMERIC, 
				transaction_datetime TIMESTAMP, 
				transaction_store_id BIGINT) 
AS $$
SELECT customer_id,
		transaction_id, 
		t.customer_card_id,
		transaction_summ, 
		transaction_datetime, 
		transaction_store_id
FROM transactions t
JOIN cards c ON t.customer_card_id = c.customer_card_id
WHERE transaction_datetime <= analyzed_period()
ORDER BY customer_id, transaction_datetime DESC
$$ LANGUAGE SQL;

---Функция, возвращающая таблицу с основным магазином для каждого клиента---

CREATE OR REPLACE FUNCTION main_store() 
RETURNS TABLE (customer_id BIGINT, main_store BIGINT) 
AS $$
WITH count_transactions_each_store AS
(SELECT customer_id,
		transaction_store_id,
		count(transaction_id) AS count_transactions
FROM customer_transactions()
GROUP BY customer_id, transaction_store_id
ORDER BY 1, 2),
count_total_transactions AS
(SELECT customer_id,
		count(transaction_id) AS total_customer_transactions
FROM customer_transactions()
GROUP BY customer_id
ORDER BY 1),
share_transactions AS
(SELECT ctes.customer_id,
		transaction_store_id,
		(count_transactions::NUMERIC / total_customer_transactions) AS share_transactions,
		dense_rank() OVER (PARTITION BY ctes.customer_id ORDER BY (count_transactions::NUMERIC / total_customer_transactions) DESC) AS raiting_transactions
FROM count_transactions_each_store ctes	
JOIN count_total_transactions ctt ON ctes.customer_id = ctt.customer_id
ORDER BY 1),
last_max_share AS
(SELECT customer_id, transaction_store_id
FROM (SELECT st.*,
			transaction_datetime,
			rank() OVER (PARTITION BY st.customer_id ORDER BY transaction_datetime DESC) AS last_date
		FROM share_transactions st 
		JOIN customer_transactions() ct ON st.customer_id = ct.customer_id 
										AND st.transaction_store_id = ct.transaction_store_id
		WHERE raiting_transactions = 1
		ORDER BY 1)
WHERE last_date = 1
ORDER BY 1),
three_recent_transactions AS
(SELECT customer_id, transaction_store_id
FROM (SELECT customer_id,
			 transaction_store_id,
			 transaction_datetime,
			 ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY transaction_datetime DESC) AS raiting
		FROM customer_transactions()
		ORDER BY customer_id, raiting)
WHERE raiting < 4
GROUP BY customer_id, transaction_store_id	
ORDER BY 1),
count_stores AS
(SELECT customer_id, count(transaction_store_id)
FROM three_recent_transactions
GROUP BY 1
ORDER BY 1)
SELECT DISTINCT cs.customer_id,
		(CASE 
			WHEN count = 1 THEN first_value(trt.transaction_store_id) OVER (PARTITION BY trt.customer_id) 
			ELSE lms.transaction_store_id
		END) AS main_store
FROM count_stores cs	
JOIN three_recent_transactions trt ON cs.customer_id = trt.customer_id	
JOIN last_max_share lms ON cs.customer_id = lms.customer_id
ORDER BY 1
$$ LANGUAGE SQL;

DROP VIEW IF EXISTS v_customers;

CREATE OR REPLACE VIEW v_customers AS
WITH average_check AS
(SELECT DISTINCT customer_id,
	  		 	avg(transaction_summ) OVER (PARTITION BY customer_id) AS customer_average_check
FROM customer_transactions()
ORDER BY 1),
customers_ranking_check AS
(SELECT customer_id, 
		customer_average_check, 
		percent_rank() OVER (ORDER BY customer_average_check DESC) AS raiting_average_check
FROM average_check),
average_check_segment AS
(SELECT customer_id,
		customer_average_check,
		(CASE
	   		WHEN raiting_average_check <= 0.1 THEN 'High'
	   		WHEN raiting_average_check > 0.1 AND raiting_average_check <= 0.35 THEN 'Medium'
			ELSE 'Low'
		END) AS customer_average_check_segment
FROM customers_ranking_check),
frequency AS
(SELECT DISTINCT customer_id,
	   		 	(EXTRACT (EPOCH FROM (max(transaction_datetime) OVER w - min(transaction_datetime) OVER w)/86400) / count(transaction_id) OVER w) AS customer_frequency
FROM customer_transactions()
WINDOW w AS (PARTITION BY customer_id)								 
ORDER BY 1),
customers_ranking_frequency AS	  			
(SELECT customer_id, 
		customer_frequency,
		percent_rank() OVER (ORDER BY customer_frequency) AS raiting_frequency_visits
FROM frequency),
frequency_segment AS
(SELECT customer_id,
		customer_frequency,
		(CASE
	   		WHEN raiting_frequency_visits <= 0.1 THEN 'Often'
	   		WHEN raiting_frequency_visits > 0.1 AND raiting_frequency_visits <= 0.35 THEN 'Occasionally'
			ELSE 'Rarely'
		END) AS customer_frequency_segment
FROM customers_ranking_frequency),
inactive_period AS
(SELECT DISTINCT customer_id,
			 	(EXTRACT (EPOCH FROM (analyzed_period() - max(transaction_datetime) OVER (PARTITION BY customer_id))/86400)) AS customer_inactive_period
FROM customer_transactions()								 
ORDER BY 1),
churn_rate AS
(SELECT ip.customer_id, 
		customer_inactive_period / customer_frequency AS customer_churn_rate
FROM inactive_period ip
JOIN frequency f ON ip.customer_id = f.customer_id),
churn_segment AS
(SELECT customer_id, 
		customer_churn_rate,
		(CASE
	   		WHEN customer_churn_rate <= 2 THEN 'Low'
	   		WHEN customer_churn_rate <= 5 THEN 'Medium'
			ELSE 'High'
		END) AS customer_churn_segment
FROM churn_rate),
customer_segments AS
(SELECT acs.customer_id,
		customer_average_check_segment, 
		customer_frequency_segment, 
		customer_churn_segment,
		segment AS customer_segment
FROM average_check_segment acs	
JOIN frequency_segment fs ON acs.customer_id = fs.customer_id
JOIN churn_segment cs ON acs.customer_id = cs.customer_id
LEFT JOIN segments s ON acs.customer_average_check_segment = s.average_check
 					AND fs.customer_frequency_segment = s.frequency_of_purchases
 					AND cs.customer_churn_segment = s.churn_probability
ORDER BY 1)
SELECT acs.customer_id,
		customer_average_check,
		acs.customer_average_check_segment, 
		customer_frequency,
		fs.customer_frequency_segment, 
		customer_inactive_period,
		customer_churn_rate,
		cs.customer_churn_segment,
		customer_segment,
		main_store AS customer_primary_store
FROM average_check_segment acs	
JOIN frequency_segment fs ON acs.customer_id = fs.customer_id
JOIN inactive_period ip ON acs.customer_id = ip.customer_id
JOIN churn_segment cs ON acs.customer_id = cs.customer_id
JOIN customer_segments s ON acs.customer_id = s.customer_id	
JOIN main_store() ms ON acs.customer_id = ms.customer_id
ORDER BY 1;

SELECT *
FROM v_customers;
