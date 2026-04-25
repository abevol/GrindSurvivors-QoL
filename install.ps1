<#
.SYNOPSIS
    GrindSurvivors-QoL Mod Collection Installer / 模组合集安装器
.DESCRIPTION
    Auto-installs UE4SS mod framework and all GrindSurvivors-QoL mods.
    自动安装 UE4SS 模组框架和所有 GrindSurvivors-QoL 模组。
.NOTES
    Requires: PowerShell 5.1+, Windows 10+
    Repository: https://github.com/abevol/GrindSurvivors-QoL
#>

# ===== 1. Environment Initialization / 环境初始化 =====
function Initialize-Environment {
    $ErrorActionPreference = 'Stop'
    # Set TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Set console encoding to UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

# ===== 2. Language Detection & Message Dictionary / 语言检测与消息字典 =====
$script:Lang = if ((Get-Culture).Name -like 'zh-*') { 'zh' } else { 'en' }

$script:ProxyList = @(
    "",                                  # Direct GitHub
    "https://ghfast.top/",               # Proxy 1
    "https://gh-proxy.com/",             # Proxy 2
    "https://github.moeyy.xyz/",         # Proxy 3
    "https://ghproxy.net/"               # Proxy 4
)

$script:Msg = @{
    'Welcome'                = @{ 'en' = 'GrindSurvivors-QoL Mod Collection Installer'; 'zh' = 'GrindSurvivors-QoL 模组合集安装器' }
    'WelcomeDesc'            = @{ 'en' = 'This script will install UE4SS and all GrindSurvivors-QoL mods for Grind Survivors.'; 'zh' = '此脚本将为 Grind Survivors 安装 UE4SS 模组框架和所有 GrindSurvivors-QoL 模组。' }
    'StepFindGame'           = @{ 'en' = '[Step 1/3] Finding game installation directory...'; 'zh' = '[步骤 1/3] 正在查找游戏安装目录...' }
    'StepDownloadUE4SS'      = @{ 'en' = '[Step 2/3] Downloading UE4SS mod framework...'; 'zh' = '[步骤 2/3] 正在下载 UE4SS 模组框架...' }
    'StepInstallMods'        = @{ 'en' = '[Step 3/3] Installing all mods...'; 'zh' = '[步骤 3/3] 正在安装所有模组...' }
    'FoundGameDir'           = @{ 'en' = 'Found game directory: {0}'; 'zh' = '找到游戏目录：{0}' }
    'GameDirNotFound'        = @{ 'en' = 'Could not automatically find the game directory.'; 'zh' = '无法自动查找游戏安装目录。' }
    'SelectExePrompt'        = @{ 'en' = 'Please select the game executable file (GrindSurvivors-Win64-Shipping.exe).'; 'zh' = '请选择游戏可执行文件（GrindSurvivors-Win64-Shipping.exe）。' }
    'UserCancelled'          = @{ 'en' = 'Operation cancelled by user.'; 'zh' = '用户取消了操作。' }
    'InvalidExe'             = @{ 'en' = 'The selected file is not GrindSurvivors-Win64-Shipping.exe.'; 'zh' = '选择的文件不是 GrindSurvivors-Win64-Shipping.exe。' }
    'Downloading'            = @{ 'en' = 'Downloading'; 'zh' = '正在下载' }
    'DownloadingFile'        = @{ 'en' = 'Downloading file...'; 'zh' = '正在下载文件...' }
    'DownloadProgress'       = @{ 'en' = '{0:F1} MB / {1:F1} MB ({2}%)'; 'zh' = '{0:F1} MB / {1:F1} MB ({2}%)' }
    'DownloadComplete'       = @{ 'en' = 'Download complete: {0}'; 'zh' = '下载完成：{0}' }
    'DownloadFailed'         = @{ 'en' = 'Download failed: {0}'; 'zh' = '下载失败：{0}' }
    'DownloadFailedAllSources' = @{ 'en' = 'All download sources failed. Please check your network connection.'; 'zh' = '所有下载源均失败，请检查网络连接。' }
    'TryingSource'           = @{ 'en' = 'Trying download source {0}/{1}...'; 'zh' = '正在尝试下载源 {0}/{1}...' }
    'TryingDirectSource'     = @{ 'en' = 'Trying direct connection to GitHub...'; 'zh' = '正在尝试直连 GitHub...' }
    'TryingProxySource'      = @{ 'en' = 'Trying proxy: {0}'; 'zh' = '正在尝试加速源：{0}' }
    'VerifyingFile'          = @{ 'en' = 'Verifying file integrity...'; 'zh' = '正在验证文件完整性...' }
    'VerifyFailed'           = @{ 'en' = 'File integrity verification failed. Expected: {0}, Got: {1}'; 'zh' = '文件完整性验证失败。预期：{0}，实际：{1}' }
    'VerifyPassed'           = @{ 'en' = 'File integrity verification passed.'; 'zh' = '文件完整性验证通过。' }
    'UE4SSAlreadyInstalled'  = @{ 'en' = 'UE4SS is already installed. Reinstall/Update? [Y/n]'; 'zh' = 'UE4SS 已安装。是否重新安装/更新？[Y/n]' }
    'UE4SSSkipped'           = @{ 'en' = 'Skipped UE4SS installation.'; 'zh' = '已跳过 UE4SS 安装。' }
    'BackingUpConfig'        = @{ 'en' = 'Backing up existing configuration...'; 'zh' = '正在备份现有配置...' }
    'RestoringConfig'        = @{ 'en' = 'Restoring configuration...'; 'zh' = '正在恢复配置...' }
    'InstallingUE4SS'        = @{ 'en' = 'Installing UE4SS...'; 'zh' = '正在安装 UE4SS...' }
    'Extracting'             = @{ 'en' = 'Extracting files...'; 'zh' = '正在解压文件...' }
    'UE4SSInstallComplete'   = @{ 'en' = 'UE4SS installation complete.'; 'zh' = 'UE4SS 安装完成。' }
    'InstallingMod'          = @{ 'en' = 'Installing mod: {0}'; 'zh' = '正在安装模组：{0}' }
    'ModInstallComplete'     = @{ 'en' = 'Mod installation complete: {0}'; 'zh' = '模组安装完成：{0}' }
    'ModRegistered'          = @{ 'en' = 'Mod registered in mods.txt successfully: {0}'; 'zh' = '模组已成功注册到 mods.txt：{0}' }
    'InstallingShared'       = @{ 'en' = 'Installing shared libraries...'; 'zh' = '正在安装共享库...' }
    'SharedInstallComplete'  = @{ 'en' = 'Shared libraries installed.'; 'zh' = '共享库安装完成。' }
    'AllComplete'            = @{ 'en' = 'All installations completed successfully! You can now launch the game.'; 'zh' = '所有安装已成功完成！现在可以启动游戏了。' }
    'PressEnterToExit'       = @{ 'en' = 'Press Enter to exit...'; 'zh' = '按 Enter 键退出...' }
    'ErrorOccurred'          = @{ 'en' = 'An error occurred: {0}'; 'zh' = '发生错误：{0}' }
    'CleaningUp'             = @{ 'en' = 'Cleaning up temporary files...'; 'zh' = '正在清理临时文件...' }
    'FetchingReleaseInfo'    = @{ 'en' = 'Fetching UE4SS release information...'; 'zh' = '正在获取 UE4SS 发布信息...' }
    'ReleaseInfoFound'       = @{ 'en' = 'Found: {0} ({1:F1} MB)'; 'zh' = '找到：{0}（{1:F1} MB）' }
    'ReleaseInfoFailed'      = @{ 'en' = 'Failed to fetch UE4SS release information.'; 'zh' = '获取 UE4SS 发布信息失败。' }
    'APIRateLimited'         = @{ 'en' = 'GitHub API rate limit reached. Please wait a few minutes and try again.'; 'zh' = 'GitHub API 请求频率超限，请等待几分钟后重试。' }
    'RemovingOldMod'         = @{ 'en' = 'Removing old mod files: {0}'; 'zh' = '正在移除旧模组文件：{0}' }
    'CopyingMod'             = @{ 'en' = 'Copying {0}...'; 'zh' = '正在复制 {0}...' }
    'NoModsFound'            = @{ 'en' = 'No mods found in the Mods directory.'; 'zh' = '在 Mods 目录中未找到任何模组。' }
    'ModsFound'              = @{ 'en' = 'Found {0} mod(s) to install.'; 'zh' = '找到 {0} 个要安装的模组。' }
}

function Get-Msg([string]$Key) {
    return $script:Msg[$Key][$script:Lang]
}

# ===== 3. Helper Functions / 辅助函数 =====

function Find-GameDirectory {
    # Try registry first
    $muiCachePath = "Registry::HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    $targetSuffix = "\Grind Survivors\GrindSurvivors\Binaries\Win64\GrindSurvivors-Win64-Shipping.exe.FriendlyAppName"

    try {
        $muiCache = Get-Item -Path $muiCachePath -ErrorAction Stop
        foreach ($valueName in $muiCache.GetValueNames()) {
            if ($valueName.EndsWith($targetSuffix, [System.StringComparison]::OrdinalIgnoreCase)) {
                # Strip ".FriendlyAppName" to get exe path, then get parent directory
                $exePath = $valueName.Substring(0, $valueName.Length - ".FriendlyAppName".Length)
                $win64Dir = Split-Path -Parent $exePath

                # Validate path exists on disk
                if (Test-Path (Join-Path $win64Dir "GrindSurvivors-Win64-Shipping.exe")) {
                    return $win64Dir
                }
            }
        }
    }
    catch {
        # Registry key not found or access denied — fall through to file picker
    }

    # Fallback: file picker dialog
    return Select-GameExecutable
}

function Select-GameExecutable {
    Write-Host (Get-Msg 'GameDirNotFound') -ForegroundColor DarkYellow
    Write-Host (Get-Msg 'SelectExePrompt')

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = Get-Msg 'SelectExePrompt'
    $dialog.Filter = "Game Executable (GrindSurvivors-Win64-Shipping.exe)|GrindSurvivors-Win64-Shipping.exe|All Files (*.*)|*.*"
    $dialog.CheckFileExists = $true

    $result = $dialog.ShowDialog()

    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        throw (Get-Msg 'UserCancelled')
    }

    $selectedFile = $dialog.FileName
    $fileName = [System.IO.Path]::GetFileName($selectedFile)
    if ($fileName -ne "GrindSurvivors-Win64-Shipping.exe") {
        throw (Get-Msg 'InvalidExe')
    }

    return Split-Path -Parent $selectedFile
}

