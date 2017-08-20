Panko
======
:fried_shrimp: Panko uses SQL callbacks to add change log functionality to [FlywayDB](https://flywaydb.org/)

## Usage 
For your specific RDBMS, move the contents of the sql folder into wherever you have configured FlyWay to look for migration scripts. Configure the variables at the top of each script to fit your naming conventions and when you run your next migration you'll have a change tracking table available. 

The changes will be grouped by each run of the `migrate` command, so if you have more than one migration script available and do not specify a target, all of the changes will be grouped together in the change log. If you want each script to have its own change log entries, then use the `target=` parameter to limit each migration to one script at a time.

## Version 
* Version 0.1

## Tests
Currently works with 
* SQL Server 2016 
* Azure SQL 12


## Contact
#### John M
* Blog: [TheLowlyDBA](http://thelowlydba.blogspot.com/)
* [Stack Overflow Profile](http://dba.stackexchange.com/users/45616/john-m?tab=profile)
