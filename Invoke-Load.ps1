<#

(c) 2019 Nenad Noveljic All Rights Reserved

Usage: Invoke-Load -Concurrency n

Version 2.1

Prerequisites: 
    sp_cpu_loop in the database, configure connect string in Config.psd1

It runs a sp_cpu_loop with n concurrent sessions and measures elapsed time, 
SOS_SCHEDULER_YIELD wait time and CPU time on each scheduler

#>

param (
    [int]$Concurrency = 1
)

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

$parallel = $concurrency

function ExecuteSelect 
{
    param(
        $Connection,
        [string]$Select
    )
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.Connection = $Connection
    $SqlCmd.CommandText = $Select

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter 
    $dataset = New-Object System.Data.DataSet

    $adapter.SelectCommand = $SqlCmd
    $adapter.Fill($dataSet) | Out-Null
    $dataSet.Tables | Format-Table 
}

$ConfigFile = Import-LocalizedData -BaseDirectory . -FileName Config.psd1

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection

#$SqlConnection.ConnectionString = "Server=" + $server + ";Integrated Security=True"
$ConnectString = $ConfigFile.ConnectString
$SqlConnection.ConnectionString = $ConnectString


$SQlConnection.Open()
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.Connection = $SqlConnection

$SqlCmd.CommandText = "drop table if exists os_schedulers_before"
$SqlCmd.ExecuteNonQuery() | Out-Null

$SqlCmd.CommandText = "drop table if exists os_schedulers_after"
$SqlCmd.ExecuteNonQuery() | Out-Null

<#
$SqlCmd.CommandText = "drop table if exists os_waits"
$SqlCmd.ExecuteNonQuery() | Out-Null

$SqlCmd.CommandText = "DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR)"
$SqlCmd.ExecuteNonQuery() | Out-Null
#>

# Snapshot tables instead of CLEAR, because you might not have the provilege 
# to clear, like for example in Azure
$SqlCmd.CommandText = "drop table if exists os_waits_before"
$SqlCmd.ExecuteNonQuery() | Out-Null

$SqlCmd.CommandText = "drop table if exists os_waits_after"
$SqlCmd.ExecuteNonQuery() | Out-Null

$SqlCmd.CommandText = "select * into os_schedulers_before from sys.dm_os_schedulers"
$SqlCmd.ExecuteNonQuery() | Out-Null

$SqlCmd.CommandText = "select * into os_waits_before from sys.dm_os_wait_stats"
$SqlCmd.ExecuteNonQuery() | Out-Null

$LOOP_ITERATIONS = 10000000

For ( $i = 1 ; $i -le $parallel ; $i++ ) {
    $Input = [System.Tuple]::Create($ConnectString, $LOOP_ITERATIONS, $i)

    Start-Job -Name "SQL$i" -ArgumentList $Input -ScriptBlock { 
      $args[0] | Measure-Command { 
        #$server = $_.Item1
        $ConnectString = $_.Item1
        
        $LOOP_ITERATIONS = $_.Item2
        $proc_id = $_.Item3
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        
        $SqlConnection.ConnectionString = $ConnectString
        
        $SQlConnection.Open()
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.Connection = $SqlConnection
        $SqlCmd.CommandText = "exec sp_cpu_loop @iterations = " + $LOOP_ITERATIONS

        $SqlCmd.CommandTimeout = 1000
        $SqlCmd.ExecuteNonQuery() | Out-Null
        $SqlConnection.Close()
      } 
    }  | Out-Null
}

$times_arr = @()
Write-Host "Threads: " $PARALLEL
Write-Host "Elapsed times:"
For ( $i = 1 ; $i -le $PARALLEL ; $i++ ) {
    Wait-Job "SQL$i" | Out-Null
    $out = Receive-Job "SQL$i" | findstr -i TotalMilliseconds 
    $time = $out -replace "TotalMilliseconds\s+:\s+(\S+)", '$1'
    Write-Host $time
    $times_arr += $time
    Remove-Job "SQL$i"
} 

$times_arr | Measure-Object -Average -Maximum -Minimum -Sum

$mean = $times_arr | Measure-Object -Average | select -ExpandProperty Average
$sqdiffs = $times_arr | foreach {[math]::Pow(($psitem - $mean), 2)}
$sigma = [math]::Sqrt( ($sqdiffs | Measure-Object -Average | select -ExpandProperty Average) )
$sigma = [math]::Round($sigma, 3)
Write-Host "Standard Deviation:" $sigma

$iterations_per_s = $times_arr | foreach { $LOOP_ITERATIONS / $_ }
$iterations_per_s_total = $iterations_per_s | Measure-Object -Sum | select -ExpandProperty Sum
$iterations_per_s_total = [math]::Round($iterations_per_s_total, 0)
Write-Host "Iterations/s:" $iterations_per_s_total

$SqlCmd.CommandText = "select * into os_waits_after from sys.dm_os_wait_stats"
$SqlCmd.ExecuteNonQuery() | Out-Null

$SqlCmd.CommandText = "select * into os_schedulers_after from sys.dm_os_schedulers"
$SqlCmd.ExecuteNonQuery() | Out-Null

<#
$SqlCmd.CommandText = "select * into os_waits from sys.dm_os_wait_stats"
$SqlCmd.ExecuteNonQuery() | Out-Null
#>

$adapter = New-Object System.Data.sqlclient.sqlDataAdapter 
$dataset = New-Object System.Data.DataSet

<#
$sql_os_waits = 
    "select wait_type, wait_time_ms, 
        signal_wait_time_ms
        from os_waits where wait_type = 'SOS_SCHEDULER_YIELD'"
#>
$sql_os_waits = 
    "select 
            a.wait_type, 
            ( a.wait_time_ms - b.wait_time_ms ) 
                total_wait_time_ms,
		    ( a.signal_wait_time_ms - b.signal_wait_time_ms ) 
                total_signal_wait_time_ms
            from os_waits_after a join os_waits_after b 
                on a.wait_type = b.wait_type
            where a.wait_type = 'SOS_SCHEDULER_YIELD'"
ExecuteSelect -Connection $SqlConnection -Select $sql_os_waits

$sql_os_scheduler =
    "select 
        a.scheduler_id, 
        ( a.total_cpu_usage_ms - b.total_cpu_usage_ms ) 
            total_cpu_usage_ms
        from os_schedulers_after a join os_schedulers_before b 
            on a.scheduler_id = b.scheduler_id 
        where a.status = 'VISIBLE ONLINE'"
ExecuteSelect -Connection $SqlConnection -Select $sql_os_scheduler

$SqlConnection.Close()