function Get-UE4SSDownloadInfo {
    Write-Host ("  " + (Get-Msg 'FetchingReleaseInfo')) -ForegroundColor DarkGray

    $apiUrl = "https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest"
    $releaseData = $null

    for ($i = 0; $i -lt $script:ProxyList.Count; $i++) {
        $proxy = $script:ProxyList[$i]
        $actualUrl = if ($proxy) { "${proxy}${apiUrl}" } else { $apiUrl }

        try {
            $headers = @{
                "User-Agent" = "GrindSurvivors-QoL-Installer/1.0"
                "Accept" = "application/vnd.github+json"
            }
            # Use Invoke-RestMethod for JSON parsing (OK for small API responses)
            $releaseData = Invoke-RestMethod -Uri $actualUrl -Headers $headers -TimeoutSec 15
            break
        }
        catch {
            # Check for rate limiting
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 403) {
                throw (Get-Msg 'APIRateLimited')
            }
            continue
        }
    }

    if (-not $releaseData) {
        throw (Get-Msg 'ReleaseInfoFailed')
    }

    # Find asset starting with "UE4SS_"
    $asset = $null
    foreach ($a in $releaseData.assets) {
        if ($a.name -like "UE4SS_*") {
            $asset = $a
            break
        }
    }

    if (-not $asset) {
        throw (Get-Msg 'ReleaseInfoFailed')
    }

    # Parse SHA256 from digest field if available (experimental features)
    $hash = ""
    if ($asset.digest -and $asset.digest.StartsWith("sha256:")) {
        $hash = $asset.digest.Substring(7).ToUpper()
    }

    return @{
        Name = $asset.name
        Url  = $asset.browser_download_url
        Size = [long]$asset.size
        Hash = $hash
    }
}

