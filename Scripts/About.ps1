$ErrorActionPreference=1
. $PSScriptRoot\Basic.ps1
. $PSScriptRoot\New-FGBranchExplorer.ps1
. $PSScriptRoot\New-FGStashExplorer.ps1

<#
.Synopsis
	Opens panel with git branches.

.Description
	The current git branch is shown with (*).
	Keys and actions:
		[Enter]
			Checkout the current panel branch.
			If it is remote then a new local branch is created.
		[F7]
			Checkout a new branch from the current git branch.
			The current panel branch does not matter.
			Enter a new branch name in the dialog.
		[F3]
			Open gitk with the current panel branch.
		[F6]
			Rename the current panel branch.
		[F8], [Del]
			Delete selected local and remote branches.
			Use [Shift..] to delete not merged local branches.
#>
function Open-FarGitBranch {
	[CmdletBinding()]
	param(
		[string]$Path = '.'
	)
	$Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
	$Root = Invoke-Error {git -C $Path rev-parse --show-toplevel}
	if ($LASTEXITCODE) {
		throw $Root
	}
	(New-FGBranchExplorer $Root).OpenPanel()
}

<#
.Synopsis
	Opens panel with git stashes.

.Description
	Keys and actions:
		[Enter]
			Apply the current stash with a choice:
			- [Apply] apply and keep the stash.
			- [Pop] apply and remove the stash.
		[F7]
			Stash current changes with a choice [Tracked] or [+Untracked]
			and the input box for the optional stash message.
		[F3]
			Open gitk to view the current stash.
		[F8], [Del]
			Delete selected stashes.
#>
function Open-FarGitStash {
	[CmdletBinding()]
	param(
		[string]$Path = '.'
	)
	$Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
	$Root = Invoke-Error {git -C $Path rev-parse --show-toplevel}
	if ($LASTEXITCODE) {
		throw $Root
	}
	(New-FGStashExplorer $Root).OpenPanel()
}

<#
.Synopsis
	Shows git help for the git command.

.Description
	The command shows HTML help the git command found in the editor, dialog, or
	command line. If 'git command' is not found then the main page is shown.
#>
function Show-FarGitHelp {
	if ($Far.Line.Text -match '\bgit\s+(\S+)') {
		$null = Invoke-Native {git ($matches[1]) --help}
	}
	else {
		Invoke-Item -LiteralPath "$(Invoke-Native {git --html-path})\index.html"
	}
}

<#
.Synopsis
	Opens the current config file in the editor.
