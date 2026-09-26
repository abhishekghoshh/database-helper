/*
Problem link 
https://leetcode.com/problems/invalid-tweets/description/?envType=study-plan-v2&envId=top-sql-50

Solution link
https://www.youtube.com/watch?v=0BN2uS1j8jc&list=PL5TWX8S_wvBPtMyBAjifOT1CfLwQPng86&index=5
*/


/*
Create table If Not Exists Tweets(tweet_id int, content varchar(50))
Truncate table Tweets
insert into Tweets (tweet_id, content) values ('1', 'Vote for Biden')
insert into Tweets (tweet_id, content) values ('2', 'Let us make America great again!')

Input: 
Tweets table:
+----------+----------------------------------+
| tweet_id | content                          |
+----------+----------------------------------+
| 1        | Vote for Biden                   |
| 2        | Let us make America great again! |
+----------+----------------------------------+
Output: 
+----------+
| tweet_id |
+----------+
| 2        |
+----------+
Explanation: 
Tweet 1 has length = 14. It is a valid tweet.
Tweet 2 has length = 32. It is an invalid tweet.
+------+
*/

/*
Write a solution to find the IDs of the invalid tweets. The tweet is invalid if the number of characters used in the content of the tweet is strictly greater than 15.

Return the result table in any order.

The result format is in the following example.
*/

select tweet_id
from Tweets
where char_length(content) > 15



/* we can also use length, while char length return the character length but the length return the byte length */
select tweet_id
from Tweets
where length(content) > 15