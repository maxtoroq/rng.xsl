param($Schema, $Instance)

$ErrorActionPreference = "Stop"

$Schema = Resolve-Path $Schema
$Instance = Resolve-Path $Instance
$saxon = "..\packages\Saxon-HE\tools\Transform.exe"

Push-Location (Split-Path $script:MyInvocation.MyCommand.Path)

try {

   ../packages/restore.ps1
   
   &$saxon `
      -s:$Instance `
      -xsl:..\src\rng.xsl `
      -im:`{http://maxtoroq.github.io/rng.xsl`}main `
      +`{http://maxtoroq.github.io/rng.xsl`}schema=$Schema `
      !method=text

   write ""

} finally {
   Pop-Location
}