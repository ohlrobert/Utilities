# Make Windows Terminal run as Administrator by default and pin it to Start
# Run the script after every Windows Terminal update
# Inspired by https://lennybacon.com/posts/create-an-link-to-a-uwp-app-to-run-as-administrator/

Clear-Host

Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows Terminal*.lnk" -Force

$PackageFullName = (Get-AppxPackage -Name Microsoft.WindowsTerminal).PackageFullName

# Create a Windows Terminal shortcut
$Shell = New-Object -ComObject Wscript.Shell
$Shortcut = $Shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows Terminal.lnk")
$Shortcut.TargetPath = "powershell.exe"
$ShortCut.Arguments = "-WindowStyle Hidden -Command wt"
$ShortCut.IconLocation = "$env:ProgramFiles\WindowsApps\$PackageFullName\WindowsTerminal.exe"
$Shortcut.Save()

# Run the Windows Terminal shortcut as Administrator
[byte[]]$bytes = Get-Content -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows Terminal.lnk" -Encoding Byte -Raw
$bytes[0x15] = $bytes[0x15] -bor 0x20
Set-Content -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows Terminal.lnk" -Value $bytes -Encoding Byte -Force

$Parameters = @{
	Size = "2x2"
	Column = 0
	Row = 0
	AppID = "Microsoft.WindowsTerminal_8wekyb3d8bbwe!App"
}

# Valid columns to place tiles in
$ValidColumns = @(0, 2, 4)

[string]$StartLayoutNS = "http://schemas.microsoft.com/Start/2014/StartLayout"

# Add pre-configured hastable to XML
function Add-Tile
{
	param
	(
		[string]
		$Size,

		[int]
		$Column,

		[int]
		$Row,

		[string]
		$AppID
	)

	[string]$elementName = "start:Tile"
	[Xml.XmlElement]$Table = $xml.CreateElement($elementName, $StartLayoutNS)
	$Table.SetAttribute("Size", $Size)
	$Table.SetAttribute("Column", $Column)
	$Table.SetAttribute("Row", $Row)
	$Table.SetAttribute("AppUserModelID", $AppID)

	$Table
}

# Export the current Start layout
$StartLayout = "$PSScriptRoot\StartLayout.xml"
Export-StartLayout -Path $StartLayout -UseDesktopApplicationID

[xml]$XML = Get-Content -Path $StartLayout -Encoding UTF8 -Force

$Groups = $XML.LayoutModificationTemplate.DefaultLayoutOverride.StartLayoutCollection.StartLayout.Group

<#
if ($Groups)
{
	$AppUserModelID = ($Parameters).AppID

	if (-not ($Group.Tile | Where-Object -FilterScript {$_.AppUserModelID -eq $AppUserModelID}))
	{
		# Count childnodes to get the minimal tiles in a row
		$ChildNodesCount = New-Object -TypeName System.Collections.ArrayList($null)
		foreach ($Group in $Groups)
		{
			$ChildNodesCount += $Group.ChildNodes.Count
		}
		$Minimum = ($ChildNodesCount | Measure-Object -Minimum).Minimum | Select-Object -First 1

		# A necessary group
		$GroupMinimum = $XML.LayoutModificationTemplate.DefaultLayoutOverride.StartLayoutCollection.StartLayout.Group | Where-Object -FilterScript {$_.ChildNodes.Count -eq $Minimum} | Select-Object -First 1

		# Calculate current filled columns
		$CurrentColumns = New-Object -TypeName System.Collections.ArrayList($null)
		if ($GroupMinimum.Tile)
		{
			$CurrentColumns += @($GroupMinimum.Tile.Column)
		}
		if ($GroupMinimum.DesktopApplicationTile)
		{
			$CurrentColumns += @($GroupMinimum.DesktopApplicationTile.Column)
		}

		# Calculate current free columns and take the first one
		$Column = (Compare-Object -ReferenceObject $ValidColumns -DifferenceObject $CurrentColumns).InputObject | Select-Object -First 1
		# If filled cells contain necessary ones assign the first free cell
		if ($CurrentColumns -contains $Parameters.Column)
		{
			$Parameters.Column = $Column
		}
		$GroupMinimum.AppendChild((Add-Tile @Parameters)) | Out-Null
	}
}
else
{
	# Create a new group
	[Xml.XmlElement]$Groups = $XML.CreateElement("start:Group", $StartLayoutNS)
	$Groups.SetAttribute("Name","")
	$Groups.AppendChild((Add-Tile @Parameters)) | Out-Null
	$XML.LayoutModificationTemplate.DefaultLayoutOverride.StartLayoutCollection.StartLayout.AppendChild($Groups) | Out-Null
}
#>

# Create a new group
[Xml.XmlElement]$Groups = $XML.CreateElement("start:Group", $StartLayoutNS)
$Groups.SetAttribute("Name","")
$Groups.AppendChild((Add-Tile @Parameters)) | Out-Null
$XML.LayoutModificationTemplate.DefaultLayoutOverride.StartLayoutCollection.StartLayout.AppendChild($Groups) | Out-Null

$XML.Save($StartLayout)

# Temporarily disable changing the Start menu layout
if (-not (Test-Path -Path HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer))
{
	New-Item -Path HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer -Force
}
New-ItemProperty -Path HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer -Name LockedStartLayout -Value 1 -Force
New-ItemProperty -Path HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer -Name StartLayoutFile -Value $StartLayout -Force

Start-Sleep -Seconds 3

# Restart the Start menu
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction Ignore

Start-Sleep -Seconds 3

# Enable changing the Start menu layout
Remove-ItemProperty -Path HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer -Name LockedStartLayout -Force -ErrorAction Ignore
Remove-ItemProperty -Path HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer -Name StartLayoutFile -Force -ErrorAction Ignore

Remove-Item -Path $StartLayout -Force

Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction Ignore

Start-Sleep -Seconds 3
