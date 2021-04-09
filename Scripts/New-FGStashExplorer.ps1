
function New-FGStashExplorer($Root) {
	New-Object PowerShellFar.PowerExplorer c3e2ab2d-2c19-48cf-af15-81d7646030b4 -Property @{
		Data = @{
			Root = $Root
		}
		Functions = 'CreateFile, DeleteFiles'
		AsCreateFile = {FGStashExplorer_AsCreateFile @args}
		AsCreatePanel = {FGStashExplorer_AsCreatePanel @args}
		AsDeleteFiles = {FGStashExplorer_AsDeleteFiles @args}
		AsGetFiles = {FGStashExplorer_AsGetFiles @args}
	}
}

function FGStashExplorer_AsCreatePanel($1) {
	$panel = [FarNet.Panel]$1
	$panel.Title = "Stashes: $($1.Data.Root)"
	$panel.ViewMode = 0
	$panel.SortMode = 'Unsorted'

	$cn = New-Object FarNet.SetColumn -Property @{ Kind = "N"; Name = "Name"; Width = 10 }
	$cd = New-Object FarNet.SetColumn -Property @{ Kind = "Z"; Name = "Description" }
	$mode = New-Object FarNet.PanelPlan
	$mode.Columns = $cn, $cd
	$panel.SetPlan(0, $mode)

	$panel.add_KeyPressed({
		### [Enter] apply/pop
		if ($_.Key.Is([FarNet.KeyCode]::Enter)) {
			$file = $this.CurrentFile
			if (!$file) {
				return
			}
			$_.Ignore = $true
			$Root = $this.Explorer.Data.Root
			$name = $file.Name
			$message = $file.Description
			$res = Show-FarMessage "$name : $message" Stash -Choices Apply, Pop, Cancel -LeftAligned
			$res = switch($res) {
				0 {
					Invoke-Error {git -C $Root stash apply $name}
				}
				1 {
					Invoke-Error {git -C $Root stash pop $name}
				}
				default {
					return
				}
			}
			if ($LASTEXITCODE) {
				throw $res
			}
			$this.Update($true)
			$this.Redraw()
			return
		}
		### [F3] gitk stash
		if ($_.Key.Is([FarNet.KeyCode]::F3)) {
			$files = $this.SelectedFiles
			if (!$files) {
				return
			}
			$names = @(foreach($_ in $files) {$_.Name})
			Push-Location -LiteralPath $this.Explorer.Data.Root
			gitk $names
			Pop-Location
			return
		}
	})

	$panel
}

function FGStashExplorer_AsGetFiles($1) {
	$Root = $1.Data.Root
	$res = Invoke-Error {git -C $Root stash list}
	if ($LASTEXITCODE) {
		throw $res
	}
	foreach($line in $res) {
		if ($line -notmatch '^(.+?):\s*(.+)') {
			New-FarFile -Name "Unexpected stash: '$line'"
			continue
		}
		$name = $matches[1]
		$message = $matches[2]
		New-FarFile -Name $name -Description $message
	}
}

function FGStashExplorer_AsCreateFile($1, $2) {
	$Root = $1.Data.Root
	$status = Invoke-Error {git -C $Root status -s}
	if ($LASTEXITCODE) {
		throw $status
	}
	if (!$status) {
		Show-FarMessage 'Nothing to stash.'
		return
	}
	$res = Show-FarMessage ($status | Out-String) Stash -Choices Tracked, +Untracked, Cancel -LeftAligned
	if (0..1 -notcontains $res) {
		return
	}
	$message = $Far.Input('Stash message (optional)', $null, 'Stash')
	if ($null -eq $message) {
		return
	}
	$param = @(
		'-C', $Root, 'stash', 'push'
		if ($res -eq 1) {
			'--include-untracked'
		}
		if ($message) {
			'--message', $message
		}
	)
	$err = Invoke-Error {git $param}
	if ($LASTEXITCODE) {
		$2.Result = 'Ignore'
		throw $err
	}
}

function FGStashExplorer_AsDeleteFiles($1, $2) {
	# ask
	if ($2.UI) {
		$text = @"
$($2.Files.Count) stash(es):
$($(foreach($_ in $2.Files) {"$($_.Name) : $($_.Description)"}) -join "`n")
"@
		if (Show-FarMessage $text Delete YesNo -LeftAligned) {
			$2.Result = 'Ignore'
			return
		}
	}

	# delete
	$Root = $1.Data.Root
	foreach($file in $2.Files) {
		$name = $file.Name
		$res = Invoke-Error {git -C $Root stash drop $name}
		if ($LASTEXITCODE) {
			$2.Result = 'Incomplete'
			$2.FilesToStay.Add($file)
			if ($2.UI) {
				Show-FarMessage "Error on stash drop $name`n$res" -Caption FarGit -LeftAligned -IsWarning
			}
		}
	}
}
