# ==========================================================
# Cleanup.Tests.ps1 - Cleanup.ps1 helper functions
#
# Cleanup.ps1 is an executable module (it deletes files), so
# we do NOT dot-source it. Instead we extract only the two
# helper functions (Clear-PathAndReport, Clear-PatternSet)
# from the parsed AST and test those against temp folders.
# ==========================================================

. (Join-Path $PSScriptRoot "_Bootstrap.ps1")

$CleanupPath = Join-Path $Global:TestModules "Cleanup.ps1"

$Tokens = $null
$Errors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $CleanupPath, [ref]$Tokens, [ref]$Errors)

$Extracted = @()

foreach ($Fn in $Ast.FindAll({ param($N) $N -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
{
    if ($Fn.Name -in @("Clear-PathAndReport", "Clear-PatternSet"))
    {
        Invoke-Expression $Fn.Extent.Text
    }
}

Describe "Cleanup module" {

    It "parses without syntax errors" {
        $Errors.Count | Should Be 0
    }

    It "defines the two helper functions" {
        (Get-Command Clear-PathAndReport -ErrorAction SilentlyContinue) | Should Not Be $null
        (Get-Command Clear-PatternSet -ErrorAction SilentlyContinue) | Should Not Be $null
    }
}

Describe "Clear-PathAndReport" {

    It "removes all contents of a folder" {
        $Dir = Join-Path $TestDrive "clean1"
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Set-Content -Path (Join-Path $Dir "a.txt") -Value ("Z" * 500) -Encoding UTF8
        New-Item -ItemType Directory -Path (Join-Path $Dir "sub") -Force | Out-Null

        $Freed = Clear-PathAndReport -Label "Test" -Path $Dir

        (Get-ChildItem $Dir -Force).Count | Should Be 0
        ($Freed -is [double]) | Should Be True
    }

    It "returns 0 and does not throw for a missing path" {
        $Freed = Clear-PathAndReport -Label "Test" -Path (Join-Path $TestDrive "missing")

        $Freed | Should Be 0
    }
}

Describe "Clear-PatternSet" {

    It "removes files matching the patterns" {
        $Dir = Join-Path $TestDrive "patterns"
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Set-Content -Path (Join-Path $Dir "one.log") -Value "x" -Encoding UTF8
        Set-Content -Path (Join-Path $Dir "two.log") -Value "x" -Encoding UTF8
        Set-Content -Path (Join-Path $Dir "keep.txt") -Value "x" -Encoding UTF8

        Clear-PatternSet -Label "Test" -Patterns @((Join-Path $Dir "*.log"))

        (Get-ChildItem $Dir -Force).Count | Should Be 1
    }

    It "does not throw when nothing matches" {
        { Clear-PatternSet -Label "Test" -Patterns @((Join-Path $TestDrive "*.nope")) } | Should Not Throw
    }
}