function Download-FileWithProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [long]$ExpectedSize = 0,
        [string]$ExpectedHash = ""
    )

    $fileName = [System.IO.Path]::GetFileName($OutputPath)
    $downloaded = $false

    for ($i = 0; $i -lt $script:ProxyList.Count; $i++) {
        $proxy = $script:ProxyList[$i]
        $actualUrl = if ($proxy) { "${proxy}${Url}" } else { $Url }

        # Display which source we're trying
        if ($proxy) {
            Write-Host ("  " + ((Get-Msg 'TryingProxySource') -f $proxy)) -ForegroundColor DarkGray
        } else {
            Write-Host ("  " + (Get-Msg 'TryingDirectSource')) -ForegroundColor DarkGray
        }
        Write-Host ("  " + (Get-Msg 'DownloadingFile')) -ForegroundColor DarkGray

        try {
            Invoke-DownloadWithProgress -Url $actualUrl -OutputPath $OutputPath -ActivityName $fileName
            $downloaded = $true
            break
        }
        catch {
            Write-Host ("  " + ((Get-Msg 'DownloadFailed') -f $_.Exception.Message)) -ForegroundColor DarkYellow
            # Remove partial file
            if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue }
            continue
        }
    }

    if (-not $downloaded) {
        throw (Get-Msg 'DownloadFailedAllSources')
    }

    # Verify file integrity
    if ($ExpectedSize -gt 0 -or $ExpectedHash) {
        Write-Host ("  " + (Get-Msg 'VerifyingFile')) -ForegroundColor DarkGray
        $actualSize = (Get-Item $OutputPath).Length
        if ($ExpectedSize -gt 0 -and $actualSize -ne $ExpectedSize) {
            Remove-Item $OutputPath -Force
            throw ((Get-Msg 'VerifyFailed') -f "size=$ExpectedSize", "size=$actualSize")
        }
        if ($ExpectedHash) {
            $actualHash = (Get-FileHash $OutputPath -Algorithm SHA256).Hash
            if ($actualHash -ne $ExpectedHash) {
                Remove-Item $OutputPath -Force
                throw ((Get-Msg 'VerifyFailed') -f $ExpectedHash, $actualHash)
            }
        }
        Write-Host ("  " + (Get-Msg 'VerifyPassed')) -ForegroundColor Green
    }

    Write-Host ("  " + ((Get-Msg 'DownloadComplete') -f $fileName)) -ForegroundColor Green
}

