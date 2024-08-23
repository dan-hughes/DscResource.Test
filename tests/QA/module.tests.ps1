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
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }

    $allModuleFunctions = Get-Command -Module 'DscResource.Test' -CommandType Function
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

    #$here = Split-Path -Parent $MyInvocation.MyCommand.Path

    # Convert-path required for PS7 or Join-Path fails
    $script:ProjectPath = "$PSScriptRoot\..\.." | Convert-Path

    # $SourcePath = (Get-ChildItem $ProjectPath\*\*.psd1 | Where-Object {
    #     ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
    #         $(try
    #             {
    #                 Test-ModuleManifest $_.FullName -ErrorAction Stop
    #             }
    #             catch
    #             {
    #                 $false
    #             }) }
    # ).Directory.FullName

    # $ProjectName = 'DscResource.Test'
    #$mut = Import-Module -Name $ProjectName -ErrorAction Stop -PassThru -Force

}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:moduleName
}

Describe 'Changelog Management' -Tag 'Changelog' {
    It 'Should be updated' -skip:(
        !([bool](Get-Command git -EA SilentlyContinue) -and
            [bool](&(Get-Process -id $PID).Path -NoProfile -Command 'git rev-parse --is-inside-work-tree 2>$null'))
    ) {
        # Get the list of changed files compared with branch main
        $HeadCommit = &git rev-parse HEAD
        $defaultBranchCommit = &git rev-parse origin/main
        $filesChanged = &git @('diff', "$defaultBranchCommit...$HeadCommit", '--name-only')

        if ($HeadCommit -ne $defaultBranchCommit)
        {
            # if we're not testing same commit (i.e. main..main)
            $filesChanged.Where{ (Split-Path $_ -Leaf) -match '^changelog' } | Should -Not -BeNullOrEmpty
        }
    }

    It 'Should have a format compliant with keepachangelog format' -skip:(![bool](Get-Command git -EA SilentlyContinue)) {
        { Get-ChangelogData (Join-Path $script:ProjectPath 'CHANGELOG.md') -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should have an Unreleased header' {
        (Get-ChangelogData -Path (Join-Path -Path $script:ProjectPath -ChildPath 'CHANGELOG.md') -ErrorAction 'Stop').Unreleased.RawData | Should -Not -BeNullOrEmpty
    }
}

Describe 'General module control' -Tags 'FunctionalQuality' {
    AfterAll {
        #Re-Import the module for the remaining tests
        Import-Module -Name $script:moduleName -Force
    }

    It 'Should import without errors' {
        { Import-Module -Name $script:moduleName -Force -ErrorAction Stop } | Should -Not -Throw
        Get-Module $script:moduleName | Should -Not -BeNullOrEmpty
    }

    It 'Should remove without error' {
        { Remove-Module -Name $script:moduleName -ErrorAction Stop } | Should -Not -Throw
        Get-Module $script:moduleName | Should -BeNullOrEmpty
    }
}

Describe 'Function Tests' {
    Context 'When running tests for <_.Name>' -ForEach $allModuleFunctions {
        BeforeAll {
            $script:functionFile = Get-ChildItem -Path $script:ProjectPath -Recurse -Include "$($_.Name).ps1"
        }

        Context 'When running quality tests' -Tags 'TestQuality' {
            BeforeDiscovery {
                if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)
                {
                    $scriptAnalyzerRules = Get-ScriptAnalyzerRule
                    $skipScriptAnalyzerRules = $false
                }

                if (-not $scriptAnalyzerRules)
                {
                    $skipScriptAnalyzerRules = $true
                }
            }

            It 'Should have a unit test file' {
                Get-ChildItem "..\" -Recurse -Include "$($_.Name).Tests.ps1" | Should -Not -BeNullOrEmpty
            }

            It 'Should pass Script Analyzer' -Skip:$skipScriptAnalyzerRules {
                $PSSAResult = (Invoke-ScriptAnalyzer -Path $script:functionFile.FullName)
                $Report = $PSSAResult | Format-Table -AutoSize | Out-String -Width 110

                $PSSAResult  | Should -BeNullOrEmpty -Because `
                    "some rule triggered.`r`n`r`n $Report"
            }
        }

        Context 'When running help tests' -Tags 'helpQuality' {
            BeforeDiscovery {
                $discoveryFile = Get-ChildItem -Path ("$PSScriptRoot\..\.." | Convert-Path) -Recurse -Include "$($_.Name).ps1"
                $AbstractSyntaxTree = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content -raw $discoveryFile.FullName), [ref]$null, [ref]$null)
                $AstSearchDelegate = { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }
                $ParsedFunction = $AbstractSyntaxTree.FindAll( $AstSearchDelegate, $true ) |
                    Where-Object Name -eq $_.Name

                $parameters = $ParsedFunction.Body.ParamBlock.Parameters.name.VariablePath.foreach{ $_.ToString() }
            }

            BeforeAll {
                $AbstractSyntaxTree = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content -raw $script:functionFile.FullName), [ref]$null, [ref]$null)
                $AstSearchDelegate = { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }
                $ParsedFunction = $AbstractSyntaxTree.FindAll( $AstSearchDelegate, $true ) |
                    Where-Object Name -eq $_.Name

                $script:FunctionHelp = $ParsedFunction.GetHelpContent()
            }

            It 'Should have a SYNOPSIS' {
                $script:FunctionHelp.Synopsis | Should -Not -BeNullOrEmpty
            }

            It 'Should have a DESCRIPTION, with length > 40' {
                $script:FunctionHelp.Description.Length | Should -BeGreaterThan 40
            }

            It 'Should have at least 1 EXAMPLE' {
                $script:FunctionHelp.Examples.Count | Should -BeGreaterThan 0
                $script:FunctionHelp.Examples[0] | Should -Match ($_.Name)
                $script:FunctionHelp.Examples[0].Length | Should -BeGreaterThan ($_.Name.Length + 10)
            }

            It 'Has help for PARAMETER: <_>' -TestCases $parameters {
                $script:FunctionHelp.Parameters.($_.ToUpper()) | Should -Not -BeNullOrEmpty
                $script:FunctionHelp.Parameters.($_.ToUpper()).Length | Should -BeGreaterThan 25
            }
        }
    }
}
