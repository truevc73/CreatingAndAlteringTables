use MetroAlt

--1) Create a temp table to show how many stops each route has. the table should have fields
--for the route number and the number of stops. Insert into it from BusRouteStops and
--then select from the temp table.
Create Table #TempStops --has # in front, this denotes a local, session-specific temp table
(
	BusRouteNumber int,
	BusStopNumber int
)
Insert into #TempStops(BusRouteNumber, BusStopNumber)
Select BusRouteKey, BusStopKey from BusRouteStops
Select * from #TempStops

--2) Do the same but using a global temp table.
Create Table ##TempStopsGlobal --Double ## and an End 
(
	BusRouteNumber int,
	BusStopNumber int
)
Select * from ##TempStopsGlobal

--3) Create a function to create an employee email address. Every employee Email follows
-- the pattern of "firstName.lastName@metroalt.com"
Go
Create function fx_Email
(@firstName nvarchar(255), @lastName nvarchar(255))--also I can use int
returns nvarchar(255)
As
Begin
Declare @Email as nvarchar(255)
Set @Email = @firstName + '.' + @lastName + '@metroalt.com'
Return @Email
End
Go
Select EmployeeKey, dbo.fx_Email(EmployeeFirstName, EmployeeLastName) as Email from Employee
Order by EmployeeKey

--4) Create a function to determine a two week pay check of an individual employee.
Go
Create function fx_TwoWeekPay    --this is marked 'alter' because I had to alter the 
(@EmployeePayRate decimal(7,2)) --data type a couple of times to avoid overrunning the 
returns decimal(7,2)            --data type that I had originally declared
As
Begin
Declare @TwoWeekPay as decimal(7,2)
Set @TwoWeekPay = @EmployeePayRate * 80
Return @TwoWeekPay
End
Go

Select EmployeeKey, dbo.fx_TwoWeekPay(EmployeeHourlyPayRate) as EveryTwoWeeks from EmployeePosition
Order by EveryTwoWeeks DESC

--5) Create a function to determine a hourly rate for a new employee. Take difference
-- between top and bottom pay for the new employees position (say driver) and then 
--subtract the difference from the maximum pay. (and yes this is very arbitrary).
Go
Create function fx_NewEmployeePayRate
(@PositionKey int, @EmployeeHourlyPayRateMax decimal(5,2), 
@EmployeeHourlyPayRateMin decimal(5,2))
returns decimal(5,2)
As
Begin
Declare @NewEmployeePayRate decimal(5,2)
Set @NewEmployeePayRate = @EmployeeHourlyPayRateMax - (@EmployeeHourlyPayRateMax-@EmployeeHourlyPayRateMin)
Return @NewEmployeePayRate
End
Go

Select dbo.fx_NewEmployeePayRate(PositionKey, max(EmployeeHourlyPayRate), 
min(EmployeeHourlyPayRate)) as NewEmployeeHourlyPay from EmployeePosition
Where PositionKey = 9
Group by PositionKey

--6) Create a stored procedure to enter a new employee, position and pay rate which
-- uses the functions to create an email address and the one to determine initial pay.
-- Use the stored procedure to add a new employee.
--Create a stored procedure that allows an employee to edit their own information name,
--address, city, zip, not email etc.  The employee key should be one of its parameters.
--Use the procedure to alter one of the employees information
Go
alter proc usp_NewPerson
@EmployeeLastName nvarchar(255), 
@EmployeeFirstName nvarchar(255), 
@EmployeeAddress nvarchar(255), 
@EmployeeCity nvarchar(255), 
@EmployeeZipCode nchar(5), 
@EmployeePhone nchar(10),
@PositionKey int

As
Begin tran
begin try

if exists
(Select EmployeeLastName, EmployeeFirstname from Employee
Where EmployeeLastName=@EmployeeLastName and EmployeeFirstName=@EmployeeFirstName)
Begin
Print 'Already registered'
Return
End

insert into Employee (
EmployeeLastName, 
EmployeeFirstName, 
EmployeeAddress, 
EmployeeCity, 
EmployeeZipCode, 
EmployeePhone,
EmployeeEmail,  
EmployeeHireDate)
values (
@EmployeeLastName, 
@EmployeeFirstName, 
@EmployeeAddress, 
@EmployeeCity, 
@EmployeeZipCode, 
@EmployeePhone,
dbo.fx_Email(@EmployeeFirstName, @EmployeeLastName),  
getdate())

--declare @email nvarchar(255)= dbo.fx_Email(@EmployeeFirstName, @EmployeeLastName)
declare @key int = ident_current('Employee')
declare @max decimal(5,2)
set @max = (select max(EmployeeHourlyPayRate) from EmployeePosition)
declare @min decimal(5,2)
set @min = (select min(EmployeeHourlyPayRate) from EmployeePosition)

insert into EmployeePosition (
EmployeeKey, 
PositionKey, 
EmployeeHourlyPayRate, 
EmployeePositionDateAssigned)
values (
@key,
@PositionKey,
dbo.fx_NewEmployeePayRate(@PositionKey, @max, @min),
getdate())

Commit Tran --commit the transaction if no error ( no Go EndCatch )
End Try
Begin Catch
Rollback Tran
Print Error_Message()
End Catch

exec usp_NewPerson
@EmployeeLastName = 'Kong', 
@EmployeeFirstName = 'King', 
@EmployeeAddress = '123 Jungle Street', 
@EmployeeCity = 'Seattle', 
@EmployeeZipCode = '98102', 
@EmployeePhone = '5554446666',
@PositionKey = '3'
select * from Employee

--Cont

Go
create proc usp_EditPerson
@EmployeeKey int, 
@EmployeeLastName nvarchar(255), 
@EmployeeFirstName nvarchar(255), 
@EmployeeAddress nvarchar(255), 
@EmployeeCity nvarchar(255), 
@EmployeeZipCode nchar(5), 
@EmployeePhone nchar(10)
As
Begin Tran
Begin try
Update Employee
	Set EmployeeLastName = @EmployeeLastName,
		EmployeeFirstName = @EmployeeFirstName,
		EmployeeAddress = @EmployeeAddress,
		EmployeeCity = @EmployeeCity,
		EmployeeZipCode = @EmployeeZipCode
		Where EmployeeKey = @EmployeeKey
Commit Tran
End Try
Begin Catch
Rollback Tran
print error_message()
End Catch

Select * from Employee

exec usp_EditPerson
@EmployeeKey = '503', 
@EmployeeLastName = 'Potato', 
@EmployeeFirstName = 'Dave', 
@EmployeeAddress = '123 City Street', 
@EmployeeCity = 'Bellevue', 
@EmployeeZipCode = '98134', 
@EmployeePhone = '4435546657'



--7) Create a trigger to fire when an employee is assigned to a second shift in a day.
-- Have it write to an overtime table. the Trigger should create the overtime table if 
--it doesn't exist. Add an employee for two shifts to test the trigger.