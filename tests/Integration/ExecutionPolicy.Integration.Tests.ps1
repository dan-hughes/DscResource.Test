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
                & "$PSScriptRoot/../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }
}

BeforeAll {
    $script:dscModuleName = 'PSDesiredStateConfiguration' # Need something that is already present
    $script:dscResourceName = 'NoResource'

    Write-Verbose -Message ("Execution Policy before Initialize-TestEnvironment:`r`n{0}" -f (Get-ExecutionPolicy -List | Out-String))

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Integration' `
        -Verbose

    Write-Verbose -Message ("Execution Policy after Initialize-TestEnvironment:`r`n{0}" -f (Get-ExecutionPolicy -List | Out-String))
}

AfterAll {
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment -Verbose

    Write-Verbose -Message ("Execution Policy after Restore-TestEnvironment:`r`n{0}" -f (Get-ExecutionPolicy -List | Out-String))
}

Describe 'Empty test' {
    It 'Should pass' {
        $true | Should -BeTrue
    }
}
