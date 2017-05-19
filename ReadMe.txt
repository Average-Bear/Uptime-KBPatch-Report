Line 24 -- To set a default set of values, Change -Searchbase to desired OU or, change $ComputerName= to something entirely different.
  You may also simply supply values to the pipeline.
  
  .EXAMPLE
    .\Uptime-KBPatch-Report.ps1 Server01, Server02

  .EXAMPLE
    .\Uptime-KBPatch-Report.ps1 Server01, Server02, Server03 -FindHotFix KB4019264, KB982018
