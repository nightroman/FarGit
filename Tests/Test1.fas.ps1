
# New branch to create, use a name sorted after 'main', e.g. 'test_*'.
# Use new names because a test may fail and leave old branches.
# If a test finishes then all branches but main are deleted.
$Data.Branch = "test_$([DateTime]::Now.ToString('yyMMdd_HHmmss'))"

# Waits for description tasks.
function Wait-It {Start-Sleep 2}

### open the test repo branch panel

job {
	# keep the current panel directory to restore
	$Data.CurrentDirectory = $Far.Panel.CurrentDirectory

	# setup the repo
	Import-Module $PSScriptRoot\Base
	Install-Repo

	# change to repo for a future typed command there
	$Far.Panel.CurrentDirectory = Get-Repo

	# open the branch panel
	Open-FarGitBranch
}

Wait-It
job {
	Assert-Far -FileName main -FileOwner * -FileDescription start
}

### create a new branch from main

keys F7
job {
	Assert-Far -Dialog
	Assert-Far $Far.Dialog[0].Text -eq 'New branch from main'

	$Far.Dialog[2].Text = $Data.Branch
}
keys Enter

Wait-It
job {
	Find-FarFile $Data.Branch
	Assert-Far -FileOwner * -FileDescription start
}

### exit/modify/open -> the new branch is current with `>`

keys Esc

job {
	Assert-Far -Native
	Set-Content README.md $Data.Branch
	Open-FarGitBranch
}

Wait-It
job {
	Assert-Far -FileName $Data.Branch -FileOwner '>' -FileDescription start
}

### commit and run a command to trigger panel update

job {
	$null = git commit --all --message test 2>$1
}
keys g i t Space s t a t u s Space - s b Enter

Wait-It
job {
	Assert-Far -FileName $Data.Branch -FileOwner * -FileDescription test
}

### rename the branch

keys ShiftF6

job {
	Assert-Far -Dialog
	Assert-Far $Far.Dialog[0].Text -eq 'Rename branch'
	Assert-Far $Far.Dialog[2].Text -eq $Data.Branch
	$Far.Dialog[2].Text = $Data.Branch + '_renamed'
	$Far.Dialog.Close()
}

job {
	Assert-Far -FileName ($Data.Branch + '_renamed')
}

### go to main and set the branch current

job {
	Find-FarFile main
	Assert-Far -FileOwner $null -FileDescription start
}

keys Enter

Wait-It
job {
	Assert-Far -FileName main -FileOwner * -FileDescription start
}

### select all but main and force delete

run {
	$Far.Panel.SelectAll()
	$Far.Panel.UnselectAt(0)
}

keys ShiftDel

job {
	Assert-Far -Dialog
	Assert-Far $Far.Dialog[0].Text -eq Delete
	Assert-Far ($Far.Dialog[1].Text -like '* branch(es):')
}

keys Enter

Wait-It
job {
	Assert-Far $Far.Panel.ShownFiles.Count -eq 1
	Assert-Far -FileName main -FileOwner * -FileDescription start
}

### exit and restore

job {
	$Far.Panel.Close()
	$Far.Panel.CurrentDirectory = $Data.CurrentDirectory
}
