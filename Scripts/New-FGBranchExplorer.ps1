
function New-FGBranchExplorer($Root) {
	$Explorer = [PowerShellFar.PowerExplorer]::new("71ebb500-c8e1-4544-827a-8456c3611f8e")
	$Explorer.Data = @{
		Root = $Root
		SetCurrentOnce = $true
		FileDescriptions = @{}
	}
	$Explorer.Functions = 'CreateFile, DeleteFiles, RenameFile'
	$Explorer.AsCreateFile = {FGBranchExplorer_AsCreateFile @args}
	$Explorer.AsCreatePanel = {FGBranchExplorer_AsCreatePanel @args}
	$Explorer.AsDeleteFiles = {FGBranchExplorer_AsDeleteFiles @args}
	$Explorer.AsGetFiles = {FGBranchExplorer_AsGetFiles @args}
	$Explorer.AsRenameFile = {FGBranchExplorer_AsRenameFile @args}
	$Explorer
}

function FGBranchExplorer_AsCreatePanel($Explorer) {
	$panel = [FarNet.Panel]$Explorer
	$panel.Title = "Branches: $($Explorer.Data.Root)"
	$panel.ViewMode = 0
	$panel.SortMode = 'Unsorted'
	$Explorer.Data.Panel = $panel

	$co = [FarNet.SetColumn]@{ Kind = "O"; Name = "Current"; Width = 1 }
	$cn = [FarNet.SetColumn]@{ Kind = "N"; Name = "Branch" }
	$cd = [FarNet.SetColumn]@{ Kind = "Z"; Name = "Commit" }

	$plan0 = [FarNet.PanelPlan]::new()
	$plan0.Columns = $co, $cn, $cd
	$panel.SetPlan(0, $plan0)

	$plan1 = $plan0.Clone()
	$plan1.IsFullScreen = $true
	$panel.SetPlan(9, $plan1)

	$panel.add_KeyPressed({
		### [Enter] checkout branch
		if ($_.Key.Is([FarNet.KeyCode]::Enter)) {
			$_.Ignore = $true
			$file = $this.CurrentFile

			# skip the current branch
			if (!$file -or $file.Owner) {
				return
			}

			$name = $file.Name
			if ($name.StartsWith('remotes/')) {
				$res = Invoke-Error {git -C $this.Explorer.Data.Root checkout -t $name}
			}
			else {
				$res = Invoke-Error {git -C $this.Explorer.Data.Root checkout $name}
			}
			if ($LASTEXITCODE) {
				throw $res
			}

			$this.Update($true)
			$this.Redraw()
			return
		}
		### [F3] gitk branch
		if ($_.Key.Is([FarNet.KeyCode]::F3)) {
			$_.Ignore = $true
			$file = $this.CurrentFile

			# skip the detached branch
			if (!$file -or $file.Name -like '(*)') {
				return
			}

			Push-Location -LiteralPath $this.Explorer.Data.Root
			gitk $file.Name
			Pop-Location
			return
		}
	})

	$panel
}

function FGBranchExplorer_AsGetFiles($Explorer) {
	# use and drop files prepared by the task
	if ($Explorer.Data.Files) {
		$Explorer.Data.Files
		$Explorer.Data.Files = $null
		return
	}

	# get git branches
	$res = Invoke-Error {git -C $Explorer.Data.Root branch -a --list --quiet}
	if ($LASTEXITCODE) {
		throw $res
	}

	# make files, use cached descriptions to avoid blanks in some cases
	$Files = [System.Collections.Generic.List[object]]@()
	foreach($line in $res) {
		if ($line.Contains('->')) {
			continue
		}
		if ($line -notmatch '^(\*)?\s*(.+)') {
			continue
		}
		$name = $Matches[2]
		$file = New-FarFile -Name $name -Description $Explorer.Data.FileDescriptions[$name]
		if ($Matches[1]) {
			# mark current branch
			if (Invoke-Error {git status -s}) {
				$file.Owner = '>'
			}
			else {
				$file.Owner = '*'
			}

			# set current panel file
			if ($Explorer.Data.SetCurrentOnce) {
				$Explorer.Data.Panel.PostName($name)
				$Explorer.Data.SetCurrentOnce = $false
			}
		}
		$Files.Add($file)
	}
	$Files

	# get descriptions, skip remotes and detached branches
	Start-FarTask -Data Explorer, Files {
		. $PSScriptRoot\Basic.ps1
		foreach($file in $Data.Files) {
			if ($file.Name -notlike 'remotes/*' -and $file.Name -notlike '(*)') {
				$description = Invoke-Error {git -C $Data.Explorer.Data.Root log --pretty=format:%s -1 $file.Name}
				$file.Description = $description
				$Data.Explorer.Data.FileDescriptions[$file.Name] = $description
			}
		}
		job {
			$Data.Explorer.Data.Files = $Data.Files
			$Data.Explorer.Data.Panel.Update($true)
			$Data.Explorer.Data.Panel.Redraw()
		}
	}
}

function FGBranchExplorer_AsCreateFile($Explorer, $2) {
	$oldBranch = Invoke-Error {git -C $Explorer.Data.Root branch --show-current}
	if ($LASTEXITCODE) {
		throw $oldBranch
	}

	$newBranch = $Far.Input('New branch name', 'GitBranch', "New branch from $oldBranch")
	if (!$newBranch) {
		$2.Result = 'Ignore'
		return
	}

	$res = Invoke-Error {git -C $Explorer.Data.Root checkout -b $newBranch}
	if ($LASTEXITCODE) {
		$2.Result = 'Ignore'
		Show-FarMessage "Error on create branch $newBranch`n$res" -Caption FarGit -LeftAligned -IsWarning
	}
}

function FGBranchExplorer_AsDeleteFiles($Explorer, $2) {
	# ask
	if ($2.UI) {
		$text = @"
$($2.Files.Count) branch(es):
$($2.Files -join "`n")
"@
		if (Show-FarMessage $text Delete YesNo -LeftAligned) {
			$2.Result = 'Ignore'
			return
		}
	}

	# delete
	foreach($file in $2.Files) {
		$branch = $file.Name
		$remote = ''
		if ($branch -match '^remotes/(?<remote>[^/]+)/(?<branch>.+)') {
			$branch = $Matches.branch
			$remote = $Matches.remote
		}
		$res = Invoke-Error {
			if ($remote) {
				git -C $Explorer.Data.Root push $remote --delete $branch
			}
			elseif ($2.Force) {
				git -C $Explorer.Data.Root branch -D $branch
			}
			else {
				git -C $Explorer.Data.Root branch -d $branch
			}
			$Explorer.Data.FileDescriptions.Remove($branch)
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

function FGBranchExplorer_AsRenameFile($Explorer, $2) {
	$oldName = $2.File.Name
	$newName = ([string]$Far.Input('New branch name', 'GitBranch', 'Rename branch', $oldName)).Trim()
	if (!$newName) {
		$2.Result = 'Ignore'
		return
	}
	$res = Invoke-Error {git -C $Explorer.Data.Root branch -m $oldName $newName}
	if ($LASTEXITCODE) {
		$2.Result = 'Ignore'
		Show-FarMessage "Error on rename branch $oldName to $newName`n$res" -Caption FarGit -LeftAligned -IsWarning
	}
	else {
		$2.PostName = $newName
		$Explorer.Data.FileDescriptions.Remove($oldName)
	}
}
