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

Describe 'Get-ObjectNotFoundRecord' -Tag 'GetObjectNotFoundRecord' {
    Context 'When calling with the parameter Message' {
        It 'Should have the correct values in the error record' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Get-ObjectNotFoundRecord -Message 'mocked error message.'

                $result | Should -BeOfType 'System.Management.Automation.ErrorRecord'
                $result.Exception | Should -BeOfType 'System.Exception'
                $result.Exception.Message | Should -Be 'System.Exception: mocked error message.'
            }
        }
    }

    Context 'When calling with the parameters Message and ErrorRecord' {
        It 'Should have the correct values in the error record' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = $null

                try
                {
                    # Force divide by zero exception.
                    1 / 0
                }
                catch
                {
                    $result = Get-ObjectNotFoundRecord -Message 'mocked error message.' -ErrorRecord $_
                }

                $result | Should -BeOfType 'System.Management.Automation.ErrorRecord'
                $result.Exception | Should -BeOfType 'System.Exception'
                $result.Exception.Message -match 'System.Exception: mocked error message.' | Should -BeTrue
                $result.Exception.Message -match 'System.Management.Automation.RuntimeException: Attempted to divide by zero.' | Should -BeTrue
                $result.Exception.Message -match 'System.DivideByZeroException: Attempted to divide by zero.' | Should -BeTrue
            }
        }
    }
}
