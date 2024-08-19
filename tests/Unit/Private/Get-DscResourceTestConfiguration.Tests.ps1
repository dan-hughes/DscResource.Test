# Suppressing this rule because Script Analyzer does not understand Pester's syntax.
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    $script:ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
            ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
            $(try
                {
                    Test-ModuleManifest $_.FullName -ErrorAction Stop
                }
                catch
                {
                    $false
                } )
        }).BaseName


    Import-Module $script:ProjectName -Force

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:ProjectName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:ProjectName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:ProjectName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:ProjectName -All | Remove-Module -Force
}

Describe 'Get-DscResourceTestConfiguration' {
    BeforeAll {
        Mock Get-StructuredObjectFromFile -MockWith { Param($Path) $Path }
        Mock ConvertTo-OrderedDictionary -MockWith { Param($Configuration) $Configuration }
        Mock Write-Debug
    }

    It 'Should have correct code path when passing IDictionary' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration -Configuration @{ }
        }

        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a Dictionary' }
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should have correct code path when passing PSCustomObject' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration -Configuration ([PSCustomObject]@{ })
        }

        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a PSCustomObject' }
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should have correct code path when passing a path' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration -Configuration 'TestDrive:\.MetaOptIn.json'
        }

        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a String, probably a Path' }
        Should -Invoke -CommandName Get-StructuredObjectFromFile -Scope It
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should use MetaOptIn file by default' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration
        }
        
        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a String, probably a Path' }
        Should -Invoke -CommandName Get-StructuredObjectFromFile -Scope It
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should throw when called passing int' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            { Get-DscResourceTestConfiguration -Configuration 2 } | Should -Throw
        }
    }
}
