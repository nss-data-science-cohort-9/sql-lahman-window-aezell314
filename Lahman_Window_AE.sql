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
	allplayerstats.name,
	allplayerstats.yearid,
	allplayerstats.seasons_played,
	allplayerstats.career_hr,
	bondsstats.bonds_career_hr
from bondsstats
inner join allplayerstats
on bondsstats.seasons_played = allplayerstats.seasons_played
and bondsstats.bonds_career_hr < allplayerstats.career_hr
where bondsstats.seasons_played = 20;

--Aaron Hank had more career home runs 20 seasons into his career (713) than Barry Bonds had 20 years into his career (708).



/* 3. Find the player who had the most anomalous season in terms of number of home runs hit. 

To do this, find the player who has the largest gap between the number of home runs hit in a season and the 5-year moving average number of 

home runs if we consider the 5-year window centered at that year (the window should include that year, the two years prior and the two years after). */


select p.namefirst || ' ' || p.namelast as name, 
	   yearid, 
	   abs(sum(hr) -
	   avg(sum(hr)) OVER(
						partition by playerid 
						ORDER BY yearid
						ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)) as dev_from_avg
from batting b
inner join people p
using(playerid)
group by yearid, playerid, name
order by dev_from_avg desc;

-- Hank Greenberg had the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs, with a 31.2 point gap in 1936.


-- 4. For this question, we'll just consider players that appear in the batting table.

/* 4a. Warmup: How many players played at least 10 years in the league and played for exactly one team? 

(For this question, exclude any players who played in the 2016 season). 

Who had the longest career with a single team? (You can probably answer this question without needing to use a window function.) */
with players as 
(
-- get players who played at least 10 years in the league and played for a single team
(select distinct playerid
from batting
group by playerid
having max(yearid) - min(yearid) >= 10
and count(distinct teamid) = 1)
except
-- exclude players who played in 2016
(select playerid
from batting 
where yearid = 2016))
select count(*)
from players;
-- There were 141 players who played at least 10 years in the league and played for exactly one team.

with players as 
(
-- get players who played at least 10 years in the league and played for a single team
(select distinct playerid
from batting
group by playerid
having max(yearid) - min(yearid) >= 10
and count(distinct teamid) = 1)
except
-- exclude players who played in 2016
(select playerid
from batting 
where yearid = 2016))
select p.namefirst || ' ' || p.namelast as playername, max(b.yearid) - min(b.yearid) as careerlength, b.teamid
from players pl
inner join batting b
using(playerid)
inner join teams t
using(teamid)
inner join people p
using(playerid)
group by playerid, playername, teamid
order by careerlength desc;
--Ted Lyons had the longest career with a single team, spending 23 years with the Chicago White Sox. 

/* 4b. Some players start and end their careers with the same team but play for other teams in between. 

For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants for 7 seasons before returning to the Oakland Athletics 

for his final season. How many players played at least 10 years in the league and start and end their careers with the same team but played 

for at least one other team during their career? For this question, exclude any players who played in the 2016 season. */


-- first make a new column to capture whether a player started and ended their career with the same team
with start_end_same as 
(
select playerid, 
	case
		when FIRST_VALUE(teamid) over win = LAST_VALUE(teamid) OVER win then 'Y'
		else 'N'
	end as start_end_same_team
from batting
window win as (partition by playerid order by yearid, stint ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
), 
	players as 
(
-- then narrow down to players who played at least 10 years in the league, played for at least 2 different teams, and started/ended with the same team 
(select playerid
from batting b
inner join start_end_same
using(playerid)
where start_end_same_team = 'Y'
group by playerid
having max(yearid) - min(yearid) >= 10
and count(distinct teamid) > 1)
except
-- exclude players who played in 2016 
(select playerid
from batting 
where yearid = 2016))
select count(*)
from players;
-- There were 200 players who played at least 10 years in the league and started and ended their careers with the same team, but played for at least one other team during their career.



-- 5a. How many times did a team win the World Series in consecutive years?
with wins as 
(select teamid, yearid, wswin, lag(wswin) over(partition by teamid order by yearid) as wswin_lastyear
from teams
order by teamid, yearid)
select count(*)
from wins
where wswin = 'Y' and wswin_lastyear = 'Y';
-- There were 22 instances where a team won the World Series in consecutive years


/* 5b. What is the longest streak of a team winning the World Series? 

Write a query that produces this result rather than scanning the output of your previous answer. */

with ws_streaks as
(select teamid, 
		name, 
		yearid, 
		wswin, 
		yearid - row_number() over win as groupid
from teams
where wswin = 'Y'
window win as (partition by teamid order by yearid)
order by teamid, yearid)
select distinct teamid, 
		name,
		first_value(yearid) over win as streak_start,
		last_value(yearid) over win as streak_end,
		count(*) over win as streak_length
from ws_streaks
window win as (partition by teamid, groupid order by yearid ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
order by streak_length desc;

-- The longest streak of a team winning the World Series is the New York Yankees, with a 5 year streak. 


/* 5c. A team made the playoffs in a year if either divwin, wcwin, or lgwin are equal to 'Y'. 

Which team has the longest streak of making the playoffs? */

with ws_streaks as
(select teamid, 
		name, 
		yearid, 
		wswin, 
		yearid - row_number() over win as groupid
from teams
where divwin = 'Y' or wcwin = 'Y' or lgwin = 'Y'
window win as (partition by teamid order by yearid)
order by teamid, yearid)
select distinct teamid, 
		name,
		first_value(yearid) over win as streak_start,
		last_value(yearid) over win as streak_end,
		count(*) over win as streak_length
from ws_streaks
window win as (partition by teamid, groupid order by yearid ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
order by streak_length desc;

-- The New York Yankees also had the longest streak of making the playoffs, with a 13 year streak starting in 1921.


/* 5d. The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, does this change your answer for the previous part? */

-- Adjust query from previous part to concatenate any streaks broken by 1994. self join?



/* 6. Which manager had the most positive effect on a team's winning percentage? 

To determine this, calculate the average winning percentage in the three years before the manager's first full season and compare it to the 

average winning percentage for that manager's 2nd through 4th full season. Consider only managers who managed at least 4 full years at the 

new team and teams that had been in existence for at least 3 years prior to the manager's first full season. */





