<# 

(c) 2019 Nenad Noveljic All Rights Reserved

Usage: Show-Statistics -File file [ -Metric ... ]

Version 2.1

Performs analysis of Invoke-Random-Load output file. All of the metrics will 
be displayed by default. However, the scope can be limited by the Metric 
parameter.

#>

param (
   [parameter(Mandatory=$true)][string]$File,
   [string[]]$Metric = @( "Iterations/s" , "SOS waits(%)" , "CV" , ` 
    "ratio max min" , "Average" ) 
)

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

function SetValue1
{
    param(
        [int]$run_id,
        [int]$threads,
        [string]$statistic,
        [float]$value,
        $grouped_by_threads,
        $recorded_max
    )

    $grouped_by_threads[$threads][$statistic] += $value

    if ( $value -ge $recorded_max[$threads][$statistic]["value"] ) {
        $recorded_max[$threads][$statistic]["value"] = $value
        $recorded_max[$threads][$statistic]["run_id"] = $run_id
    }

}

$grouped_by_threads = @{}
$recorded_max = @{}

$content = Get-Content $file 

$RECORDED_STATISTICS = ` 
    "Iterations/s" , "SOS_SCHEDULER_YIELD" , "Standard Deviation" , `
    "Average" , "SOS waits(%)" , "CV" , "Maximum" , "Minimum" , "ratio max min"
    
foreach($line in $content ) {
    Try {
        if($line -match "Run:"){
            $run = $line -replace "Run:\s*(\S+)", '$1'    
        }

        if($line -match "Threads:"){
            $threads = $line -replace "Threads\s*:\s+(\S+)", '$1'
            [int]$threads = [convert]::ToInt32($threads, 10)
    
            if ( ! $grouped_by_threads.ContainsKey($threads) ) {
                $grouped_by_threads[$threads] = @{}
                $recorded_max[$threads] = @{}
                foreach ( $statistic in $RECORDED_STATISTICS ) {
                    $grouped_by_threads[$threads][$statistic] = @()
                    $recorded_max[$threads][$statistic] = @{}
                }
                 
            }

        }

        foreach ( $statistic in $RECORDED_STATISTICS ) {

            if($line -match $statistic ){
                $value = $line -replace "$statistic\s*:?\s+(\S+)\s*\S*", '$1'
                $value = [float]$value
                if ( $statistic -eq "Average" ) {
                    $average = $value
                } elseif ( $statistic -eq "SOS_SCHEDULER_YIELD" ) {     
                    $overhead = $value / $threads
                    $overhead = $overhead * 100  / ( $average - $overhead ) 
                    SetValue1 $run $threads "SOS waits(%)" $overhead `
                        $grouped_by_threads $recorded_max
                    #$grouped_by_threads[$threads]["SOS waits(%)"] += `
                     #   $overhead

                } elseif ( $statistic -eq "Standard Deviation" ) {
                    $cv = $value * 100 / $average
                    #$grouped_by_threads[$threads]["CV"] += $cv
                    SetValue1 $run $threads "CV" $cv $grouped_by_threads `
                        $recorded_max
                } elseif ( $statistic -eq "Maximum" ) {
                    $maximum = $value 
                } elseif ( $statistic -eq "Minimum" ) {
                    $ratio_max_min = $maximum / $value
                    SetValue1 $run $threads "ratio max min" $ratio_max_min `
                        $grouped_by_threads $recorded_max
                }
                #$grouped_by_threads[$threads][$statistic] += $value
                SetValue1 $run $threads $statistic $value $grouped_by_threads $recorded_max
            }


        }


    } Catch {
        Write-Host "Run: " $run
        Write-Host "Threads: " $threads
        Write-Host "Statistic: " $statistic
        $host.SetShouldExit(-1)
        throw
    }
}

#$AVG_STATISTICS = "Iterations/s" , "SOS waits(%)" , "CV" , "ratio max min"
#$MAX_STATISTICS = "SOS waits(%)" , "CV"
$MAX_STATISTICS = @()
#$RECORDED_MAX_STATISTICS = "CV" , "SOS waits(%)" , "ratio max min"
$AVG_STATISTICS = $Metric
$RECORDED_MAX_STATISTICS = $Metric

$output_arr = @()

foreach ( $threads in $grouped_by_threads.Keys ) { 

    $arr_item = [PSCustomObject]@{}

    Add-Member -InputObject $arr_item `
            -NotePropertyName ( "Load" ) -NotePropertyValue $threads

    foreach ( $statistic in $AVG_STATISTICS ) {
        $value = $grouped_by_threads[$threads][$statistic] | 
            Measure-Object -Average | select -ExpandProperty Average
        $value = [math]::Round($value, 1) 
        Add-Member -InputObject $arr_item `
            -NotePropertyName ( "AVG " + $statistic ) -NotePropertyValue $value
    }  

    foreach ( $statistic in $MAX_STATISTICS ) {
        $value = $grouped_by_threads[$threads][$statistic] | 
            Measure-Object -Maximum | select -ExpandProperty Maximum
        $value = [math]::Round($value, 0) 
        Add-Member -InputObject $arr_item `
            -NotePropertyName ( "MAX " + $statistic ) -NotePropertyValue $value
    }

    $i = 1
    foreach ( $statistic in $RECORDED_MAX_STATISTICS ) {
        $value = $recorded_max[$threads][$statistic]["value"]
        $value = [math]::Round($value, 1)
        $run_id = $recorded_max[$threads][$statistic]["run_id"]
        Add-Member -InputObject $arr_item `
            -NotePropertyName ( "MAX " + $statistic ) `
            -NotePropertyValue $value
        Add-Member -InputObject $arr_item `
            -NotePropertyName ( "Run id " + $i ) `
            -NotePropertyValue $run_id
        $i++
    }

    $output_arr += $arr_item
    
} 

$output_arr | Format-Table -Property *
