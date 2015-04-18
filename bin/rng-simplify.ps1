param($Schema)

$ErrorActionPreference = "Stop"

$Schema = Resolve-Path $Schema
$saxon = "..\packages\Saxon-HE\tools\Transform.exe"

Push-Location (Split-Path $script:MyInvocation.MyCommand.Path)

try {

   ../packages/restore.ps1
   
   &$saxon `
      -s:$Schema `
      -xsl:..\src\rng-simplify.xsl `
      -im:`{http://maxtoroq.github.io/rng.xsl/simplify`}main `
      !indent=yes

} finally {
   Pop-Location
}