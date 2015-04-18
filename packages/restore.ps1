
$ErrorActionPreference = "Stop"

$nuget = "..\.nuget\nuget.exe"

Push-Location (Split-Path $script:MyInvocation.MyCommand.Path)

function ensure-nuget {
   if (-not (Test-Path $nuget -PathType Leaf)) {
      
      $nuget_dir = Split-Path -Parent $nuget

      if (-not (Test-Path $nuget_dir -PathType Container)) {
         md $nuget_dir | Out-Null
      }

      write "Downloading NuGet..."
      Invoke-WebRequest https://www.nuget.org/nuget.exe -OutFile $nuget
   }
}

function ensure-saxon {
   if (-not (Test-Path Saxon-HE -PathType Container)) {
      ensure-nuget
      write "Downloading Saxon-HE..."
      &$nuget install Saxon-HE -ExcludeVersion
   }
}


try {
   ensure-saxon
} finally {
   Pop-Location
}