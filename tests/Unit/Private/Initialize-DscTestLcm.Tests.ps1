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

Describe 'Initialize-DscTestLcm' {
    BeforeAll {
        Mock -CommandName New-Item
        Mock -CommandName Remove-Item
        Mock -CommandName Invoke-Command
        Mock -CommandName Set-DscLocalConfigurationManager

        # Stub of the generated configuration so it can be mocked.
        function LocalConfigurationManagerConfiguration
        {
        }

        Mock -CommandName LocalConfigurationManagerConfiguration
    }

    Context 'When Local Configuration Manager should have consistency disabled' {
        BeforeAll {
            $expectedConfigurationMetadata = '
                Configuration LocalConfigurationManagerConfiguration
                {
                    LocalConfigurationManager
                    {
                        ConfigurationMode = ''ApplyOnly''
                    }
                }
            '

            # Truncating everything to one line so easier to compare.
            $expectedConfigurationMetadataOneLine = $expectedConfigurationMetadata -replace '[ \r\n]'
        }

        It 'Should call Invoke-Command with the correct configuration' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

            { Initialize-DscTestLcm -DisableConsistency } | Should -Not -Throw
            }
            Assert-MockCalled -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1
        }
    }

    Context 'When Local Configuration Manager should have consistency disabled' {
        BeforeAll {
            $env:DscCertificateThumbprint = '1111111111111111111111111111111111111111'

            $expectedConfigurationMetadata = "
                Configuration LocalConfigurationManagerConfiguration
                {
                    LocalConfigurationManager
                    {
                        CertificateId = '$($env:DscCertificateThumbprint)'
                    }
                }
            "

            # Truncating everything to one line so easier to compare.
            $expectedConfigurationMetadataOneLine = $expectedConfigurationMetadata -replace '[ \r\n]'
        }

        AfterAll {
            Remove-Item -Path 'env:DscCertificateThumbprint' -Force
        }

        It 'Should call Invoke-Command with the correct configuration' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                { Initialize-DscTestLcm -Encrypt } | Should -Not -Throw
            }
            Assert-MockCalled -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1
        }
    }
}
