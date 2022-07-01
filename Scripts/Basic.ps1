
# Invokes the native command and outputs errors.
function Invoke-Error($Command__) {
	#! Continue (not Ignore) to receive errors as output
	$ErrorActionPreference = 'Continue'
	$OutputEncoding__ = [Console]::OutputEncoding
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
	& $Command__ 2>&1
	[Console]::OutputEncoding = $OutputEncoding__
}

# Invokes the native command and checks for $LASTEXITCODE.
#! try/finally fails in panel scenarios, use Invoke-Error.
function Invoke-Native($Command__) {
	$OutputEncoding__ = [Console]::OutputEncoding
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
	try {
		& $Command__
		if ($LASTEXITCODE) {Write-Error "Exit code: $LASTEXITCODE. Command: $Command" -ErrorAction 1}
	}
	finally {
		[Console]::OutputEncoding = $OutputEncoding__
	}
}

# Shows the error $_.
function Show-Error {
	Write-Host $_ -ForegroundColor Red
}

# Throws if 'Not a git repository.'
function Assert-Git {
	[CmdletBinding()]param()
	$path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath('.')
	do {
		if (Test-Path -LiteralPath "$path\.git") {
			return
		}
	} while ($Path = Split-Path $Path)
	throw 'Not a git repository.'
}

# Decodes git strings with octets.
filter ConvertFrom-Octet {
	if (!$_.Contains('\')) {
		return $_
	}
	$bytes = [System.Collections.ArrayList]@()
	foreach($m in ([regex]'\\\d\d\d|.').Matches($_)) {
		$t = $m.ToString()
		if (($b = $t[0]) -eq '\') {
			$b = [Convert]::ToInt32($t.Substring(1), 8)
		}
		$null = $bytes.Add($b)
	}
	[System.Text.Encoding]::UTF8.GetString($bytes)
}

# Gets the current branch name.
function Get-BranchCurrent {
	Invoke-Native {git branch --show-current}
}

# Gets branch names except the current.
function Get-BranchOther {
	foreach($branch in Invoke-Native {git branch --list --quiet}) {
		if ($branch -notmatch '^(\*)?\s*(\S+)') {
			throw "Unexpected branch: '$branch'."
		}
		if (!$matches[1]) {
			$matches[2]
		}
	}
}

# Gets stash strings.
function Get-StashText {
	Invoke-Native {git stash list}
}

# Gets the stash name from a string.
function Get-StashName {
	[CmdletBinding()]
	param(
		$Stash
	)

	if ($Stash -notmatch '^(stash@{\d+})') {
		throw "Unexpected stash format: $Stash."
	}
	$matches[1]
}

# Shows the stash list and gets the selected stash name.
function Select-StashName {
	[CmdletBinding()]
	param(
		$Title
	)

	if (!($stash = Get-StashText)) {
		Show-FarMessage 'There are no stashes.'
		return
	}

	$stash = $stash | Out-FarList -Title $Title
	if (!$stash) {
		return
	}

	Get-StashName $stash
}
