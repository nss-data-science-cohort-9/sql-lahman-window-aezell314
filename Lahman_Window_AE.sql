/* 1a. Write a query which retrieves each teamid and number of wins (w) for the 2016 season. 

Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. 

Compare the output from these three functions. What do you notice? */

select teamid, w as wins, ROW_NUMBER() OVER(win), RANK() OVER(win), dense_rank() OVER(win)
from teams t 
where yearid = 2016
window win AS (ORDER BY w desc);
-- Row number does not take into account ties; rank gives the same rank to tied values but then skips the next rank, dense rank gives the same rank to tied values and does not skip the next rank


/* 1b. Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? 

A team's division is indicated by the divid column in the teams table. */

with divrank as (
	select teamid, name, yearid, divid, w as wins, rank() OVER(partition by yearid, divid order by w)
	from teams t
	where divid is not null)
select name, divid, count(*)
from divrank 
where rank = 1
group by teamid, name, divid
order by count(*) desc;
-- The San Diego Padres finished last in their division the most times (10 times).

/* 2a. Barry Bonds has the record for the highest career home runs, with 762. 

Write a query which returns, for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. 

(Barry Bonds' playerid is bondsba01.) */

select playerid, yearid, sum(hr) as homeruns, ROW_NUMBER() OVER(win) as seasons_played, sum(sum(hr)) OVER(win) as career_hr
from batting b
where playerid = 'bondsba01'
group by yearid, playerid
window win AS (ORDER BY yearid);

/* 2b. How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? 

For this question, we will consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of seasons into his career.
*/

with bondsstats as (
	select playerid, yearid, sum(hr) as homeruns, ROW_NUMBER() OVER(win) as seasons_played, sum(sum(hr)) OVER(win) as bonds_career_hr
	from batting b
	where playerid = 'bondsba01'
	group by yearid, playerid
	window win AS (ORDER BY yearid)),
allplayerstats as (
	select playerid, yearid, ROW_NUMBER() OVER(win) as seasons_played, sum(sum(hr)) OVER(win) as career_hr
	from batting b
	group by yearid, playerid
	window win AS (partition by playerid ORDER BY yearid)
)
select count(*)
from bondsstats
inner join allplayerstats
on bondsstats.seasons_played = allplayerstats.seasons_played
and bondsstats.bonds_career_hr < allplayerstats.career_hr
where allplayerstats.yearid = 2016;

--In 2016, there were 20 players on track to beat Barry Bonds' record.

/*
2c. Were there any players who 20 years into their career who had hit more home runs at that point into their career than Barry Bonds had hit 20 years into his career?
*/

with bondsstats as (
	select playerid, yearid, ROW_NUMBER() OVER(win) as seasons_played, sum(sum(hr)) OVER(win) as bonds_career_hr, p.namelast || ' ' || p.namefirst as name
	from batting b
	inner join people p
	using(playerid)
	where playerid = 'bondsba01'
	group by yearid, playerid, name
	window win AS (ORDER BY yearid)),
allplayerstats as (
	select playerid, yearid, ROW_NUMBER() OVER(win) as seasons_played, sum(sum(hr)) OVER(win) as career_hr, p.namelast || ' ' || p.namefirst as name
	from batting b
	inner join people p
	using(playerid)
	group by yearid, playerid, name
	window win AS (partition by playerid ORDER BY yearid)
)
select 
	bondsstats.bonds_career_hr, 
	allplayerstats.playerid,
	allplayerstats.yearid,
	allplayerstats.seasons_played,
	allplayerstats.career_hr,
	allplayerstats.name
from bondsstats
inner join allplayerstats
on bondsstats.seasons_played = allplayerstats.seasons_played
and bondsstats.bonds_career_hr < allplayerstats.career_hr
where bondsstats.seasons_played = 20;

--Aaron Hank had more career home runs 20 seasons into his career (713) than Barry Bonds had 20 years into his career (708).

