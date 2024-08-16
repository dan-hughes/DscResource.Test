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

Describe 'DscResource.GalleryDeploy\Get-FunctionDefinitionAst' -Tag 'Get-FunctionDefinitionAst' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:mockScriptPath = Join-Path -Path $TestDrive -ChildPath 'TestFunctions.ps1'
        }
    }

    Context 'When a script file has function definitions' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                    function Get-Something
                    {
                        return "test1"
                    }

                    function Get-SomethingElse
                    {
                        param
                        (
                            [Parameter()]
                            [System.String]
                            $Param1
                        )

                        return $Param1
                    }
                '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding 'ascii' -Force
            }
        }

        It 'Should return the correct number of function definitions' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Get-FunctionDefinitionAst -FullName $script:mockScriptPath
                $result | Should -HaveCount 2
            }
        }
    }

    Context 'When a script file has no function definitions' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                    $script:variable = 1
                    return $script:variable
                '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding 'ascii' -Force
            }
        }

        It 'Should return $null' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Get-FunctionDefinitionAst -FullName $script:mockScriptPath
                $result | Should -BeNullOrEmpty
            }
        }
    }
}
