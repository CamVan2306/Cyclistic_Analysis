create database cyclistic_db
go
use cyclistic_db
go

select top 10 *
from Trips

-- Q1. What was the total number of trips taken by both Member and Casual groups last year?
select member_casual, count(ride_id) as total_rides, 
	round((count(ride_id)*100.0 / sum(count(ride_id)) over()),2) as percentage_share
from trips
group by member_casual

--.Q2. Average cycling time between the two groups
select member_casual, avg(ride_length_minutes) as average_ride
from trips
group by member_casual

-- Q3. How did the number of trips and average duration vary from Monday to Sunday between the two groups?
select member_casual, day_of_week, count(ride_id) as total_rides,
	round(avg(ride_length_minutes),2) as average_rides
from trips
group by member_casual, day_of_week
order by member_casual asc, total_rides desc

-- Q4. How is the number of trips allocated over 12 months for the Casual and Member groups?
select member_casual, month, count(ride_id) as total_trips
from trips
group by member_casual, month
order by member_casual asc, month asc

-- Q5. What are the top 10 most popular start stations (start_station_names) specifically for the Casual category?
select top 10 start_station_name, count(ride_id) as total_trips
from trips
where member_casual='casual'
group by start_station_name
order by total_trips desc

-- Q6. What are the peak hours for Casual guests on weekends? What are the peak hours for Member guests on weekdays?
with Hourly_Counts AS (
    select
        case 
            when member_casual = 'casual' and day_of_week in ('Saturday', 'Sunday') then 'Casual (Weekend)'
            when member_casual = 'member' and day_of_week not in ('Saturday', 'Sunday') then 'Member (Weekday)'
            else 'Other'
        end as target_group,
        hour as hour_of_day,
        count(ride_id) as total_rides
    from trips
	group by 
        case 
            when member_casual = 'casual' and day_of_week in ('Saturday', 'Sunday') then 'Casual (Weekend)'
            when member_casual = 'member' and day_of_week not in ('Saturday', 'Sunday') then 'Member (Weekday)'
            else 'Other'
        end, hour
),
Ranked_Hours as (
    select *,
        row_number() over(partition by target_group order by total_rides desc) as rank
    from Hourly_Counts
    where target_group != 'Other'
)

select target_group, hour_of_day as peak_hour, total_rides 
from Ranked_Hours 
where rank = 1

-- Q7. Top 5 routes (from Station A to Station B) most frequently taken by the Casual group?
select top 5 concat(start_station_name ,' to ', end_station_name) as route_name, 
	count(ride_id) as total_trips
from trips
where member_casual='casual' and start_station_name is not null
	and end_station_name is not null
group by concat(start_station_name ,' to ', end_station_name)
order by total_trips desc

--Q8. What percentage increase in the number of trips for the Casual group changes from spring (March) to summer (June) each month?
with Monthly_Rides as (
	select month, count(ride_id) as current_month_rides
	from trips
	where member_casual = 'casual' and month in (3,4,5,6)
	group by month
),
Growth_Calc as (
	select month, current_month_rides,
		lag(current_month_rides,1) over(order by month asc) as prev_month_rides
	from Monthly_Rides
)

select month, current_month_rides, prev_month_rides,
	round((current_month_rides-prev_month_rides)*100.0/prev_month_rides,2) as growth_rate_percentage 
from Growth_Calc