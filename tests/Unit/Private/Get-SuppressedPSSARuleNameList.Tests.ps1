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
    $script:moduleName = 'DscResource.Test'

    # Make sure there are not other modules imported that will conflict with mocks.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force

    # Re-import the module using force to get any code changes between runs.
    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:moduleName
}

Describe 'Private\Get-SuppressedPSSARuleNameList' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:rule1 = "'PSAvoidUsingConvertToSecureStringWithPlainText'"
            $script:rule2 = "'PSAvoidGlobalVars'"

            $script:scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }
    }

    Context 'When a module files contains suppressed rules' {
        It 'Should return the all the suppressed rules' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                "
            # Testing suppressing this rule
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute($script:rule1, '')]
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute($script:rule2, '')]
            param()
            " | Out-File -FilePath $script:scriptPath -Encoding ascii -Force

                $result = Get-SuppressedPSSARuleNameList -FilePath $script:scriptPath
                $result.Count | Should -Be 4
                $result[0] | Should -Be $script:rule1
                $result[1] | Should -Be "''"
                $result[2] | Should -Be $script:rule2
                $result[3] | Should -Be "''"
            }
        }
    }
}
