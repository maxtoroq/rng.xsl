param(
   [Parameter(Position=0)]$TestFile = $null, 
   [Parameter(Position=1)]$CaseNumber = $null,
   [switch]$ValidateSchemas = $false
)

$ErrorActionPreference = "Stop"

if ($TestFile -ne $null) {
   $TestFile = Resolve-Path $TestFile
}

Push-Location (Split-Path $script:MyInvocation.MyCommand.Path)

$rng = Resolve-Path ..\src\rng.xsl
$rng_simpl = Resolve-Path ..\src\rng-simplify.xsl
$saxon_nuget = "..\packages\Saxon-HE"

$ns = "http://maxtoroq.github.io/rng.xsl"
$docb = $null
$rng_schema_doc = $null

function case-title($spectest, $case) {
   
   $caseNum = [int]$case.ToString()
   $testCase = Select-Xml "(//testCase)[$caseNum]" $spectest
   
   $sections = Select-Xml 'ancestor-or-self::*[section][1]/section' $testCase.Node
   $first = $true

   foreach ($section in $sections) {

      if ($first) { 
         write "Section" 
      } else { 
         write "/"
      }

      write $section.Node.'#text'
      $first = $false
   }

   $title = Select-Xml 'ancestor-or-self::*[documentation and parent::*][1]/documentation' $testCase.Node

   if ($title -ne $null) {
      if ($sections.Count -gt 0) {
         write "-"
      }
      write $title.Node.'#text'
   }
}

function write-exception([Saxon.Api.DynamicError]$exception, $case_id, $title) {
   
   Write-Warning @"
Unexpected exception running [$case_id] $title
$($exception.Message)
Module: $($exception.ModuleUri)
At line: $($exception.LineNumber)
"@
}

function build-document($d) {
   if ($d -is [Saxon.Api.XdmValue]) {
      $d
   } else {
      $docb.Build((New-Object Uri $d))
   }
}

function load-rng-transform($rng_exec, $instance, $schema) {

   $rng_transform = $rng_exec.Load()
   $rng_transform.InitialMode = New-Object Saxon.Api.QName $ns, "main"
   $rng_transform.InitialContextNode = build-document $instance
   $rng_transform.SetParameter((New-Object Saxon.Api.QName $ns, "schema"), (build-document $schema))

   return $rng_transform
}

function validate-schema($rng_exec, $schema) {
   
   $rng_transform = load-rng-transform $rng_exec $schema $rng_schema_doc
   $writer = New-Object IO.StringWriter

   $serializer = New-Object Saxon.Api.Serializer
   $serializer.SetOutputProperty((New-Object Saxon.Api.QName "method"), "text")
   $serializer.SetOutputWriter($writer)

   $rng_transform.Run($serializer)

   return [bool]::Parse($writer.ToString())
}

