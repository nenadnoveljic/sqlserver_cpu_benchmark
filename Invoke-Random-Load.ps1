<#

(c) 2019 Nenad Noveljic All Rights Reserved

Usage: 
Invoke-Random-Load -Server Server\Instance -MaxConcurrency c -iterations i

Version 1.0

Prerequisites: sp_cpu_loop in the database

It runs Invoke-Load i times. The concurrency of each execution is a random 
number between 1 and c. The output can be processed by Show-Stats.

#>

param (
   [parameter(Mandatory=$true)][string]$server,
   [int]$iterations = 1,
   [int]$MaxConcurrency = 1
)

$MaxConcurrency++

For ( $i = 1 ; $i -le $iterations ; $i++ ) {
    Write-Host ( "Run: " + $i  ) 
    $concurrency = Get-Random -Minimum 1 -Maximum $MaxConcurrency
    .\Invoke-Load.ps1 -Server $Server -Concurrency $concurrency
    Write-Host "==============================="
}
