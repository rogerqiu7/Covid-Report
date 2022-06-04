-- Sales Analysis report query

-- Skills used: JOINS, CASE STATEMENTS,COMMON TABLE EXPRESSIONS (CTE), AGGREGATE and WINDOW functions.

-- first, create our database
CREATE DATABASE sales;

-- First, lets inspect our data
SELECT * FROM sales_data_sample LIMIT 5;

-- Now let's check out all our unique values
SELECT DISTINCT status from sales_data_sample; -- 6 distinct status, can plot 
SELECT DISTINCT year_id from sales_data_sample; -- 2003 to 2005
SELECT DISTINCT PRODUCTLINE from sales_data_sample; -- 7 transportation product lines, can plot
SELECT DISTINCT COUNTRY from sales_data_sample; -- 19 countries, can plot
SELECT DISTINCT DEALSIZE from sales_data_sample; -- small, medium and large sizes, can plot
SELECT DISTINCT TERRITORY from sales_data_sample;-- NA, EMEA, APAC and Japan, can plot 

-- Let's start by grouping and reviewing sales by productline
-- select products and use basic window function, (sum) of sales as revenue, grouped by productline and sorted by revenue
SELECT PRODUCTLINE, SUM(sales) Revenue
FROM sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY 2 DESC;
-- classic and vintage cars have largest revenue, ships and train have lowest

-- now lets see how we did each year
-- select year and sum of sales as revenue, grouped by productline and sorted by revenue
SELECT YEAR_ID, SUM(sales) Revenue
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY 2 DESC;
-- 2004 had the most revenue, 2005 the least, or atleast it appears.

-- lets look closer at 2005
SELECT DISTINCT MONTH_ID FROM sales_data_sample
WHERE year_id = 2005;
-- there is only 5 months, thats why the annual sales appears low

-- lets also look at dealsizes by revenue
SELECT  DEALSIZE,  sum(sales) Revenue
FROM sales_data_sample
GROUP BY  DEALSIZE
ORDER BY 2 DESC;
-- seems most of our revenue are from medium deals and least from large

-- lets find the best month for sales in each year? How much was earned that month? 
-- select the month, total sales that month, and number of orders that month in one year, group by month, order by revenue 
SELECT MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Frequency
FROM sales_data_sample
WHERE YEAR_ID = 2005 -- change year to see other years
GROUP BY MONTH_ID
ORDER BY 2 DESC;
-- in 2003, Nov and Oct had most revenue and orders with Jan and Feb having least
-- in 2004, also Nov and Oct with most and Mar, Apr having least
-- so far in 2005, May is most and Jan, Apr has least
-- sales seems to be highest in the end of the year and fewest at the beginning

-- November seems to be key month, what products do they sell in November?
-- lets select by month, product, sales and order count, from a specific year and month, order by revenue
SELECT  MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ORDERNUMBER)
FROM sales_data_sample
WHERE YEAR_ID = 2004 AND MONTH_ID = 11 -- change to see other years/months
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC;
-- classic and vintage cars have highest revenue in november with ships and trains the least for all years

--  We can find the city has the highest number of sales in a specific country
-- select city and total sales revenue, in UK, sort by revenue
SELECT city, SUM(sales) Revenue
FROM sales_data_sample
WHERE country = 'UK'
GROUP BY city
ORDER BY 2 DESC;

-- Manchester has the highest revenue

-- What is the best product in the country?
-- select our country, year, the product and the revenue, lets group by country, year and product
SELECT country, YEAR_ID, PRODUCTLINE, SUM(sales) Revenue
FROM sales_data_sample
WHERE country = 'USA'
GROUP BY country, YEAR_ID, PRODUCTLINE
ORDER BY 4 DESC;

-- classic cars are the best selling items in the USA.


-- Finally, Let's find out who our best customer is, this is best answered with (Recency-Frequency-Monetary) RFM
-- this indexing technique using past purchase behavior to segment customers using 3 metrics:
-- recency: how long ago their purchase was
-- frequency: how often they purchase
-- monetary: how much they spent

-- lets start by creating the following below as a temporary table so we can easily access it later
CREATE TEMPORARY TABLE rfm 

-- now well create our RFM analysis using a 2-layered CTE, which are queries that exist temporarily to use only within the context of a larger query.
-- rfm will be the first common table expression name
WITH rfm AS 
(
-- select the customername, total and avg sales and monetary and avg monetary value
-- count of orders as frequency
-- highest orderdate as the last order date, will be the last time the customers ordered
-- max orderdate in the table as max order date, will always be 2005-05-31
-- use datediff function, takes(the last order date of the table, last order date of customer) as Recency
-- shorter the recency, the more recently the customer purchased
	SELECT 
		CUSTOMERNAME, 
		SUM(sales) MonetaryValue,
		AVG(sales) AvgMonetaryValue,
		COUNT(ORDERNUMBER) Frequency,
		MAX(ORDERDATE) last_order_date,
        (SELECT MAX(ORDERDATE) FROM sales_data_sample) max_order_date,
        DATEDIFF((SELECT MAX(ORDERDATE) FROM sales_data_sample), MAX(ORDERDATE)) Recency
	FROM sales_data_sample
	GROUP BY CUSTOMERNAME
    -- now that we have these 92 customers and their RFMs, lets group them into 4 equal groups
),
-- rfm_calc is the next layer of our CTE
rfm_calc AS
(
-- ntile(insert number of buckets we want) order by recency and name it rfm_recency
-- create the same 4 buckets for frequency and total monetary value
	SELECT *,
		NTILE(4) OVER (ORDER BY Recency DESC) rfm_recency,
		NTILE(4) OVER (ORDER BY Frequency) rfm_frequency,
		NTILE(4) OVER (ORDER BY MonetaryValue) rfm_monetary
	FROM rfm 
-- we can see the 3 new columns with our rfm rankings, the higher the rfm, the better the customer
-- customers that are have all as 4 are our best customers
)
-- now lets add our 3 rfm columns together and name it rfm_cell. 
SELECT *, rfm_recency + rfm_frequency + rfm_monetary AS rfm_cell,
-- lets also create a column where we concatanate the 3 columns together and call it rfm cell string
CONCAT(rfm_recency, rfm_frequency, rfm_monetary) AS rfm_cell_string
FROM rfm_calc;

-- lets see how our temp table looks
SELECT * FROM rfm;

-- now we create the table to segment and catogorize our customers into different preset rfm categories based on their rfm_string
-- well use a CASE statement to return the categories based on the values in our rfm_cell_string
-- for example, customers that are 111, do all 3 poorly so they are our lost customers
-- customers that are 444 do well in all 3 areas to they are our best and loyal customers
SELECT CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	CASE 
		WHEN rfm_cell_string IN (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141, 221) THEN 'bad customer'  -- lost customers, low in all aspects
		WHEN rfm_cell_string IN (133, 134, 143, 244, 334, 343, 344, 144, 234) THEN 'slipping customer' -- Big spenders who haven’t purchased lately
		WHEN rfm_cell_string IN (311, 411, 421, 412, 331, 423) THEN 'new customer' -- recently purchased but not frequent or a lot
		WHEN rfm_cell_string IN (222, 223, 233, 322, 232) THEN 'decent customer'-- can potentially be good customers
		WHEN rfm_cell_string IN (323, 333, 321, 422, 332, 432) THEN 'active customer' -- customers who buy often & recently, but at low price points
		WHEN rfm_cell_string IN (433, 434, 443, 444) THEN 'best customer' -- good customers
	END rfm_segment
FROM rfm;

-- now we have a nice list of customers and their category which we can now import to excel and use for decision making