/*
Problem link 
https://leetcode.com/problems/find-customer-referee/description/?envType=study-plan-v2&envId=top-sql-50

Solution link
https://www.youtube.com/watch?v=8XSR6UEqliU&list=PL5TWX8S_wvBPtMyBAjifOT1CfLwQPng86&index=2
*/


/*

Create table If Not Exists Customer (id int, name varchar(25), referee_id int)
Truncate table Customer
insert into Customer (id, name, referee_id) values ('1', 'Will', 'None')
insert into Customer (id, name, referee_id) values ('2', 'Jane', 'None')
insert into Customer (id, name, referee_id) values ('3', 'Alex', '2')
insert into Customer (id, name, referee_id) values ('4', 'Bill', 'None')
insert into Customer (id, name, referee_id) values ('5', 'Zack', '1')
insert into Customer (id, name, referee_id) values ('6', 'Mark', '2')

Input: 
Customer table:
+----+------+------------+
| id | name | referee_id |
+----+------+------------+
| 1  | Will | null       |
| 2  | Jane | null       |
| 3  | Alex | 2          |
| 4  | Bill | null       |
| 5  | Zack | 1          |
| 6  | Mark | 2          |
+----+------+------------+
Output: 
+------+
| name |
+------+
| Will |
| Jane |
| Bill |
| Zack |
+------+

*/


/*
In SQL, id is the primary key column for this table.
Each row of this table indicates the id of a customer, their name, and the id of the customer who referred them.
 

Find the names of the customer that are not referred by the customer with id = 2.
Return the result table in any order.

SQL by default removes null value, so to include null we have added referee_id is null crieria

*/


select name
from Customer
where referee_id != 2 or referee_id is null ;



/* 
There is another approach
we could use the IFNULL method to set the default value if the value is null
*/

select name
from Customer
where IFNULL(referee_id,0) != 2 ;