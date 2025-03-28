USE USER_ACTIVITY;
SELECT * FROM NEW_USERS;
SELECT * FROM NEW_LOGINS;
SELECT COUNT(DISTINCT USER_ID) FROM NEW_LOGINS;

select * from NEW_USERS U JOIN NEW_LOGINS L ON U.USER_ID = L.USER_ID ;


-- -----1. Which users did not log in during the past 5 months?---

select 
	u.USER_ID
    , max(l.LOGIN_TIMESTAMP) latest_login
from User_activity.NEW_USERS u join User_activity.NEW_LOGINS l on u.USER_ID = l.USER_ID
group by u.USER_ID
having max(l.LOGIN_TIMESTAMP) < current_timestamp() - Interval 5 Month
ORDER BY LATEST_LOGIN DESC
;

SELECT current_timestamp() - Interval 5 Month;
-- 22024-10-05 17:56:02

-- 2.How many users and sessions were there in each quarter, ordered from newest to oldest? --

select 
  concat(year(LOGIN_TIMESTAMP), ' Q' ,quarter(login_timestamp)) year_q
  , makedate(year(LOGIN_TIMESTAMP),1) + interval (quarter(login_timestamp) -1) * 3 month as quat_1st_day
  , count(distinct USER_ID) users
  , count(SESSION_ID) sessions
from User_activity.NEW_LOGINS
group by 
concat(year(LOGIN_TIMESTAMP), ' Q' ,quarter(login_timestamp))
, makedate(year(LOGIN_TIMESTAMP),1) + interval (quarter(login_timestamp) -1) * 3 month
order by quat_1st_day desc;


-- 3. Which users logged in during January 2024 but did not log in during November 2023? --

select 
distinct
 user_id
from User_activity.NEW_LOGINS
where year(LOGIN_TIMESTAMP) = 2024
	 and month(LOGIN_TIMESTAMP) = 01
     and user_id 
not in ( 
select 
 user_id
from User_activity.NEW_LOGINS
where year(LOGIN_TIMESTAMP) = 2023
	 and month(LOGIN_TIMESTAMP) = 11 );
     
-- OR 

select 
 distinct l1.user_id
from User_activity.NEW_LOGINS l1 Left join User_activity.NEW_LOGINS l2 
on l1.user_id = l2.user_id 
and year(l2.LOGIN_TIMESTAMP) = 2023 and month(l2.LOGIN_TIMESTAMP) = 11
where l2.user_id is null and year(l1.LOGIN_TIMESTAMP) = 2024 and month(l1.LOGIN_TIMESTAMP) = 01 ;

-- 4. What is the percentage change in sessions from the last quarter?

with quat_sessions as 
(
 select 
  -- concat(year(LOGIN_TIMESTAMP), ' Q' ,quarter(login_timestamp)) year_q
   makedate(year(LOGIN_TIMESTAMP),1) + interval (quarter(login_timestamp) -1) * 3 month as quat_1st_day
  -- , count(distinct USER_ID) users
  , count(SESSION_ID) sessions
from User_activity.NEW_LOGINS
group by 
-- concat(year(LOGIN_TIMESTAMP), ' Q' ,quarter(login_timestamp))
 makedate(year(LOGIN_TIMESTAMP),1) + interval (quarter(login_timestamp) -1) * 3 month
)
, prev_quat_sessions
as (
select 
 quat_1st_day
 ,sessions
 , lag(quat_1st_day ,1) over (order by quat_1st_day) prev_quat
 , lag(sessions ,1) over (order by quat_1st_day) prev_sessions
 from quat_sessions
 )
 
 select 
 quat_1st_day
 , sessions
 , prev_sessions 
 , (sessions - prev_sessions) * 100 / prev_sessions session_pct_change
 from prev_quat_sessions
 ;
 
 -- 5. Which user had the highest session score each day?
 
 select 
 date(login_timestamp) login_date
 , USER_ID
 , MAX(SESSION_SCORE) OVER (PARTITION BY date(login_timestamp)) MAX_SCORE
 from User_activity.NEW_LOGINS ;
 
 
 -- 6. Which users have had a session every single day since their first login? 
 

 select 
 USER_ID
 ,MAX(DATE(LOGIN_TIMESTAMP))
 ,MIN(DATE(LOGIN_TIMESTAMP))
 ,COUNT(DISTINCT DATE(LOGIN_TIMESTAMP)) 
 from User_activity.NEW_LOGINS
 GROUP BY USER_ID	
 HAVING COUNT(DISTINCT DATE(LOGIN_TIMESTAMP)) = DATEDIFF(MAX(DATE(LOGIN_TIMESTAMP)) ,MIN(DATE(LOGIN_TIMESTAMP))) + 1 ;