function Invoke-DownloadWithProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        [string]$ActivityName = "file"
    )

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = "GrindSurvivors-QoL-Installer/1.0"
    $request.Timeout = 30000          # 30 second connection timeout
    $request.ReadWriteTimeout = 30000 # 30 second read timeout
    $request.AllowAutoRedirect = $true
    $request.MaximumAutomaticRedirections = 10

    $response = $null
    $responseStream = $null
    $fileStream = $null

    try {
        $response = $request.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        $fileStream = [System.IO.File]::Create($OutputPath)

        $buffer = New-Object byte[] 65536   # 64KB buffer
        $totalRead = [long]0
        $lastProgressUpdate = [DateTime]::MinValue
        
        while ($true) {
            $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -le 0) { break }

            $fileStream.Write($buffer, 0, $bytesRead)
            $totalRead += $bytesRead

            # Throttle progress updates to every 200ms
            $now = [DateTime]::Now
            if (($now - $lastProgressUpdate).TotalMilliseconds -ge 200) {
                $lastProgressUpdate = $now
                if ($totalBytes -gt 0) {
                    $percent = [math]::Floor($totalRead / $totalBytes * 100)
                    $downloadedMB = $totalRead / 1MB
                    $totalMB = $totalBytes / 1MB
                    $status = ((Get-Msg 'DownloadProgress') -f $downloadedMB, $totalMB, $percent)
                    Write-Progress -Activity ((Get-Msg 'Downloading') + ": $ActivityName") -Status $status -PercentComplete $percent
                } else {
                    $downloadedMB = $totalRead / 1MB
                    Write-Progress -Activity ((Get-Msg 'Downloading') + ": $ActivityName") -Status (("{0:F1} MB") -f $downloadedMB)
                }
            }
        }

        Write-Progress -Activity ((Get-Msg 'Downloading') + ": $ActivityName") -Completed
    }
    finally {
        if ($fileStream) { $fileStream.Close() }
        if ($responseStream) { $responseStream.Close() }
        if ($response) { $response.Close() }
    }
}

