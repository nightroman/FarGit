
function New-FGBranchExplorer($Root) {
	New-Object PowerShellFar.PowerExplorer 71ebb500-c8e1-4544-827a-8456c3611f8e -Property @{
		Data = @{
			Root = $Root
		}
		Functions = 'CreateFile, DeleteFiles, RenameFile'
		AsCreateFile = {FGBranchExplorer_AsCreateFile @args}
		AsCreatePanel = {FGBranchExplorer_AsCreatePanel @args}
		AsDeleteFiles = {FGBranchExplorer_AsDeleteFiles @args}
		AsGetFiles = {FGBranchExplorer_AsGetFiles @args}
		AsRenameFile = {FGBranchExplorer_AsRenameFile @args}
	}
}

function FGBranchExplorer_AsCreatePanel($1) {
	$panel = [FarNet.Panel]$1
	$panel.Title = "Branches: $($1.Data.Root)"
	$panel.ViewMode = 0
	$panel.SortMode = 'Unsorted'

	$cn = New-Object FarNet.SetColumn -Property @{ Kind = "N"; Name = "Name" }
	$co = New-Object FarNet.SetColumn -Property @{ Kind = "O"; Name = "Current"; Width = 1 }
	$mode = New-Object FarNet.PanelPlan
	$mode.Columns = $co, $cn
	$panel.SetPlan(0, $mode)
	$panel
}

function FGBranchExplorer_AsGetFiles($1) {
	$Root = $1.Data.Root
	$res = Invoke-Error {git -C $Root branch -a --list --quiet}
	if ($LASTEXITCODE) {
		throw $res
	}
	foreach($line in $res) {
		if ($line -notmatch '^(\*)?\s*(\S+)') {
			New-FarFile -Name "Unexpected branch: '$line'"
			continue
		}
		$name = $matches[2]
		$isHidden = $name.Contains('/')
		if ($matches[1]) {
			New-FarFile -Name $name -Owner *
		}
		elseif ($isHidden) {
			New-FarFile -Name $name -Attributes Hidden
		}
		else {
			New-FarFile -Name $name
		}
	}
}

function FGBranchExplorer_AsCreateFile($1, $2) {
	$Root = $1.Data.Root
	$oldBranch = Invoke-Error {git -C $Root branch --show-current}
	if ($LASTEXITCODE) {
		throw $oldBranch
	}
	$newBranch = $Far.Input('New branch name', 'GitBranch', "New branch from $oldBranch")
	if (!$newBranch) {
		$2.Result = 'Ignore'
		return
	}
	$res = Invoke-Error {git -C $Root checkout -b $newBranch}
	if ($LASTEXITCODE) {
		$2.Result = 'Ignore'
		Show-FarMessage "Error on create branch $newBranch`n$res" -Caption FarGit -LeftAligned -IsWarning
	}
}

function FGBranchExplorer_AsDeleteFiles($1, $2) {
	# ask
	if ($2.UI) {
		$text = @"
$($2.Files.Count) branch(es):
$($2.Files[0..9] -join "`n")
"@
		if (Show-FarMessage $text Delete YesNo -LeftAligned) {
			$2.Result = 'Ignore'
			return
		}
	}

	# delete
	$Root = $1.Data.Root
	foreach($file in $2.Files) {
		$branch = $file.Name
		$res = Invoke-Error {
			if ($2.Force) {
				git -C $Root branch -D $branch
			}
			else {
				git -C $Root branch -d $branch
			}
		}
		if ($LASTEXITCODE) {
			$2.Result = 'Incomplete'
			$2.FilesToStay.Add($file)
			if ($2.UI) {
				Show-FarMessage "Error on delete branch $branch`n$res" -Caption FarGit -LeftAligned -IsWarning
			}
		}
	}
}

function FGBranchExplorer_AsRenameFile($1, $2) {
	$Root = $1.Data.Root
	$oldName = $2.File.Name
	$newName = ([string]$Far.Input('New branch name', 'GitBranch', 'Rename branch', $oldName)).Trim()
	if (!$newName) {
		$2.Result = 'Ignore'
		return
	}
	$res = Invoke-Error {git -C $Root branch -m $oldName $newName}
	if ($LASTEXITCODE) {
		$2.Result = 'Ignore'
		Show-FarMessage "Error on rename branch $oldName to $newName`n$res" -Caption FarGit -LeftAligned -IsWarning
	}
	else {
		$2.PostName = $newName
	}
}