#>
function Edit-FarGitConfig {
	try {
		Assert-Git

		$root = Invoke-Native {git rev-parse --git-dir}
		Open-FarEditor $root\config
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Sets the repository root current in the panel.
#>
function Set-FarGitRoot {
	try {
		Assert-Git

		$root = Invoke-Native {git rev-parse --show-toplevel}
		$Far.Panel.CurrentDirectory = $root
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Shows changed files and navigates to a selected.

.Description
	The command shows the list of changed files.
	Select a file to navigate to in the active panel.
#>
function Show-FarGitStatus {
	try {
		Assert-Git

		$info = Invoke-Native {git status --porcelain} | ConvertFrom-Octet | .{process{
			($_ -replace '^ ', '-') -replace '^(.) ', '$1-'
		}} | Out-FarList -Title "On branch $(Get-BranchCurrent)"
		if (!$info) {
			return
		}
		if ($info -notmatch '^(..)\s+"?(.+?)"?(?:\s+->\s+"?(.+?)"?)?$') {
			throw "Unexpected status format: $info"
		}
		$path = if ($matches[3]) {$matches[3]} else {$matches[2]}
		$Far.Panel.GoToPath("$(Invoke-Native {git rev-parse --show-toplevel})\$path")
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Switches to another branch.

.Description
	The command shows the branch list.
	Select a branch to be set the current.
	If there are no branches the command prompts to create a new branch.
#>
function Invoke-FarGitCheckoutBranch {
	try {
		Assert-Git

		if (!($branch = Get-BranchOther)) {
			if (0 -eq (Show-FarMessage 'No other branches. Create?' -Buttons YesNo)) {
				Invoke-FarGitBranchCreate
			}
			return
		}

		$branch = $branch | Out-FarList -Title "Switch from $(Get-BranchCurrent)"
		if ($branch) {
			Invoke-Native {git checkout $branch}
		}
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Merges another branch into the current.

.Description
	The command shows the branch list.
	Select a branch to merge into the current.
#>
function Invoke-FarGitMergeBranch {
	try {
		Assert-Git

		if (!($branch = Get-BranchOther)) {
			Show-FarMessage 'No other branches.'
			return
		}

		$branch = $branch | Out-FarList -Title "Merge to $(Get-BranchCurrent)"
		if ($branch) {
			Invoke-Native {git merge $branch}
		}
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Deletes another branch.

.Parameter Force
		Tells to delete a branch irrespective of its merged status.

.Description
	The command shows the branch list.
	Select a branch to be deleted.

	By default the branch must be fully merged in its upstream branch. Use the
	switch Force in order to delete a branch irrespective of its merged status.
#>
function Invoke-FarGitBranchDelete {
	[CmdletBinding()]
	param(
		[switch]$Force
	)
	try {
		Assert-Git

		if (!($branch = Get-BranchOther)) {
			Show-FarMessage 'No other branches.'
			return
		}

		$branch = $branch | Out-FarList -Title 'Delete branch'
		if (!$branch) {
			return
		}

		$message = if ($Force) {"Delete branch $branch (force)"} else {"Delete branch $branch"}
		if (0 -ne (Show-FarMessage $message -Buttons YesNo -IsWarning:$Force)) {
			return
		}
		if ($Force) {
			Invoke-Native {git branch -D $branch}
		}
		else {
			Invoke-Native {git branch -d $branch}
		}
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Creates a new branch and switches to it.

.Description
	The command shows the input box.
	Enter the new branch name and press enter.
#>
function Invoke-FarGitBranchCreate {
	try {
		Assert-Git

		$currentBranch = Get-BranchCurrent
		$newBranch = if (('main', 'master') -ccontains $currentBranch) {''} else {$currentBranch}
		$newBranch = $Far.Input('Branch name', 'GitBranch', "New branch from $currentBranch", $newBranch)
		if ($newBranch) {
			Invoke-Native {git checkout -b $newBranch}
		}
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Renames the current branch.

.Description
	The command shows the input box with the current branch name.
	Enter the new branch name and press enter.
#>
function Invoke-FarGitBranchRename {
	param (
		[switch]$DatePrefix
	)
	try {
		Assert-Git

		$currentBranch = Get-BranchCurrent
		$newBranch = if ($DatePrefix -and $currentBranch -notmatch '^\d\d\d\d\d\d-') {
			'{0:yyMMdd}-{1}' -f (Get-Date), $currentBranch
		}
		else {
			$currentBranch
		}

		$newBranch = $Far.Input('Branch name', 'GitBranch', "Rename branch $currentBranch", $newBranch)
		if ($newBranch) {
			Invoke-Native {git branch -m $newBranch}
		}
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Invokes git stash apply.

.Description
	The command shows the stash list.
	Select a stash to be applied.
#>
function Invoke-FarGitStashApply {
	try {
		Assert-Git

		if ($stash = Select-StashName 'Apply stash') {
			Invoke-Native {git stash apply $stash}
		}
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Invokes git stash drop.

.Description
	The command shows the stash list.
	Select a stash to be dropped.
#>
function Invoke-FarGitStashDrop {
	try {
		Assert-Git

		if ($stash = Select-StashName 'Drop stash') {
			Invoke-Native {git stash drop $stash}
		}
	}
	catch {
		Show-Error
	}
}

<#
.Synopsis
	Invokes git stash pop.

.Description
	The command shows the stash list.
	Select a stash to be popped.
#>
function Invoke-FarGitStashPop {
	try {
		Assert-Git

		if ($stash = Select-StashName 'Pop stash') {
			Invoke-Native {git stash pop $stash}
		}
	}
	catch {
		Show-Error
	}
}
