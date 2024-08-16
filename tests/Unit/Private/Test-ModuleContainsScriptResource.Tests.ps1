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

Describe 'Test-ModuleContainsScriptResource' {
    Context 'When a module contains script resources' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $resourceName1 = 'TestResource1'
                $resourceName2 = 'TestResource2'
                $resourcesPath = Join-Path -Path $TestDrive -ChildPath 'DscResources'
                $testResourcePath1 = (Join-Path -Path $resourcesPath -ChildPath $resourceName1)
                $testResourcePath2 = (Join-Path -Path $resourcesPath -ChildPath $resourceName2)

                New-Item -Path $resourcesPath -ItemType Directory
                New-Item -Path $testResourcePath1 -ItemType Directory
                New-Item -Path $testResourcePath2 -ItemType Directory

                'resource_schema1' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath1) -Encoding ascii
                'resource_schema2' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath2) -Encoding ascii
            }
        }

        It 'Should return $true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ModuleContainsScriptResource -ModulePath $TestDrive
                $result | Should -BeTrue
            }
        }
    }

    Context 'When a module does not contain a script resource' {
        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ModuleContainsScriptResource -ModulePath $TestDrive
                $result | Should -BeFalse
            }
        }
    }
}
