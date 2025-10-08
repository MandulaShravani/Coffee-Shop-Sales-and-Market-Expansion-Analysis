create database coffeeday;

-- COFFEEDAY SCHEMAS

create table cities
( city_id int primary key,
  city_name varchar(15),
  population bigint,
  estimated_rent float,
  city_rank int);
  
CREATE TABLE customers_info
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES cities(city_id)
);

CREATE TABLE products
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
);

CREATE TABLE sales
(
  sale_id int primary key,
  sale_date date,
  product_id int,
  customer_id int,
  total float,
  rating int,
  constraint fk_products FOREIGN KEY(product_id) references products(product_id),
  constraint fk_customers FOREIGN KEY(customer_id) references customers_info(customer_id)
);
-- END OF SCHEMAS


-- 1.How many people in each city are estimated to consume coffee,given that 25% of the population does?

select city_name,round((population*0.25/1000000),2) as coffee_consumers_in_millions,city_rank from cities order by 2 desc;

-- 2.What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

select ci.city_name, sum(total) as revenue
from sales as s
join customers_info as c on s.customer_id=c.customer_id
join cities as ci 
on ci.city_id= c.city_id
where 
   extract(year from s.sale_date) = 2023
   and
   extract(quarter from s.sale_date)=4
group by 1
order by 2 desc;

-- 3.How many units of each coffee has been sold?

select p.product_name,count(s.product_id) as units from
products as p
left join sales as s 
on p.product_id=s.product_id
group by p.product_name
order by 2 desc;  

-- 4.What is the average sales amount per customer in each city?

select ci.city_name,count(distinct c.customer_id) as customer_count,round(sum(s.total)/count(distinct c.customer_id),2) as average_sales
from sales as s
right join customers_info as c
on s.customer_id=c.customer_id
join cities as ci
on ci.city_id=c.city_id
group by ci.city_name
order by average_sales desc;

-- 5.Provide list of cities along with their populations and estimated coffee consumers

WITH city_table as 
(
	SELECT 
		city_name,
		ROUND((population * 0.25)/1000000, 2) as coffee_consumers
	FROM cities
),
customers_table
AS
(
	SELECT 
		ci.city_name,
		COUNT(DISTINCT c.customer_id) as unique_cx
	FROM sales as s
	JOIN customers_info as c
	ON c.customer_id = s.customer_id
	JOIN cities as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
)
SELECT 
	customers_table.city_name,
	city_table.coffee_consumers as coffee_consumer_in_millions,
	customers_table.unique_cx
FROM city_table
JOIN 
customers_table
ON city_table.city_name = customers_table.city_name;

-- 6.what are the top 3 selling products in each city based on sales volume
select * from
(select ci.city_name,p.product_name,count(s.sale_id) as total_orders,
DENSE_RANK() OVER(PARTITION BY ci.city_name ORDER BY COUNT(s.sale_id) DESC) as ranking
from sales as s
join products as p
on p.product_id=s.product_id
join customers_info as c
on c.customer_id=s.customer_id
join cities as ci
on ci.city_id=c.city_id
group by 1,2
order by 1,3 desc) as table1
where ranking <=3;

-- 7.How many unique customers are there in the each city who have purchased coffee products

select ci.city_name,count( distinct c.customer_id) as unique_customers
from cities as ci
left join customers_info as c
on ci.city_id=c.city_id
join sales as s
on s.customer_id=c.customer_id
where s.product_id in (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
group by 1
order by 2 desc; 

-- 8.Find each city and their average sale per customer and avg rent per customer
with city_table
as
(select c.city_name,COUNT(distinct s.customer_id) as total_customers,
ROUND(SUM(s.total)/COUNT(distinct s.customer_id)) as avg_sale
from sales as s
join customers_info as ci
on ci.customer_id=s.customer_id
join cities as c
on c.city_id=ci.city_id
group by c.city_name
order by avg_sale desc),
city_rent
as
(select city_name,estimated_rent from cities)
select cr.city_name,cr.estimated_rent,ct.total_customers,ct.avg_sale,
ROUND(cr.estimated_rent/ct.total_customers) as avg_rent
from city_rent as cr 
join city_table as ct
on cr.city_name=ct.city_name
order by 4 desc;

-- 9.Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city
with
monthly_sales
AS
(
	select 
		ci.city_name,
		EXTRACT(MONTH FROM sale_date) as month,
		EXTRACT(YEAR FROM sale_date) as YEAR,
		SUM(s.total) as total_sale
	from sales as s
	join customers_info as c
	on c.customer_id = s.customer_id
	join cities as ci
	on ci.city_id = c.city_id
	group by 1, 2, 3
	order by 1, 3, 2
),
growth_ratio
AS
(
		SELECT
			city_name,
			month,
			year,
			total_sale as cr_month_sale,
			LAG(total_sale, 1) OVER(PARTITION BY city_name ORDER BY year, month) as last_month_sale
		FROM monthly_sales
)

SELECT
	city_name,
	month,
	year,
	cr_month_sale,
	last_month_sale,
	ROUND(
		(cr_month_sale-last_month_sale)/last_month_sale * 100
		, 2
		) as growth_ratio

FROM growth_ratio
WHERE 
	last_month_sale IS NOT NULL;
    
-- 10.Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer 

with city_table
AS
(
	select 
		ci.city_name,
		SUM(s.total) as total_revenue,
		COUNT(DISTINCT s.customer_id) as total_cx,
		ROUND(
				SUM(s.total)/
					COUNT(DISTINCT s.customer_id)
				,2) as avg_sale_pr_cx
		
	from sales as s
	join customers_info as c
	on s.customer_id = c.customer_id
	join cities as ci
	on ci.city_id = c.city_id
	group by 1
	order by 2 DESC
),
city_rent
AS
(
	SELECT 
		city_name, 
		estimated_rent,
		ROUND((population * 0.25)/1000000, 3) as estimated_coffee_consumer_in_millions
	FROM cities
)
SELECT 
	cr.city_name,
	total_revenue,
	cr.estimated_rent as total_rent,
	ct.total_cx,
	estimated_coffee_consumer_in_millions,
	ct.avg_sale_pr_cx,
	ROUND(
		cr.estimated_rent/ct.total_cx
		, 2) as avg_rent_per_cx
FROM city_rent as cr
JOIN city_table as ct
ON cr.city_name = ct.city_name
ORDER BY 2 DESC;


/*
-- Recomendation
City 1: Pune
	1.Average rent per customer is very low.
	2.Highest total revenue.
	3.Average sales per customer is also high.

City 2: Delhi
	1.Highest estimated coffee consumers at 7.7 million.
	2.Highest total number of customers, which is 68.
	3.Average rent per customer is 330 (still under 500).

City 3: Jaipur
	1.Highest number of customers, which is 69.
	2.Average rent per customer is very low at 156.
	3.Average sales per customer is better at 11.6k.