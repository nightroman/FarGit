
function New-FGStashExplorer($Root) {
	$Explorer = [PowerShellFar.PowerExplorer]::new("c3e2ab2d-2c19-48cf-af15-81d7646030b4")
	$Explorer.Data = @{
		Root = $Root
	}
	$Explorer.Functions = 'CreateFile, DeleteFiles'
	$Explorer.AsCreateFile = {FGStashExplorer_AsCreateFile @args}
	$Explorer.AsCreatePanel = {FGStashExplorer_AsCreatePanel @args}
	$Explorer.AsDeleteFiles = {FGStashExplorer_AsDeleteFiles @args}
	$Explorer.AsGetFiles = {FGStashExplorer_AsGetFiles @args}
	$Explorer
}

function FGStashExplorer_AsCreatePanel($Explorer) {
	$panel = [FarNet.Panel]$Explorer
	$panel.Title = "Stashes: $($Explorer.Data.Root)"
	$panel.ViewMode = 0
	$panel.SortMode = 'Unsorted'

	$cn = [FarNet.SetColumn]@{ Kind = "N"; Name = "Name"; Width = 10 }
	$cd = [FarNet.SetColumn]@{ Kind = "Z"; Name = "Description" }
	$plan0 = [FarNet.PanelPlan]::new()
	$plan0.Columns = $cn, $cd
	$panel.SetPlan(0, $plan0)

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

function FGStashExplorer_AsGetFiles($Explorer) {
	$Root = $Explorer.Data.Root
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

function FGStashExplorer_AsCreateFile($Explorer, $2) {
	$Root = $Explorer.Data.Root
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

function FGStashExplorer_AsDeleteFiles($Explorer, $2) {
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
	$Root = $Explorer.Data.Root
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