function Install-UE4SS {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ZipPath,
        [Parameter(Mandatory=$true)]
        [string]$GameDir   # Win64 directory
    )

    $modsDir = Join-Path $GameDir "ue4ss\Mods"
    $modsTxtPath = Join-Path $modsDir "mods.txt"
    $settingsPath = Join-Path $GameDir "ue4ss\UE4SS-settings.ini"

    # --- Backup existing configs ---
    $backedUpModsTxt = $null
    $backedUpSettings = $null

    if (Test-Path $modsTxtPath) {
        Write-Host ("  " + (Get-Msg 'BackingUpConfig')) -ForegroundColor DarkGray
        $backedUpModsTxt = Get-Content -Path $modsTxtPath -Raw -Encoding UTF8
    }
    if (Test-Path $settingsPath) {
        $backedUpSettings = Get-Content -Path $settingsPath -Raw -Encoding UTF8
    }

    # --- Extract UE4SS ZIP ---
    Write-Host ("  " + (Get-Msg 'Extracting')) -ForegroundColor DarkGray
    # UE4SS ZIP is FLAT: dwmapi.dll + ue4ss/ at root → extract directly to Win64 dir
    Expand-Archive -Path $ZipPath -DestinationPath $GameDir -Force

    # --- Verify sentinel files ---
    $dwmapiPath = Join-Path $GameDir "dwmapi.dll"
    $ue4ssDllPath = Join-Path $GameDir "ue4ss\UE4SS.dll"
    if (-not (Test-Path $dwmapiPath) -or -not (Test-Path $ue4ssDllPath)) {
        throw "UE4SS extraction verification failed: sentinel files not found."
    }

    # --- Restore UE4SS-settings.ini ---
    if ($backedUpSettings) {
        Write-Host ("  " + (Get-Msg 'RestoringConfig')) -ForegroundColor DarkGray
        [System.IO.File]::WriteAllText($settingsPath, $backedUpSettings, [System.Text.Encoding]::UTF8)
    }

    # --- Merge mods.txt ---
    if ($backedUpModsTxt) {
        # Parse backed up entries (format: "ModName : 0|1")
        $customEntries = @{}
        foreach ($line in ($backedUpModsTxt -split "`r?`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -and -not $trimmed.StartsWith(";") -and $trimmed -match '^(.+?)\s*:\s*(\d+)$') {
                $customEntries[$Matches[1].Trim()] = $Matches[2]
            }
        }

        # Read new default mods.txt
        $newModsTxt = Get-Content -Path $modsTxtPath -Encoding UTF8
        $defaultMods = @{}
        foreach ($line in $newModsTxt) {
            $trimmed = $line.Trim()
            if ($trimmed -and -not $trimmed.StartsWith(";") -and $trimmed -match '^(.+?)\s*:\s*\d+$') {
                $defaultMods[$Matches[1].Trim()] = $true
            }
        }

        # Find custom entries not in default list
        $extraEntries = @()
        foreach ($modName in $customEntries.Keys) {
            if (-not $defaultMods.ContainsKey($modName)) {
                $extraEntries += "$modName : $($customEntries[$modName])"
            }
        }

        # Insert extra entries before "; Built-in keybinds" comment or "Keybinds : 1" line
        if ($extraEntries.Count -gt 0) {
            $lines = [System.Collections.ArrayList]@($newModsTxt)
            $insertIndex = $lines.Count  # default: end of file
            for ($j = 0; $j -lt $lines.Count; $j++) {
                if ($lines[$j].Trim().StartsWith("; Built-in keybinds") -or $lines[$j].Trim() -match '^Keybinds\s*:\s*\d+$') {
                    $insertIndex = $j
                    break
                }
            }
            foreach ($entry in $extraEntries) {
                $lines.Insert($insertIndex, $entry)
                $insertIndex++
            }
            $lines | Set-Content -Path $modsTxtPath -Encoding UTF8
        }
    }
}

