------------------------------------------------------------KPI Queries - 5 queries từ Mart------------------------------------------------------------
--KPI 1:
select month_num,sum(net_amount)as revenu_month from mart.dim_date
join mart.fact_sales using (date_key)
group by month_num 
order by month_num asc

--KPI 2:
select category_name , sum(net_amount) as revenu_category from mart.dim_product dp 
join mart.fact_sales t using (product_sk)
group by 
category_name
order by 
revenu_category desc

--KPI 3:
select dp.product_id ,product_name, sum(net_amount) as revenu_product from mart.dim_product dp 
join mart.fact_sales t using(product_sk)
group by
dp.product_name ,
dp.product_id 
order by 
revenu_product desc
limit 10;

--KPI 4:
select (sum(net_amount) / count(distinct order_id)) as AOV from mart.fact_sales t 

--KPI 5:
select segment, count(distinct customer_id) as number_customer from mart.dim_customer dc 
join fact_sales t using (customer_sk)
group by
dc.segment 
order by 
number_customer  desc
