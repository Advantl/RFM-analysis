/*
RFM-analysis 

Skills used: CTE's, Temp Tables, Windows Functions, Aggregate Functions, Converting Data Types, Aggregation, Filtering, Subqueries, Conditions.
*/

with rfm_status as (
    select card as customer,
           sum(summ_with_disc) as monetary,
           count(card) as frequency,
           date_trunc('day', max(datetime)) as most_recent_customer_order_date,
           (select date_trunc('day', max(datetime)+interval '1' day) as last_order_date
            from bonuscheques
            order by 1 desc
            limit 1) as most_recent_order_date
    from bonuscheques
    where length(card) = 13
    group by card
),
rfm as (
    select
        customer,
        monetary,
        frequency,
        most_recent_customer_order_date,
        most_recent_order_date,
        date_part('day', most_recent_order_date - most_recent_customer_order_date) as recency
    from rfm_status
    where frequency <= 13
),
bounds as (
    select
        percentile_cont(0.25) within group (order by recency) as r25,
        percentile_cont(0.75) within group (order by recency) as r75,
        percentile_cont(0.25) within group (order by frequency) as f25,
        percentile_cont(0.75) within group (order by frequency) as f75,
        percentile_cont(0.25) within group (order by monetary) as m25,
        percentile_cont(0.75) within group (order by monetary) as m75
    from rfm
),
rfm_calculation_ntile as (
    select r.*,
           case 
                when r.recency <= b.r25 then 3
                when r.recency > b.r25 and r.recency <= b.r75 then 2
                else 1
           end as rfm_recency,
           case 
                when r.frequency = 1 then 1
                when r.frequency between 2 and 3 then 2
                else 3
           end as rfm_frequency,
           case 
                when r.monetary <= b.m25 then 1
                when r.monetary > b.m25 and r.monetary <= b.m75 then 2
                else 3
           end as rfm_monetary
    from rfm r
    cross join bounds b
),
rfm_value_points as (
    select
        rcn.*,
        (rcn.rfm_recency + rcn.rfm_frequency + rcn.rfm_monetary) as rfm_value,
        cast(rcn.rfm_recency as varchar) || cast(rcn.rfm_frequency as varchar) || cast(rcn.rfm_monetary as varchar) as rfm_points
    from rfm_calculation_ntile as rcn
),
rfm_customer_categories as (
    select
        rfmm.customer as customer_card,
        rfmm.rfm_points,
        case
            when rfmm.rfm_points in ('333', '233') then 'Champions'
            when rfmm.rfm_points in ('332', '331', '223', '323') then 'Loyal'
            when rfmm.rfm_points in ('322', '232', '231') then 'Potential Loyalist'
            when rfmm.rfm_points in ('311', '211') then 'New Customers'
            when rfmm.rfm_points in ('221', '321', '313', '312', '222', '213', '212') then 'Promising'
            when rfmm.rfm_points in ('131', '122', '121') then 'At Risk'
            when rfmm.rfm_points in ('133', '132', '113', '123') then 'Cannot Lose Them'
            when rfmm.rfm_points in ('112', '111') then 'Hibernating Customers'
        end as rfm_categories
    from rfm_value_points as rfmm
)
select *
from rfm_customer_categories
order by customer_card desc;
