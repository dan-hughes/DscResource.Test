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

    if ($isLinux -or $isMacOS)
    {
        Write-Warning -Message 'DSC configuration parsing is not currently supported on Linux or MacOS. Skipping test.'
        return
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

Describe 'DscResource.GalleryDeploy\Test-ConfigurationName' -Tag 'WindowsOnly' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:mockScriptPath = Join-Path -Path $TestDrive -ChildPath '99-TestConfig'
        }
    }

    Context 'When a script file has the correct name' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration TestConfig
                {
                }
            '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $script:mockScriptPath
                $result | Should -BeTrue
            }
        }
    }

    Context 'When a script file has the correct name but is a LCM meta configuration' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                [DSCLocalConfigurationManager()]
                Configuration TestConfig
                {
                }
            '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $script:mockScriptPath
                $result | Should -BeTrue
            }
        }
    }

    Context 'When a script file has the different name than the configuration name' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration WrongConfig
                {
                }
            '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $script:mockScriptPath
                $result | Should -BeFalse
            }
        }
    }

    Context 'When the configuration name starts with a number' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration 1WrongConfig
                {
                }
            '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should throw the correct error' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $errorMessage = 'The configuration name ''1WrongConfig'' is not valid.'
                { Test-ConfigurationName -Path $script:mockScriptPath } | Should -Throw -ExpectedMessage ('*' + $errorMessage + '*')
            }
        }
    }

    Context 'When the configuration name does not end with a letter or a number' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration WrongConfig_
                {
                }
            '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $script:mockScriptPath
                $result | Should -BeFalse
            }
        }
    }

    Context 'When the configuration name contain other characters than only letters, numbers, and underscores' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration Wrong-Config
                {
                }
            '

                $definition | Out-File -FilePath $script:mockScriptPath -Encoding utf8 -Force
            }
        }

        BeforeDiscovery {
            <#
                    It is not allowed to have a configuration name that contains
                    a dash ('-') in PS5.0. Skipping this test if it is PS5.0.
                #>
            $skipTest = $PSVersionTable.PSVersion -lt [System.Version] '5.1'
        }

        It 'Should return false' -Skip:$skipTest {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $script:mockScriptPath
                $result | Should -BeFalse
            }
        }
    }
}
