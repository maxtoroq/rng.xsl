param($TestFile)

$ErrorActionPreference = "Stop"

$TestFile = Resolve-Path $TestFile
$saxon = "..\packages\Saxon-HE\tools\Transform.exe"

Push-Location (Split-Path $script:MyInvocation.MyCommand.Path)

try {

   ../packages/restore.ps1
   
   $dir = Split-Path -Parent $TestFile
   $cases = Join-Path $dir (gi $TestFile).BaseName

   if (Test-Path $cases -PathType Container) {
      rm $cases -Recurse
   }

   md $cases | Out-Null

   $cases_uri = (New-Object Uri $cases).AbsoluteUri

   &$saxon -s:$TestFile -xsl:split.xsl output-dir=$cases_uri

} finally {
   Pop-Location
}