-- 7. On what dates were there no logins at all?

WITH RECURSIVE CALENDAR AS 
(
SELECT 
 MIN(DATE(LOGIN_TIMESTAMP)) FIRST_DAY
 ,MAX(DATE(LOGIN_TIMESTAMP)) LAST_DAY
 from User_activity.NEW_LOGINS
 
 UNION ALL 
 
 SELECT 
FIRST_DAY +  INTERVAL 1 DAY FIRST_DAY
 , LAST_DAY
 from CALENDAR
 WHERE FIRST_DAY < LAST_DAY
)
 SELECT FIRST_DAY FROM CALENDAR 
 WHERE FIRST_DAY NOT IN 
 (
 SELECT DATE(LOGIN_TIMESTAMP) FROM User_activity.NEW_LOGINS
 )
 ;
 
 -- 8. HOW MANY MONTHLY ACTIVE USERS TILL LAST MONTH?
 
 SELECT 
 CONCAT(YEAR(L.LOGIN_TIMESTAMP) ,'-' , MONTH(L.LOGIN_TIMESTAMP) ) MONTHS
 ,COUNT(DISTINCT L.USER_ID) MONTHLY_ACTIVE_USERS
 FROM User_activity.NEW_LOGINS L LEFT JOIN User_activity.NEW_USERS U ON L.USER_ID = U.USER_ID
 WHERE U.USER_STATUS = 'Active' 
 AND MONTH(L.LOGIN_TIMESTAMP) != MONTH(current_date())
 GROUP BY  CONCAT(YEAR(L.LOGIN_TIMESTAMP) ,'-' , MONTH(L.LOGIN_TIMESTAMP) )
 ORDER BY MONTHS DESC;
 
 -- OR DAILY ACTIVE USERS
 
 SELECT 
 DATE(L.LOGIN_TIMESTAMP)  DAY
 ,COUNT(DISTINCT L.USER_ID) MONTHLY_ACTIVE_USERS
 FROM User_activity.NEW_LOGINS L LEFT JOIN User_activity.NEW_USERS U ON L.USER_ID = U.USER_ID
 WHERE U.USER_STATUS = 'Active' 
 AND MONTH(L.LOGIN_TIMESTAMP) != MONTH(current_date())
 GROUP BY   DATE(L.LOGIN_TIMESTAMP) 
 ORDER BY DAY DESC;
 
 -- 9. HOW MANY LOGINS EACH USER DID OVER THE TIME 
 
  SELECT 
	  U.USER_ID
	 ,U.USER_NAME
	 ,COUNT(L.SESSION_ID) NUM_OF_SESSIONS
 FROM User_activity.NEW_LOGINS L LEFT JOIN User_activity.NEW_USERS U ON L.USER_ID = U.USER_ID
 GROUP BY U.USER_ID
	 ,U.USER_NAME
 ORDER BY NUM_OF_SESSIONS DESC;
 
 -- 10. IDENTIFIES FIRST TIME USERS AND RETURNING USERS
 
WITH FIRSTLOGIN AS (
    SELECT USER_ID, MIN(DATE(LOGIN_TIMESTAMP)) AS FIRST_LOGIN
    FROM NEW_LOGINS
    GROUP BY USER_ID
)
SELECT 
    DATE(L.LOGIN_TIMESTAMP) AS LOGIN_DATE
    , COUNT(DISTINCT CASE WHEN F.FIRST_LOGIN = DATE(L.LOGIN_TIMESTAMP) THEN L.USER_ID END) AS NEW_USERS
    , COUNT(DISTINCT CASE WHEN F.FIRST_LOGIN < DATE(L.LOGIN_TIMESTAMP) THEN L.USER_ID END) AS RETURNING_USERS
FROM NEW_LOGINS L
JOIN FIRSTLOGIN F ON L.USER_ID = F.USER_ID
GROUP BY DATE(L.LOGIN_TIMESTAMP)
ORDER BY DATE(L.LOGIN_TIMESTAMP) DESC;
 