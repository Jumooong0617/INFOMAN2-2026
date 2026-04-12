
### OLTP QUERY PLAN
```sql
EXPLAIN ANALYZE
SELECT
  SUM(p.Price * oi.Quantity) AS TotalRevenue,
  SUM(oi.Quantity) AS TotalItemsSold
FROM OrderItems oi
JOIN Orders o ON oi.OrderID = o.OrderID
JOIN Users u ON o.UserID = u.UserID
JOIN Products p ON oi.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
WHERE c.CategoryName = 'Electronics'
  AND u.Age BETWEEN 18 AND 25
  AND u.City = 'Manila'
  AND o.OrderDate BETWEEN '2025-12-01' AND '2025-12-31';
```
![alt text](images/image1.png)


### OLAP QUERY PLAN
```sql
EXPLAIN ANALYZE
SELECT
  SUM(f.SalesAmount) AS TotalRevenue,
  SUM(f.Quantity) AS TotalItemsSold
FROM Fact_Sales f
JOIN Dim_Date d ON f.DateKey = d.DateKey
JOIN Dim_Location l ON f.LocationKey = l.LocationKey
JOIN Dim_Product p ON f.ProductKey = p.ProductKey
JOIN Dim_Customer c ON f.CustomerKey = c.CustomerKey
WHERE p.CategoryName = 'Electronics'
  AND l.City = 'Manila'
  AND c.AgeGroup = '18-25'
  AND d.Year = 2025
  AND d.MonthName = 'December';
```
![alt text](images/image2.png)