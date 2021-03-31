<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build
#>

Set-StrictMode -Version 2
$ModuleName = 'FarGit'

# Synopsis: Remove temp files.
task clean {
	remove z
}

# Synopsis: Set $script:Version.
task version {
	($script:Version = switch -Regex -File Release-Notes.md {'##\s+v(\d+\.\d+\.\d+)' {$Matches[1]; break} })
}

# Synopsis: Make the module in z\$ModuleName.
task module version, {
	remove z
	$null = mkdir z\$ModuleName\Scripts

	# root
	Copy-Item -Destination z\$ModuleName -LiteralPath $(
		"about_$ModuleName.help.txt"
		"$ModuleName.psd1"
		"$ModuleName.psm1"
		'LICENSE'
	)

	# scripts
	Copy-Item -Destination z\$ModuleName\Scripts -Path $(
		'Scripts\*'
	)

	# set module version
	Import-Module PsdKit
	$xml = Import-PsdXml z\$ModuleName\$ModuleName.psd1
	Set-Psd $xml $Version 'Data/Table/Item[@Key="ModuleVersion"]'
	Export-PsdXml z\$ModuleName\$ModuleName.psd1 $xml
}

# Synopsis: Push PSGallery module.
task pushPSGallery module, {
	$NuGetApiKey = Read-Host NuGetApiKey
	Publish-Module -Path z\$ModuleName -NuGetApiKey $NuGetApiKey
},
clean
