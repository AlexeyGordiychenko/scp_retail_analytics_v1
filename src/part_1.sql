-- DROP DATABASE IF EXISTS Retail_Analytics;
-- CREATE DATABASE Retail_Analytics;
DROP TABLE IF EXISTS Customers CASCADE;
DROP TABLE IF EXISTS Cards CASCADE;
DROP TABLE IF EXISTS Product_Groups CASCADE;
DROP TABLE IF EXISTS Products CASCADE;
DROP TABLE IF EXISTS Stores CASCADE;
DROP TABLE IF EXISTS Transactions CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TABLE IF EXISTS Analysis_Date CASCADE;
-- Create the Customers table
CREATE TABLE IF NOT EXISTS Customers (
    Customer_ID SERIAL PRIMARY KEY,
    Customer_Name VARCHAR(50) NOT NULL CHECK (Customer_Name ~ '^[A-Za-zА-Яа-яЁё\s\-]+$'),
    Customer_Surname VARCHAR(50) NOT NULL CHECK (Customer_Surname ~ '^[A-Za-zА-Яа-яЁё\s\-]+$'),
    Customer_Primary_Email VARCHAR(50) UNIQUE CHECK (
        Customer_Primary_Email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'
    ),
    Customer_Primary_Phone VARCHAR(15) UNIQUE CHECK (Customer_Primary_Phone ~ '^\+7[0-9]{10}$')
);
-- Create the Cards table
CREATE TABLE IF NOT EXISTS Cards (
    Customer_Card_ID SERIAL PRIMARY KEY,
    Customer_ID INT REFERENCES Customers(Customer_ID) NOT NULL
);
-- Create the Product_Groups table
CREATE TABLE IF NOT EXISTS Product_Groups (
    Group_ID SERIAL PRIMARY KEY,
    Group_Name VARCHAR(50) NOT NULL
);
-- Create the Products table
CREATE TABLE IF NOT EXISTS Products (
    SKU_ID SERIAL PRIMARY KEY,
    SKU_Name VARCHAR(50) NOT NULL,
    Group_ID INT REFERENCES Product_Groups(Group_ID) NOT NULL
);
-- Create the Stores table
CREATE TABLE IF NOT EXISTS Stores (
    Transaction_Store_ID SERIAL PRIMARY KEY,
    SKU_ID SERIAL REFERENCES Products(SKU_ID) NOT NULL,
    SKU_Purchase_Price NUMERIC(10, 2) NOT NULL,
    SKU_Retail_Price NUMERIC(10, 2) NOT NULL
);
-- Create the Transactions table
CREATE TABLE IF NOT EXISTS Transactions (
    Transaction_ID SERIAL PRIMARY KEY,
    Customer_Card_ID INT REFERENCES Cards(Customer_Card_ID) NOT NULL,
    Transaction_Summ NUMERIC(10, 2) NOT NULL,
    Transaction_DateTime TIMESTAMP NOT NULL,
    Transaction_Store_ID INT REFERENCES Stores(Transaction_Store_ID) NOT NULL
);
-- Create the Checks table
CREATE TABLE IF NOT EXISTS Checks (
    Transaction_ID INT REFERENCES Transactions(Transaction_ID) PRIMARY KEY,
    SKU_ID INT REFERENCES Products(SKU_ID) NOT NULL,
    SKU_Amount NUMERIC(10, 2) NOT NULL,
    SKU_Summ NUMERIC(10, 2) NOT NULL,
    SKU_Summ_Paid NUMERIC(10, 2) NOT NULL,
    SKU_Discount NUMERIC(10, 2) NOT NULL
);
-- Create the Analysis_Date table
CREATE TABLE IF NOT EXISTS Analysis_Date (Analysis_Formation TIMESTAMP PRIMARY KEY);