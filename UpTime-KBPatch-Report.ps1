<# 
.SYNOPSIS
    Reports uptimes of specified workstations.

.EXAMPLE
    .\Script.ps1 Server01, Server02
    Reports uptimes for Server01, Server02

.EXAMPLE
    .\Script.ps1 -FindHotFix KB4019264, KB982018
    Reports uptimes for all servers in Default array and searched for specified HotFixes. Value(s) will only return if they are found.

.NOTES
    Written by JBear 5/19/16	
#>

[cmdletbinding()]

Param (

    #Change -Searchbase to desired OU or, change $ComputerName= to something entirely different
    #i.e. Get-Content C:\serverlist.txt
    [Parameter(ValueFromPipeline=$true,position=0)]
    $ComputerName = ((Get-ADComputer -Filter * -SearchBase "OU=Servers,DC=ACME,DC=COM").Name),

    #Format today's date
    $LogDate = (Get-Date -format yyyyMMdd),

    #$OutFile = "\\Server01\WeeklyReports\" + $LogDate + "-ServerUpTimeReport.csv"
    $OutFile = "C:\ServerUpTimeReport.csv",

    [Parameter(position=1)]
    [Switch]$FindHotFix,

    [Parameter(ValueFromPipeline=$true,Position=2)]
    [String[]]$KB=@()
)	

$i=0
$j=0
			
function UptimeReport {

    foreach ($Computer in $ComputerName) {

        Write-Progress -Activity "Retrieving Uptime and HotFix results..." -Status ("Percent Complete:" + "{0:N0}" -f ((($i++) / $ComputerName.count) * 100) + "%") -CurrentOperation "Processing $($Computer)..." -PercentComplete ((($j++) / $ComputerName.count) * 100)

        if(!([String]::IsNullOrWhiteSpace($Computer))) {

            if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                Start-Job { param($Computer, $ComputerName, $KB)

                    if($KB) {

                        Invoke-Command -ComputerName $Computer {param ($Computer, $KB)

                            $uptime = Get-WmiObject Win32_OperatingSystem -ComputerName $Computer
                            $bootTime = $uptime.ConvertToDateTime($uptime.LastBootUpTime)
                            $elapsedTime = (Get-Date) - $bootTime
                            $HotFixResults = Get-HotFix -Id $KB -ErrorAction SilentlyContinue

                            if($HotFixResults) {

                                foreach($HotFix in $HotFixResults) {

                                    [pscustomobject] @{

                                        ComputerName = $Computer
                                        LastBootTime = $bootTime
                                        ElapsedTime = '{0:00} Days, {1:00} Hours, {2:00} Minutes, {3:00} Seconds' -f $elapsedTime.Days, $elapsedTime.Hours, $elapsedTime.Minutes, $elapsedTime.Seconds
                                        HotFix=$HotFix.HotFixID
                                        HFInstallDate=$HotFix.InstalledOn
                                    }
                                }

                                $KB | ForEach-Object {
                                            
                                    if(!($hotfixresults.HotFixID -contains $_)) {
                                        
                                        [pscustomobject] @{

                                            ComputerName = $Computer
                                            LastBootTime = $bootTime
                                            ElapsedTime = '{0:00} Days, {1:00} Hours, {2:00} Minutes, {3:00} Seconds' -f $elapsedTime.Days, $elapsedTime.Hours, $elapsedTime.Minutes, $elapsedTime.Seconds
                                            HotFix=$_
                                            HFInstallDate='Not Installed'
                                        }
                                    }
                                }
                            }

                            else {

                                $KB | ForEach-Object {
                                            
                                    if(!($hotfixresults.HotFixID -contains $_)) {

                                        [pscustomobject] @{

                                            ComputerName = $Computer
                                            LastBootTime = $bootTime
                                            ElapsedTime = '{0:00} Days, {1:00} Hours, {2:00} Minutes, {3:00} Seconds' -f $elapsedTime.Days, $elapsedTime.Hours, $elapsedTime.Minutes, $elapsedTime.Seconds
                                            HotFix=$_
                                            HFInstallDate='Not Installed'
                                        }    
                                    }
                                }                                                  
                            }
                        } -ArgumentList $Computer, $KB
                    }

                    else {

                        $uptime = Get-WmiObject Win32_OperatingSystem -ComputerName $Computer
                        $bootTime = $uptime.ConvertToDateTime($uptime.LastBootUpTime)
                        $elapsedTime = (Get-Date) - $bootTime

                        [pscustomobject] @{

                            ComputerName = $Computer
                            LastBootTime = $bootTime
                            ElapsedTime = '{0:00} Days, {1:00} Hours, {2:00} Minutes, {3:00} Seconds' -f $elapsedTime.Days, $elapsedTime.Hours, $elapsedTime.Minutes, $elapsedTime.Seconds
                            HotFix=$null
                            HFInstallDate=$null
                        }
                    }
                } -Name "Uptime Information" -ArgumentList $Computer, $ComputerName, $KB
            }

            else {

                Start-Job {param ($Computer)

                    [pscustomobject] @{

                        ComputerName = $Computer
                        LastBootTime = 'Ping failed'
                        ElapsedTime = 'N/A'
                        HotFix='N/A'
                        HFInstallDate=$null
                    }
                } -Name "PING Failed" -ArgumentList $Computer
            }
        }
    }
} 

if(!($FindHotFix.IsPresent)) {

    UptimeReport | Receive-Job -Wait -AutoRemoveJob |  Sort ComputerName | Select ComputerName, LastBootTime, ElapsedTime | Export-Csv $OutFile -NoTypeInformation -Force
    Write-Host -ForegroundColor Green "Server uptime results saved to $OutFile"
}

else {

    UptimeReport | Receive-Job -Wait -AutoRemoveJob |  Sort ComputerName | Select ComputerName, LastBootTime, ElapsedTime, HotFix, HFInstallDate | Export-Csv $OutFile -NoTypeInformation -Force
    Write-Host -ForegroundColor Green "Server uptime results saved to $OutFile"
}