function Install-Mod {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceDir,      # Local mod source directory (e.g. Mods/FreshPerksFirst)
        [Parameter(Mandatory=$true)]
        [string]$ModName,        # Mod folder name (e.g. FreshPerksFirst)
        [Parameter(Mandatory=$true)]
        [string]$GameDir         # Win64 directory
    )

    $modsDir = Join-Path $GameDir "ue4ss\Mods"
    $modTargetDir = Join-Path $modsDir $ModName
    $modsTxtPath = Join-Path $modsDir "mods.txt"

    # Ensure Mods directory exists
    if (-not (Test-Path $modsDir)) {
        New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
    }

    # Remove old mod directory if exists
    if (Test-Path $modTargetDir) {
        Write-Host ("  " + ((Get-Msg 'RemovingOldMod') -f $ModName)) -ForegroundColor DarkGray
        Remove-Item -Path $modTargetDir -Recurse -Force
    }

    # Copy mod directory
    Write-Host ("  " + ((Get-Msg 'CopyingMod') -f $ModName)) -ForegroundColor DarkGray
    Copy-Item -Path $SourceDir -Destination $modTargetDir -Recurse -Force

    # Register in mods.txt
    if (Test-Path $modsTxtPath) {
        Update-ModsConfig -ModsTxtPath $modsTxtPath -ModName $ModName -Enabled 1
        Write-Host ("  " + ((Get-Msg 'ModRegistered') -f $ModName)) -ForegroundColor Green
    }
}

function Install-SharedLibraries {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SharedSourceDir,  # Local Mods/shared directory
        [Parameter(Mandatory=$true)]
        [string]$GameDir           # Win64 directory
    )

    $modsDir = Join-Path $GameDir "ue4ss\Mods"
    $sharedTargetDir = Join-Path $modsDir "shared"

    # Ensure Mods directory exists
    if (-not (Test-Path $modsDir)) {
        New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
    }

    # Remove old shared directory if exists
    if (Test-Path $sharedTargetDir) {
        Write-Host ("  " + ((Get-Msg 'RemovingOldMod') -f "shared")) -ForegroundColor DarkGray
        Remove-Item -Path $sharedTargetDir -Recurse -Force
    }

    # Copy shared directory
    Write-Host ("  " + ((Get-Msg 'CopyingMod') -f "shared")) -ForegroundColor DarkGray
    Copy-Item -Path $SharedSourceDir -Destination $sharedTargetDir -Recurse -Force
}

function Get-ModList {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModsRootDir  # Path to Mods/ directory
    )

    $mods = @()
    $excludeDirs = @("shared")
    
    $dirs = Get-ChildItem -Path $ModsRootDir -Directory
    foreach ($dir in $dirs) {
        if ($dir.Name -notin $excludeDirs) {
            $mods += $dir.Name
        }
    }

    return $mods
}

function Update-ModsConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModsTxtPath,
        [Parameter(Mandatory=$true)]
        [string]$ModName,
        [int]$Enabled = 1
    )

    $lines = [System.Collections.ArrayList]@(Get-Content -Path $ModsTxtPath -Encoding UTF8)

    # Check if mod entry already exists
    $existingIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($ModName))\s*:\s*\d+") {
            $existingIndex = $i
            break
        }
    }

    $entry = "$ModName : $Enabled"

    if ($existingIndex -ge 0) {
        # Update existing entry
        $lines[$existingIndex] = $entry
    }
    else {
        # Insert before "; Built-in keybinds" comment or "Keybinds : 1"
        $insertIndex = $lines.Count
        for ($j = 0; $j -lt $lines.Count; $j++) {
            $trimmed = $lines[$j].Trim()
            if ($trimmed.StartsWith("; Built-in keybinds") -or $trimmed -match '^Keybinds\s*:\s*\d+$') {
                $insertIndex = $j
                break
            }
        }
        $lines.Insert($insertIndex, $entry)
    }

    $lines | Set-Content -Path $ModsTxtPath -Encoding UTF8
}

# ===== 4. Main Execution Flow / 主执行流程 =====

