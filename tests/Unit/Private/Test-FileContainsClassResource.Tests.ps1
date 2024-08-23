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

Describe 'Private\Test-FileContainsClassResource' -Tag 'Private' {
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
