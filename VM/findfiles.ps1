# Script generated by Jaap Brasser, J.R. Phillips and Steffen Politzky (July 2018)
# To run the script you need to install the rubrik PS module from github
# Customize the "param" section below
# Examples:
# Run the script to search over all VM's (take much longer):
# .\findfiles -Q <filename> 
# or search only a subset of VM's (use of wildcard * after the VM name):
# .\findfiles -Q <filename> -VM <vmname*>
# First run will ask for the credentials and store it encrypted in a file. To re-enable the password question just delete the rubrik.cred file in the user directory.


# Set defaults below
#############################################################################
param(
    [Alias('U')]
        [string] $User,
    [Alias('P')]
        [securestring] $Password,
    [Alias('S')]
        [string] $Server = '172.17.28.31',
    [Alias('Q')]
        [string] $SearchQuery = 'hosts',
    [Alias('VM')]
        [string] $VMName = 'SE-*'
)

# End defaults
##############################################################################

# Test if the file rubrik.cred exist and ask for creds if not
try {
$MyCredential = Import-CliXml -Path "${env:\userprofile}\rubrik.cred"
}
catch
{
$MyCredential = Get-Credential
$MyCredential | Export-CliXml -Path "${env:\userprofile}\rubrik.cred"
}

# Search in each VM for the search string
function Find-RubrikVMFile {
    param(
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [String]$Id,
        [parameter(Mandatory)]
        [string]$searchstring
    )
    $endpointURI = 'vmware/vm/' + $Id + '/search?path=' + $SearchString
    $jobstats = (Invoke-RubrikRESTCall -Endpoint $endpointURI -Method GET)
	if ($jobstats.data) {
        $vmname = (get-rubrikvm -id $Id).name
			foreach ($i in $jobstats.data) {
            $snapshotid = $i.fileVersions.snapshotid
            $snapshots = Get-RubrikSnapshot -id $id
            $snapshotdates = foreach ($s in $snapshotid) {$snapshots | Where-Object {$_.id -eq $s} | Select-Object date}
            $o = New-Object PSObject
            $o | Add-Member -Name 'VMName' -type noteproperty -Value $vmname
            $o | Add-Member -Name 'FileName' -type noteproperty -Value $i.filename
            $o | Add-Member -Name 'FilePath' -type noteproperty -Value $i.path
            $o | Add-Member -Name 'SnapshotDates' -type noteproperty -Value $snapshotdates
            $o
        }
        
    }
}

# Connect to the cluster
try {
	Connect-Rubrik -Server $Server -Credential $MyCredential | Out-Null 
	Write-Host "`nYou are now connected to Rubrik cluster:  " -NoNewline
	Write-Host $Server -ForegroundColor Cyan
	}
catch {
	throw "Error connecting to Rubrik"
	}
		
Write-Host "`nSearch can take several minutes depending on the amount of VM's. Please wait..."		

# Filter VM names and genereate a progress bar
$AllSystem = Get-RubrikVM | Where-Object {$_.Name -like $VMName}
for ($i = 0; $i -lt $AllSystem.Count; $i++) { 
    Write-Progress -Activity ('Searching for files in {0}, VM {1} out of {2}' -f $AllSystem[$i].Name,$i,$AllSystem.Count) -PercentComplete ($i / $allsystem.count * 100)  -Status 'In Progress'
    $AllSystem[$i] | Find-RubrikVMFile -SearchString $SearchQuery
}

Write-Host "`nDone..."
#End script