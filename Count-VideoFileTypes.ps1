param (
    [Parameter(Mandatory=$true)]
    [string]$FolderPath
)

# Verify the path exists
if (-not (Test-Path -Path $FolderPath)) {
    Write-Error "The path '$FolderPath' does not exist."
    exit
}

# Recursively get all files, group by extension, sort, and output as a table
Get-ChildItem -Path $FolderPath -File -Recurse | 
    Group-Object -Property Extension | 
    Select-Object @{Name="Extension"; Expression={if([string]::IsNullOrWhiteSpace($_.Name)) { "<No Extension>" } else { $_.Name }}}, Count | 
    Sort-Object -Property Count -Descending | 
    Format-Table -AutoSize