function test($TestFile) {
   
   Add-Type -Path (Join-Path $saxon_nuget "lib\net40\saxon9he-api.dll") 

   $processor = New-Object Saxon.Api.Processor

   if ($CaseNumber -eq $null) {
      $processor.ErrorWriter = [IO.TextWriter]::Null
   }

   $compiler = $processor.NewXsltCompiler()
   $docb = $processor.NewDocumentBuilder()

   $rng_exec = $null
   $rng_simpl_exec = $null
   $rng_schema_doc = $docb.Build((New-Object Uri (Resolve-Path relaxng.rng)))
  
   try {
      $rng_exec = $compiler.Compile((New-Object Uri $rng))
      $rng_simpl_exec = $compiler.Compile((New-Object Uri $rng_simpl))
   } catch {
      write $compiler.ErrorList[0]
      write $compiler.ErrorList[0].LineNumber
      return
   }

   [xml]$spectest = Get-Content $TestFile
   $dir = Split-Path -Parent $TestFile

   $passed = 0
   $failed = 0
   $total = 0

   $cases_dir = Join-Path $dir (gi $TestFile).BaseName

   if (-not (Test-Path $cases_dir -PathType Container)) {
      .\split.ps1 $TestFile
   }

   $cases = ls $cases_dir -Directory

   if ($CaseNumber -ne $null) {
      $cases = $cases[$CaseNumber - 1]
   }

   foreach ($case in $cases) {
      
      Push-Location $case.FullName

      $case_success = $true

      try {
         
         $title = case-title $spectest $case

         $rng_simpl_transform = $rng_simpl_exec.Load()
         $rng_simpl_transform.InitialMode = New-Object Saxon.Api.QName "$ns/simplify", "main"

         if (Test-Path i.rng) {
            
            $incorrect_doc = $docb.Build((New-Object Uri (Resolve-Path i.rng)))

            if ($ValidateSchemas) {

               $schema_valid = $null

               try {
                  $schema_valid = validate-schema $rng_exec $incorrect_doc

               } catch [Saxon.Api.DynamicError] {
                  write-exception $_.Exception "$($case)-i" $title
               }

               if ($schema_valid) {
                  $case_success = $false
                  Write-Warning "[$($case)-i] $title"
               }
            
            } else {
            
               $rng_simpl_transform.InitialContextNode = $incorrect_doc
               $output = New-Object Saxon.Api.XdmDestination

               try {
                  $rng_simpl_transform.Run($output)
                  $case_success = $false

               } catch [Saxon.Api.DynamicError] {
               
                  $err_code = $_.Exception.ErrorCode

                  if ($err_code.Uri -ne $ns) {
                     write-exception $_.Exception "$($case)-i" $title
                     return
                  }
               }

               if (-not $case_success) {

                  Write-Warning "[$($case)-i] $title"
               
                  if ($CaseNumber -ne $null) {
                     write $output.XdmNode.OuterXml
                  }
               }
            }

         } else {
            
            $correct_doc = $docb.Build((New-Object Uri (Resolve-Path c.rng)))

            if ($ValidateSchemas) {
               
               $schema_valid = $null

               try {
                  $schema_valid = validate-schema $rng_exec $correct_doc

               } catch [Saxon.Api.DynamicError] {

                  write-exception $_.Exception "$($case)-c" $title
               }

               if (-not $schema_valid) {
                  $case_success = $false
                  Write-Warning "[$($case)-c] $title"
               }

            } else {
               
               $rng_simpl_transform.InitialContextNode = $correct_doc
               $output = New-Object Saxon.Api.XdmDestination

               try {
                  $rng_simpl_transform.Run($output)

               } catch {

                  $case_success = $false
                  Write-Warning "[$($case)-c] $title" 
               }
               
               if ($case_success) {

                  foreach ($valid in (ls *.v.xml)) {

                     $rng_transform = load-rng-transform $rng_exec $valid.FullName (Resolve-Path c.rng)
                     $writer = New-Object IO.StringWriter

                     $serializer = New-Object Saxon.Api.Serializer
                     $serializer.SetOutputProperty((New-Object Saxon.Api.QName "method"), "text")
                     $serializer.SetOutputWriter($writer)

                     try {
                        $rng_transform.Run($serializer)

                     } catch [Saxon.Api.DynamicError] {

                        $case_success = $false
                        write-exception $_.Exception "$($case)-$($valid.Name)" $title
                        continue
                     }

                     if ($writer.ToString() -ne "true") {
                        $case_success = $false
                        Write-Warning "[$($case)-$($valid.Name)] $title" 
                     }
                  }

                  foreach ($invalid in (ls *.i.xml)) {

                     $rng_transform = load-rng-transform $rng_exec $invalid.FullName (Resolve-Path c.rng)
                     $writer = New-Object IO.StringWriter

                     $serializer = New-Object Saxon.Api.Serializer
                     $serializer.SetOutputProperty((New-Object Saxon.Api.QName "method"), "text")
                     $serializer.SetOutputWriter($writer)

                     try {
                        $rng_transform.Run($serializer)

                     } catch [Saxon.Api.DynamicError] {

                        $case_success = $false
                        write-exception $_.Exception "$($case)-$($invalid.Name)" $title
                        continue
                     }

                     if ($writer.ToString() -ne "false") {
                        $case_success = $false
                        Write-Warning "[$($case)-$($invalid.Name)] $title" 
                     }
                  }
               }
            }
         }

      } finally {
         Pop-Location
      }

      $total = $total + 1

      if ($case_success) {
         $passed = $passed + 1
      } else {
         $failed = $failed + 1
      }
   }

   write @"
Passed: $passed
Failed: $failed
Total: $total
"@
}

function main {
   
   ../packages/restore.ps1

   $suites = if ($TestFile -ne $null) { 
      gi $TestFile 
   } else { 
      ls "*.xml"
   }

   foreach ($suite in $suites) {
      
      write "Test Suite: $($suite.Name)"
      test $suite
      write ""
   }
}

try {
   main
} finally {
   Pop-Location
}
