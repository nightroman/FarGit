
Import-Module FarGit
$RepoRoot = "C:\TEMP\FarGitTestRepo"

function Invoke-Git($Command__) {
	$ErrorActionPreference = 'Continue'
	$res = & $Command__ 2>&1
	if ($LASTEXITCODE) {
		throw $res
	}
	$res
}

function Set-Repo {
	Set-Location -LiteralPath $RepoRoot
}

function Get-Repo {
	$RepoRoot
}

function Install-Repo {
	if (!(Test-Path -LiteralPath $RepoRoot)) {
		$null = mkdir $RepoRoot
	}

	Set-Repo

	if (!(Test-Path .git)) {
		$null = Invoke-Git {git init}
		Set-Content README.md '# Test repo for FarGit'
		$null = Invoke-Git {git add --all}
		$null = Invoke-Git {git commit --all --message start}
	}

	if ((Invoke-Git {git branch --show-current}) -ne 'main') {
		$null = Invoke-Git {git checkout main}
	}

	$null = Invoke-Git {git reset --hard}
}