# Determine script root directory (where this script and the Mods/ folder live)
$script:ScriptRoot = Split-Path -Parent $PSCommandPath
$script:ModsRoot = Join-Path $script:ScriptRoot "Mods"
$script:TempDir = Join-Path $env:TEMP "GrindSurvivorsQoL_Install_$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    Initialize-Environment

    # Display welcome banner
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $(Get-Msg 'Welcome')" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host (Get-Msg 'WelcomeDesc')
    Write-Host ""

    # Create temp directory
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    # Step 1: Find game directory
    Write-Host (Get-Msg 'StepFindGame') -ForegroundColor Yellow
    $gameDir = Find-GameDirectory
    Write-Host ((Get-Msg 'FoundGameDir') -f $gameDir) -ForegroundColor Green
    Write-Host ""

    # Step 2: Download UE4SS
    Write-Host (Get-Msg 'StepDownloadUE4SS') -ForegroundColor Yellow
    $ue4ssInstalled = (Test-Path (Join-Path $gameDir "dwmapi.dll")) -and (Test-Path (Join-Path $gameDir "ue4ss\UE4SS.dll"))
    $skipUE4SS = $false
    if ($ue4ssInstalled) {
        $answer = Read-Host (Get-Msg 'UE4SSAlreadyInstalled')
        if ($answer -match '^[Nn]') {
            Write-Host (Get-Msg 'UE4SSSkipped') -ForegroundColor DarkYellow
            $skipUE4SS = $true
        }
    }

    if (-not $skipUE4SS) {
        $ue4ssInfo = Get-UE4SSDownloadInfo
        Write-Host ((Get-Msg 'ReleaseInfoFound') -f $ue4ssInfo.Name, ($ue4ssInfo.Size / 1MB)) -ForegroundColor Green
        $ue4ssZip = Join-Path $script:TempDir $ue4ssInfo.Name
        Download-FileWithProgress -Url $ue4ssInfo.Url -OutputPath $ue4ssZip -ExpectedSize $ue4ssInfo.Size -ExpectedHash $ue4ssInfo.Hash

        Write-Host ("  " + (Get-Msg 'InstallingUE4SS')) -ForegroundColor DarkGray
        Install-UE4SS -ZipPath $ue4ssZip -GameDir $gameDir
        Write-Host (Get-Msg 'UE4SSInstallComplete') -ForegroundColor Green
    }
    Write-Host ""

    # Step 3: Install all mods from local Mods/ directory
    Write-Host (Get-Msg 'StepInstallMods') -ForegroundColor Yellow

    if (-not (Test-Path $script:ModsRoot)) {
        throw "Mods directory not found at: $script:ModsRoot"
    }

    # Get list of mods (exclude "shared")
    $modList = Get-ModList -ModsRootDir $script:ModsRoot

    if ($modList.Count -eq 0) {
        Write-Host ("  " + (Get-Msg 'NoModsFound')) -ForegroundColor DarkYellow
    } else {
        Write-Host ("  " + ((Get-Msg 'ModsFound') -f $modList.Count)) -ForegroundColor Green

        # Ensure mods.txt exists before registering mods (created by UE4SS install, or create it)
        $modsDir = Join-Path $gameDir "ue4ss\Mods"
        $modsTxtPath = Join-Path $modsDir "mods.txt"
        if (-not (Test-Path $modsDir)) {
            New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
        }
        if (-not (Test-Path $modsTxtPath)) {
            Set-Content -Path $modsTxtPath -Value "; Auto-generated mods.txt`n" -Encoding UTF8
        }

        # Install each mod
        foreach ($modName in $modList) {
            $modSourceDir = Join-Path $script:ModsRoot $modName
            Write-Host ""
            Write-Host ((Get-Msg 'InstallingMod') -f $modName) -ForegroundColor Cyan
            Install-Mod -SourceDir $modSourceDir -ModName $modName -GameDir $gameDir
            Write-Host ((Get-Msg 'ModInstallComplete') -f $modName) -ForegroundColor Green
        }

        # Install shared libraries
        $sharedSourceDir = Join-Path $script:ModsRoot "shared"
        if (Test-Path $sharedSourceDir) {
            Write-Host ""
            Write-Host (Get-Msg 'InstallingShared') -ForegroundColor Cyan
            Install-SharedLibraries -SharedSourceDir $sharedSourceDir -GameDir $gameDir
            Write-Host (Get-Msg 'SharedInstallComplete') -ForegroundColor Green
        }
    }

    Write-Host ""

    # Done
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  $(Get-Msg 'AllComplete')" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host ((Get-Msg 'ErrorOccurred') -f $_.Exception.Message) -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
finally {
    # Cleanup temp directory
    if (Test-Path $script:TempDir) {
        Write-Host (Get-Msg 'CleaningUp')
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host ""
    Read-Host (Get-Msg 'PressEnterToExit')
}
