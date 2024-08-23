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

Describe 'Public\Get-DscResourceTestContainer' -Tag 'Public' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:mockGetDscResourceTestContainerParameters = @{
                ProjectPath   = '.'
                ModuleName    = 'MyDscResourceName'
                DefaultBranch = 'main'
                SourcePath    = './source'
                ModuleBase    = "./output/MyDscResourceName/*"
            }
        }
    }

    Context 'When only Pester 4 is available' {
        BeforeAll {
            Mock -CommandName Get-Module -MockWith {
                return @{
                    Version = '4.10.1'
                }
            }
        }

        It 'Should throw the correct exception' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                { Get-DscResourceTestContainer @script:mockGetDscResourceTestContainerParameters } | Should -Throw 'This command requires Pester v5.1.0 or higher to be installed.'
            }
        }
    }

    Context 'When getting Pester 5 HQRM tests script containers' {
        BeforeAll {
            # Must create a stub since this does not exist in Pester 4.
            function New-PesterContainer
            {
                throw '{0}: StubNotImplemented' -f $MyInvocation.MyCommand
            }

            Mock -CommandName New-PesterContainer
            Mock -CommandName Get-Module -MockWith {
                return @{
                    Version = '5.1.0'
                }
            }
        }

        It 'Should call the correct mock' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                { Get-DscResourceTestContainer @script:mockGetDscResourceTestContainerParameters } | Should -Not -Throw
            }

            Should -Invoke -CommandName 'New-PesterContainer' -Exactly -Times 1 -Scope It
        }
    }
}
