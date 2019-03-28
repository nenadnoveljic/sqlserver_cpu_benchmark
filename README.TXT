INTRODUCTION

These are the scripts for performing a CPU benchmark on a SQL Server database.

PREPARATION

The procedure sp_cpu_loop executes a simple loop. Therefore, you have to first execute the script create_sp_cpu_loop.sql before proceeding with the tests.

SINGLE TEST

Typically, you would use Invoke-Load for executing a single test, like:

Invoke-Load -Server Server\Instance -Concurrency 3

TEST SERIES

But what's more interesting is to run a series of tests with a random load:

Invoke-Random-Load -Server Server\Instance -MaxConcurrency 6 -iterations 1000 *> random_load.log

The command above runs 1000 tests with a random concurrency ranging from 1 to 6.

ANALYSIS

Then, you can run Show-Statistics for doing the analysis:

Show-Statistics -File random_load.log

Load AVG Iterations/s AVG SOS waits(%) AVG CV AVG ratio max min MAX Iterations/s Run id 1 MAX SOS waits(%) Run id 2 MAX CV Run id 3 MAX ratio max min Run id 4
---- ---------------- ---------------- ------ ----------------- ---------------- -------- ---------------- -------- ------ -------- ----------------- --------
  12          11255.4             10.8   10.1               1.4            16771     1194             24.2     1617   18.4     2382               1.8     2382
  11            10708              9.7    9.5               1.3            11330      397             12.7     1435   14.9      397               1.6     1435
  10            10204              9.3    8.8               1.3            10466     1969             13.9      136   14.1      136               1.5      136
   9           9751.7              7.4      8               1.3             9993      769             15.9      329   15.5      329               1.7      369
   8           9316.3              5.9    7.4               1.2            12749     1191             17.9     1560   16.7     1787               1.7     2073
   7           8818.8              3.9    6.6               1.2             9215     1361             21.9     1361   21.1     1361               1.7     1361
   6           8310.4              0.3      5               1.2             8833     1487             24.3     1432   15.9     1432               1.4     1432
   5           7678.8              0.1    4.1               1.1             7928      482              0.1      887   10.4     1788               1.3     1788
   4           6783.8              0.1    3.9               1.1             7127       97              0.5     2181   12.9      543               1.3      875
   3           5523.7              0.1    3.2               1.1             6035     1836              0.1     1808   16.8     2015               1.5     2015
   2           4803.3              0.1    0.4                 1             5066     2186              0.2     1711    1.7      317                 1      317
   1           3421.7              0.1      0                 1             3519      937              0.4     1853      0     2398                 1     2398

Calculated metrics are:

- "Iterations/s": average loop iterations per second
- "SOS waits(%)": SCHEDULER_OS_YIELD wait time overhead in %
- "CV": Coefficient of variation of the elapsed times od each session in a 
  single run
- "ratio max min": max(elapsed time)/min(elapsed time) in a single run
- "Average": average elapsed time per execution in a single run

All of the metrics are calculated for a given load, where the load corresponds to the number of the concurrent sessions. For each metric an average and a maximum value are calculated per load. The column right from the maximum value contains the run id, which gives you a reference for zooming into the outliers in the log file.

All of the metrics will be displayed by default. However, the scope can be limited by the Metric parameter:

Show-Statistics -File random_load.log -Metric "CV","SOS waits(%)"

CASES STUDIES
- Microsoft Azure CPU Performance: https://nenadnoveljic.com/blog/microsoft-azure-sql-server-cpu-performance/
- SOS_SCHEDULER_YIELD waits: https://nenadnoveljic.com/blog/sos_scheduler_yield-waits-during-low-cpu-utilization/
