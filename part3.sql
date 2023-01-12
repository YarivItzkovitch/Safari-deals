-------------part 1----------------

-- query 1
select d.tourtype,[average stars]=AVG(r.numofstars),[average price]=AVG(a.price)
from reviews as r join Deals as d on r.dealURL=d.dealurl join Appears as a on d.dealurl=a.dealURL
where a.price<5001
group by d.tourtype
order by AVG(r.numofstars) desc

--query 2

select c.country, (case when month(e.startdate) in (12, 1, 2) then 'winter'
      when month(e.startdate) in (3, 4, 5) then 'spring'
      when month(e.startdate) in (6, 7, 8) then 'summer'
      when month(e.startdate) in (9, 10, 11) then 'autumn'
 end) as season, [minimum price in season]=min(a.price)
from Enquiries as e join Countries as c on e.dealURL=c.dealurl join Appears a on c.dealurl=a.dealurl
where DATEDIFF(dd,e.startdate,e.endDate)<=14
group by c.country, (case when month(e.startdate) in (12, 1, 2) then 'winter'
      when month(e.startdate) in (3, 4, 5) then 'spring'
      when month(e.startdate) in (6, 7, 8) then 'summer'
      when month(e.startdate) in (9, 10, 11) then 'autumn'
 end)
having min(a.price) < 2500
order by c.country

--query 3 (nested)

select top 5 d.dealurl,  avgnumofstars=avg(r.numofstars), t.tourT,t.avgSTAR
from deals as d join reviews as r on d.dealurl = r.dealurl join (select tourT= d.tourtype, avgSTAR= avg(cast(r.numOfStars as decimal (3,2))) from reviews as r join deals as
d on d.dealUrl = r.dealurl group by d.tourtype) as t on t.tourt = d.tourtype
group by d.dealurl, t.tourt, t.avgstar
having avg(r.numofstars)>t.avgstar
order by avgnumofstars desc

--query 4 (nested)

select Datevalue=CAST(s.searchdt as date),numOfsearches= count(CAST(s.searchdt as date))
from Searches as s
group by CAST(s.searchdt as date)
having count(CAST(s.searchdt as date))>
(select cast(count(*) as decimal (6,2))/count(distinct cast(Searches.searchDT as date))
from Searches)

-- query 5 (union)


select d.dealurl as name,  avgnumofstars=avg(r.numofstars),totalavgforcategory=(select avgSTAR= avg(cast(r.numOfStars as decimal (3,2))) from reviews as r join deals as
d on d.dealUrl = r.dealurl) 
from deals as d join reviews as r on d.dealurl = r.dealurl
group by d.dealurl
having avg(r.numofstars)>(select avgSTAR= avg(cast(r.numOfStars as decimal (3,2))) from reviews as r join deals as
d on d.dealUrl = r.dealurl) 
union
select t.tpName as name,  avgnumofstars=avg(r.numofstars),totalavgforcategory=(select avgSTAR= avg(cast(r.numOfStars as decimal (3,2))) from reviews as r join TravelPartners as
t on t.tpname = r.tpName)
from TravelPartners as t join reviews as r on t.tpName = r.tpName
group by t.tpName
having avg(r.numofstars)>(select avgSTAR= avg(cast(r.numOfStars as decimal (9,2))) from reviews as r join TravelPartners as
t on t.tpname = r.tpName) 
order by avgnumofstars desc

-- query 6 (update)
alter table customers
--drop column numofsearches
add numOfSearches int null

update Customers
set numOfSearches=(select count(*) from Searches where Searches.email=Customers.email)

---------------part 2-----------

-- view
create view V_custSearch as 
select c.Email,[full name]= c.firstName+' '+c.lastName,[search date]=cast(s.searchDT as date) ,s.destination,s.priceRange,s.tripMonth,a.dealURL,d.tpName
from Customers as c join Searches as s on s.email = c.Email join Appears as a on (a.userIP = s.userIP and a.searchDT = s.searchDT) join Deals as d on d.dealURL=a.dealURL
-- view use query
select distinct v.Email, v.[full name]
from V_custSearch as v
where v.priceRange like '%over%'
-- scalar function
CREATE FUNCTION dealInSearches
(
    @dealurl varchar(100),
	@month int,
	@year int
)
RETURNS INT
AS
BEGIN
	declare @DealInSearches int
	select @DealInSearches = count(a.dealURL)
	from Appears as a
	where @dealurl=a.dealURL and MONTH(a.searchDT)= @month and YEAR(a.searchDT)=@year
    RETURN @dealinsearches

END
-- scalar function use query

select d.tpName,d.dealURL,number_of_returns=dbo.dealinsearches(d.dealURL,3,2022)
from Appears as a join deals as d on a.dealURL=d.dealURL
where d.tpName = 'travel usa'
group by tpName,d.dealURL

