if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Execute este script como Administrador."
    exit
}

$RecoverySizeMB = 750

$systemDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'GPT' -and $_.IsSystem }
if (-not $systemDisk) {
    Write-Error "Disco do sistema (GPT) não encontrado."
    exit
}
$diskNumber = $systemDisk.Number

# Usa LargestFreeExtent para verificar espaço não alocado
$unallocated = ($systemDisk | Select-Object -ExpandProperty LargestFreeExtent)
if ($unallocated -lt ($RecoverySizeMB * 1MB)) {
    Write-Error "Espaço não alocado insuficiente no disco $diskNumber. É necessário pelo menos $RecoverySizeMB MB livre."
    exit
}

$newPartition = New-Partition -DiskNumber $diskNumber -Size ($RecoverySizeMB * 1MB) -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -AssignDriveLetter
$driveLetter = $newPartition.DriveLetter
if (-not $driveLetter) {
    Write-Error "Não foi possível atribuir letra à nova partição."
    exit
}

Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel "Recovery" -Confirm:$false | Out-Null

$reInfo = reagentc /info | Out-String

# Tenta extrair o caminho do Windows RE
if ($reInfo -match "Windows RE location:\s+(.*)") {
    $winrePath = $matches[1].Trim()
} else {
    $winrePath = ""
}

# Caso Windows RE desativado ou sem caminho válido, usar winre.wim padrão
if (($reInfo -match "Windows RE status:\s+Disabled") -or [string]::IsNullOrEmpty($winrePath)) {
    $winreWimPath = "C:\Windows\System32\Recovery\Winre.wim"
    if (-not (Test-Path $winreWimPath)) {
        Write-Error "Arquivo padrão do WinRE não encontrado em $winreWimPath"
        exit
    }
    $targetPath = "$driveLetter`:\Recovery\WindowsRE"
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    Copy-Item $winreWimPath -Destination "$targetPath\Winre.wim" -Force
} else {
    if (-not (Test-Path $winrePath)) {
        Write-Error "Caminho físico do WinRE não encontrado: $winrePath"
        exit
    }
    $targetPath = "$driveLetter`:\Recovery\WindowsRE"
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    Copy-Item "$winrePath\*" $targetPath -Recurse -Force
}

# Remove a letra da unidade para esconder a partição
Remove-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $newPartition.PartitionNumber -AccessPath "$driveLetter`:\" -Confirm:$false

# Define os atributos corretos da partição via Diskpart
$diskpartScript = @"
select disk $diskNumber
select partition $($newPartition.PartitionNumber)
set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
gpt attributes=0x8000000000000001
exit
"@

$scriptPath = "$env:TEMP\diskpart_recovery.txt"
$diskpartScript | Out-File -FilePath $scriptPath -Encoding ASCII
diskpart /s $scriptPath | Out-Null
Remove-Item $scriptPath -Force

# Configura o Windows RE para apontar para a nova partição
reagentc /disable | Out-Null
reagentc /setreimage /path "\Recovery\WindowsRE" /target C:\Windows | Out-Null
reagentc /enable | Out-Null

reagentc /info
