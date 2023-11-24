-- We have 3 db with different type of information about coffee oredrs
--sourse of data: https://www.kaggle.com/datasets/saadharoon27/coffee-bean-sales-raw-dataset 

select *
from customers

select *
from orders

select *
from products


--Let's join our tables and create 1 temp table for our future work
drop table if exists full_data_tb
select cus.[Customer ID], cus.[Customer Name], cus.Email, cus.[Phone Number], cus.[Address Line 1] as Address, cus.City, cus.Country, cus.[Loyalty Card],
       ord.[Order ID], ord.[Order Date], ord.[Product ID], ord.Quantity,
	   prod.[Coffee Type], prod.[Roast Type], prod.Size, prod.[Unit Price], prod.[Price per 100g], prod.Profit
	   into full_data_tb
from customers as cus
join orders as ord on cus.[Customer ID] = ord.[Customer ID]
join products as prod on ord.[Product ID] = prod.[Product ID]


-- check the data table 
select *
from full_data_tb
order by [Customer Name]


----------------------------------------------------------------------------------------------- \\ Loyalty card \\

---- Let's see how many customers have loyalty card 

select distinct([Loyalty Card]) , count([Loyalty Card]) as count
from full_data_tb
group by [Loyalty Card]
order by count desc
-- as we can see most of our customers don't have loyalty card 
--so maybe we should review the policy regarding these cards - make them more tempting for customers


---- Let's see is it really important to have a loyalty card. Maybe we have much more profit from customers without them.
select [Loyalty Card] , convert(decimal(15,2), sum([Price per 100g] * Size * Quantity)) as profit_per_customer
from full_data_tb
group by [Loyalty Card]
order by profit_per_customer desc 
-- as we can see difference between these 2 groups not that big
-- plus we already see that we have more customers without card


---- Let's take a look for our top 5 customers (by profit per customer)
select top 5 [Customer Name], [Loyalty Card] ,convert( decimal(15,2), sum([Price per 100g] * Size * Quantity)) as profit_per_customer
from full_data_tb
group by [Customer Name], [Loyalty Card]
order by profit_per_customer desc 
-- 4 of them don't have loyalty card

--actually in most cases, the presence of such cards allows clients to feel like “part of a closed club”
--so let's see how we can attract the attention of customers with the greatest profit to our cards


---- Let's take a look for our top 5 customers without loyalty card 

drop table if exists #top_5_customers_no_card
create table #top_5_customers_no_card 
(Customer_Name nvarchar(255),
profit_per_customer float)

insert into #top_5_customers_no_card
select top 5 [Customer Name], convert( decimal(15,2), sum([Price per 100g] * Size * Quantity)) as profit_per_customer
from full_data_tb
where [Loyalty Card] = 'No'
group by [Customer Name]
order by profit_per_customer desc

select *
from #top_5_customers_no_card


-- Let's find out witch products they like

drop table if exists #fav_products_top_5_cust
create table #fav_products_top_5_cust 
(Customer_Name nvarchar(255),
ProductID nvarchar(255),
Coffee_Type nvarchar(255),
Roast_Type nvarchar(255),
Profit float)

insert into #fav_products_top_5_cust
select [Customer Name], [Product ID], [Coffee Type], [Roast Type], Profit
from full_data_tb
where full_data_tb.[Customer Name] in (select #top_5_customers_no_card.Customer_Name
                                       from #top_5_customers_no_card) 
order by [Customer Name]

select *
from #fav_products_top_5_cust


-- It will be very generous to allocate only the most profitable clients
--so we can look at the most profitable products that they love and make a special price for these products only with our loyalty card
select *
from #fav_products_top_5_cust as tb
where tb.Profit = (select max(Profit) 
                  from #fav_products_top_5_cust as tb1
				  where tb1.Customer_Name = tb.Customer_Name)
order by Customer_Name

-- now we have most profitable Product ID
--this will give us more customers with our cards
--plus, people will be glad to receive such attention from the coffee shop :)



----------------------------------------------------------------------------------------------- \\ Countries \\

--Let's find out which countries are more profitable 
select Country, convert(decimal(15,2), sum([Price per 100g] * Size * Quantity)) as profit_countries
from full_data_tb
group by Country
-- as we can see huge part of our customers are in US



----------------------------------------------------------------------------------------------- \\ Null customers data \\

--let's find customers with unknown phone and email 

select [Customer ID], [Customer Name], Email, [Phone Number], [Order Date]
from full_data_tb
Where Email is null and [Phone Number] is null 
order by [Order Date]
--based on order date we can't say for sure they're 'new' or 'old' clients

--Let's update our table

alter table full_data_tb
add Customer_Status as (case when Email is null and [Phone Number] is null then 'Need to find out'
                             when Email is null or [Phone Number] is null then 'Need to write / call'
							 else 'Full info'
							 end);

select [Customer ID], [Customer Name], Email, [Phone Number], [Order Date], Customer_Status
from full_data_tb

--Now we can simply determine which clients have missing information and add what is missing



----------------------------------------------------------------------------------------------- \\ Top product of the year \\

-- add year column
alter table full_data_tb
add Order_year as year([Order Date])

select *
from full_data_tb

alter table full_data_tb
add product_revenue as [Unit Price] * Quantity

select *
from full_data_tb


select distinct dt.Order_year, dt.[Product ID], dt.product_revenue
from full_data_tb as dt
join (select Order_year as y,
      max(product_revenue) as mpr
	  from full_data_tb
	  group by Order_year) as ym
on Order_year = y
and product_revenue = mpr
order by Order_year asc

--as we can see Product with ID E-L-2.5 is the most profitable in 2019 and 2022 

--let's find out what this product is
select distinct [Product ID], [Coffee Type], [Roast Type],[Unit Price]
from full_data_tb
where [Product ID] = 'E-L-2.5' and Order_year = '2022'
-- so now we new that it's Excelsa coffee 