-- tabular function

CREATE FUNCTION tp_Deal_conversion_rate
(
    @tpname varchar(40)
)
RETURNS TABLE 
AS
return
SELECT tpname=@tpname,e.dealURL,ratio=cast((e.enqcount*1.0)/a.appearCount as decimal(5,3))
from (select dealURL=ee.dealURL,enqcount=count(ee.dealurl) from Enquiries as ee group by ee.dealURL )as e
join (select dealurl=d.dealURL, appearCount=count(d.dealurl) from Appears as d group by d.dealURL) as a on a.dealurl = e.dealURL
	join deals as d on d.dealURL=e.dealURL
	where d.tpName= @tpname

-- tabular function use query
select *
from tp_Deal_conversion_rate('travel usa')
order by ratio desc

--trigger 
create trigger update_Num_of_searches
on searches for insert
As begin
update Customers
set numOfSearches=(select count(*) from Searches where Searches.email=Customers.Email)
where Customers.Email in (select Email from inserted) end
-- trigger use sample
select * from Customers
insert into Searches(userIP,searchDT,tripMonth,priceRange,destination,email) 
	values ('1.242.141.135','3-1-2023',3,'over 10000$','iran','AAO8818@gmail.com'),('1.142.221.135','3-1-2023',3,'over 10000$','iran','AAO8818@gmail.com')

-- SP
CREATE PROCEDURE update_travel_status
    @start_date DATE,
    @end_date DATE
AS
BEGIN
    UPDATE customers
    SET has_traveled = 0

	update Customers
	set has_traveled = 1
    WHERE EXISTS (SELECT 1 FROM Enquiries WHERE Customers.Email = Enquiries.customerEmail AND Enquiries.endDate BETWEEN @start_date AND @end_date)
    AND NOT EXISTS (SELECT 1 FROM reviews WHERE Customers.Email = reviews.email AND reviews.reviewdt BETWEEN @start_date AND @end_date)
END
-- SP run sample
select * from Customers
exec update_travel_status '2021-01-01','2023-01-01'

--------------- part 4 -----------
-- window functions query 1 
select *
from(
select tp.tpname,r.dealurl,r.revenue,rn =rank()over (partition by tp.tpname order by r.revenue desc),rr.totalrev,rr.asiron
from TravelPartners as tp join
(select tpname=d.tpname,dealurl=d.dealurl,revenue=sum(a.price) from deals as d join Appears as a
on d.dealurl=a.dealURL group by d.tpname,d.dealURL) as r 
on  r.tpname=tp.tpname join (select tpname=dd.tpname,totalrev=sum(aa.price)
,asiron=ntile(10) over (order by sum(aa.price) desc)
from Deals as dd join Appears as aa on
dd.dealURL=aa.dealurl group by dd.tpName) as rr on r.tpname=rr.tpname) as total
where total.rn=1
order by total.totalrev desc

-- window functions query 2 

select e.year,e.numofenq,last_year_number=LAG(e.numofenq,1) over (order by e.year asc)
from(
select distinct year=year(startDate), numofenq=count(enquiryid) over (partition by year(startdate))
from Enquiries as e
) as e

-- systematic integration of several unique tools 
	alter table deals 
	add underperforming tinyint null
	select * from Deals
	select * from deal_performance
	drop table deal_performance
	CREATE TABLE deal_performance (
    dealurl varchar(100),
    num_searches int,
    avg_rating float
	)
create procedure update_deal_performance
AS
BEGIN
 
    truncate table deal_performance

    insert into deal_performance (dealurl, num_searches, avg_rating)
    select d.dealurl, num_searches = count(a.dealurl), avg_rating = isnull(dbo.get_avg_rating(d.dealurl),0)
    from deals as d
    left join appears as a ON d.dealurl = a.dealurl
    GROUP BY d.dealurl;
END


CREATE FUNCTION get_avg_rating (
    @dealurl varchar(100)
)
RETURNS float
AS
BEGIN
    DECLARE @avg_rating float;

    select @avg_rating = avg(cast(r.numofstars as float))
    from reviews as r
    where r.dealurl = @dealurl;

    RETURN @avg_rating;
END

create trigger deal_performance_alert
on deal_performance for insert
as begin
update deals
set underperforming = (case when(select avg_rating from deal_performance where deal_performance.dealurl=Deals.dealURL) = 0 then 2
when (select avg_rating from deal_performance where deal_performance.dealurl = deals.dealURL) < 3.5 then 1
else 0 end)
where Deals.dealURL in(select dealURL from inserted)
end

exec update_deal_performance

select * from deal_performance
select * from Deals
