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

Describe 'Get-StructuredObjectFromFiles' {
    BeforeAll {
        Mock -CommandName Import-PowerShellDataFile
        Mock -CommandName Get-Content
        Mock -CommandName Import-Module
        Import-Module powershell-yaml -Force -ErrorAction Stop
        Mock -CommandName ConvertFrom-Yaml
        # Mock -CommandName ConvertFrom-Json fails on 6.x
    }

    It 'Should Import a PowerShell DataFile when path extension is PSD1' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.psd1'
        }
        Assert-MockCalled -CommandName Import-PowerShellDataFile -Scope it
    }


    # It 'Should ConvertFrom-Json when path extension is JSON' {
    # InModuleScope -ScriptBlock {
    #  Set-StrictMode -Version 1.0

    #     $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.json'
    #  }
    #     Assert-MockCalled -CommandName ConvertFrom-Json -Scope it
    # }

    It 'Should Import module & ConvertFrom-Yaml when path extension is Yaml' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.yaml'
        }
        Assert-MockCalled -CommandName Import-Module -Scope it
        Assert-MockCalled -CommandName ConvertFrom-Yaml -Scope It
    }


    It 'Should throw when extension not one of the above' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            { Get-StructuredObjectFromFile -Path 'TestDrive:\tests.txt' } | Should -Throw
        }
    }
}
