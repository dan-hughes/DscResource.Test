$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
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


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Set-SourceEncoding' {
        Context 'When file has a mof extension' {
            BeforeAll {
                $filePath = Join-Path $TestDrive -ChildPath 'TestFile.mof'
                Mock -Command ConvertTo-UTF8
            }

            It 'Should not throw and invoke the correct mocks' {
                { Set-SourceEncoding -FileInfo $filePath } | Should -Not -Throw

                Assert-MockCalled ConvertTo-UTF8 -Exactly -Times 1
            }
        }

        Context 'When file does not have a mof extension' {
            BeforeAll {
                $filePath = Join-Path $TestDrive -ChildPath 'TestFile.ps1'
                Mock -Command ConvertTo-ASCII
            }

            It 'Should not throw and invoke the correct mocks' {
                { Set-SourceEncoding -FileInfo $filePath } | Should -Not -Throw

                Assert-MockCalled ConvertTo-ASCII -Exactly -Times 1
            }
        }
    }
}
