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

Describe 'TestHelper\Test-FileContainsClassResource' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:mockResourceName1 = 'TestResourceName1'
            $script:mockResourceName2 = 'TestResourceName2'

            $script:scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }
    }

    Context 'When module file contain class-based resources ''DscResource''' {
        It 'Should return $true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                "
                [DscResource()]
                class $script:mockResourceName1
                {
                }

                [DscResource()]
                class $script:mockResourceName2
                {
                }
                " | Out-File -FilePath $script:scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $script:scriptPath
                $result | Should -BeTrue
            }
        }
    }

    Context 'When module file contain class-based resources ''DscProperty''' {
        It 'Should return $true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                "
                class $script:mockResourceName1
                {
                    [DscProperty(Key)]
                    [System.String]
                    $SomeProperty
                }

                class $script:mockResourceName2
                {
                    [DscProperty()]
                    [System.String]
                    $SomeProperty
                }
                " | Out-File -FilePath $script:scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $script:scriptPath
                $result | Should -BeTrue
            }
        }
    }

    Context 'When module file does not contain class-based resources' {
        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                "
                function $script:mockResourceName1
                {
                }
                " | Out-File -FilePath $script:scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $script:scriptPath
                $result | Should -BeFalse
            }
        }
    }
}
