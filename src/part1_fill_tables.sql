CALL import('Customers', '../datasets/Personal_Data_Mini.tsv', E'\t');
CALL import('Cards', '../datasets/Cards_Mini.tsv', E'\t');
CALL import('Product_Groups', '../datasets/Groups_SKU_Mini.tsv', E'\t');
CALL import('Products', '../datasets/SKU_Mini.tsv', E'\t');
CALL import('Stores', '../datasets/Stores_Mini.tsv', E'\t');
CALL import('Transactions', '../datasets/Transactions_Mini.tsv', E'\t');
CALL import('Checks', '../datasets/Checks_Mini.tsv', E'\t');
CALL import('Analysis_Date', '../datasets/Date_Of_Analysis_Formation.tsv', E'\t');

\COPY Customers FROM '../datasets/Personal_Data_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY Cards FROM '../datasets/Cards_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY Product_Groups FROM '../datasets/Groups_SKU_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY Products FROM '../datasets/SKU_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY Stores FROM '../datasets/Stores_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY Transactions FROM '../datasets/Transactions_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY Checks FROM '../datasets/Checks_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY Analysis_Date FROM '../datasets/Date_Of_Analysis_Formation.tsv' WITH CSV DELIMITER E'\t';