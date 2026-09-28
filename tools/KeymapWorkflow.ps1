param(
    [string]$Repository = 'orihekat78/zmk-config-moNa2-v2',
    [string]$Branch = 'main',
    [switch]$OpenEditor,
    [switch]$BuildOnly,
    [ValidateSet('Right', 'Left')][string]$Side = 'Right',
    [long]$RunId = 0,
    [string]$Uf2Drive,
    [ValidateRange(1, 120)][int]$TimeoutMinutes = 45
)

$ErrorActionPreference = 'Stop'
$editorUrl = 'https://nickcoutsos.github.io/keymap-editor/'
$keymapPath = 'config/mona2.keymap'
$sideCode = if ($Side -eq 'Left') { 'l' } else { 'r' }
$sideLabel = if ($Side -eq 'Left') { '左側' } else { '右側' }
$sideConfirmation = $Side.ToUpperInvariant()

function Invoke-Gh {
    param([string[]]$Arguments)
    $result = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Arguments -join ' ') に失敗しました: $($result -join ' ')"
    }
    return $result
}

function Get-LatestKeymapCommit {
    $uri = "repos/$Repository/commits?sha=$Branch&path=$keymapPath&per_page=1"
    $commits = @(Invoke-Gh @('api', $uri, '--jq', '.[].sha'))
    if ($commits.Count -ne 1 -or $commits[0] -notmatch '^[0-9a-f]{40}$') {
        throw "${Repository} の ${Branch} に $keymapPath が見つかりません。"
    }
    return [string]$commits[0]
}

function Get-BuildRun {
    param([string]$Commit)
    $json = Invoke-Gh @('run', 'list', '-R', $Repository, '-w', 'build.yml', '-c', $Commit,
        '-e', 'push', '-L', '10', '--json', 'databaseId,headSha,status,conclusion,url')
    $runs = @($json | ConvertFrom-Json)
    return @($runs | Where-Object { $_.headSha -eq $Commit } | Sort-Object databaseId -Descending |
        Select-Object -First 1)
}

function Test-SideUf2 {
    param([System.IO.FileInfo]$File, [string]$Code)
    if ($File.Name -notmatch "(?i)^mona2_$Code(?:[ _-].*)?\.uf2$") { return $false }
    if ($File.Length -lt 512 -or $File.Length % 512 -ne 0) { return $false }
    $stream = $File.OpenRead()
    try {
        $header = New-Object byte[] 8
        if ($stream.Read($header, 0, 8) -ne 8) { return $false }
        return ([Convert]::ToHexString($header) -eq '5546320A57515D9E')
    }
    finally { $stream.Dispose() }
}

function Test-XiaoBootDrive {
    param([string]$Root)
    $info = Join-Path $Root 'INFO_UF2.TXT'
    if (-not (Test-Path -LiteralPath $info -PathType Leaf)) { return $false }
    try {
        $contents = Get-Content -LiteralPath $info -Raw
        return ($contents -match '(?im)^Board-ID:\s*(?:Seeed.*XIAO.*nRF52840|nRF52840.*SeeedXiao)')
    }
    catch { return $false }
}

function Get-XiaoBootDrives {
    if ($Uf2Drive) {
        $path = (Resolve-Path -LiteralPath $Uf2Drive -ErrorAction SilentlyContinue).Path
        if ($path -and (Test-XiaoBootDrive $path)) { return @($path) }
        return @()
    }
    $roots = @([System.IO.DriveInfo]::GetDrives() |
        Where-Object { $_.IsReady -and $_.DriveType -eq [System.IO.DriveType]::Removable } |
        ForEach-Object { $_.RootDirectory.FullName })
    return @($roots | Where-Object { Test-XiaoBootDrive $_ })
}

try {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub CLI (gh) が見つかりません。'
    }
    $workflow = Invoke-Gh @('api', "repos/$Repository/actions/workflows/build.yml", '--jq', '.state')
    if ($workflow -ne 'active') { throw "${Repository} の build.yml が有効ではありません。" }

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    if ($RunId) {
        $run = Invoke-Gh @('run', 'view', [string]$RunId, '-R', $Repository,
            '--json', 'databaseId,status,conclusion,url,headBranch,event') | ConvertFrom-Json
        if ($run.headBranch -ne $Branch -or $run.event -notin @('push', 'workflow_dispatch')) {
            throw '指定されたビルドは対象ブランチのpush/手動ビルドではありません。'
        }
    }
    else {
        $before = Get-LatestKeymapCommit
        Write-Host "監視先: https://github.com/$Repository (ブランチ: $Branch)"
        Write-Host "エディタ: $editorUrl"
        Write-Host 'Keymap Editorで編集し、GitHubへ保存してください。保存を待っています。'
        if ($OpenEditor) { Start-Process $editorUrl }

        do {
            Start-Sleep -Seconds 8
            $commit = Get-LatestKeymapCommit
            if ($commit -ne $before) { break }
        } while ((Get-Date) -lt $deadline)
        if ($commit -eq $before) { throw 'キーマップの保存を時間内に検出できませんでした。' }
        Write-Host "保存を検出: $commit"

        $run = $null
        do {
            $matches = @(Get-BuildRun $commit)
            if ($matches.Count -gt 0) { $run = $matches[0]; break }
            Start-Sleep -Seconds 8
        } while ((Get-Date) -lt $deadline)
        if (-not $run) { throw 'この保存に対応するpushビルドが見つかりませんでした。' }
    }
    Write-Host "ビルド: $($run.url)"

    do {
        $run = (Invoke-Gh @('run', 'view', [string]$run.databaseId, '-R', $Repository,
            '--json', 'databaseId,status,conclusion,url') | ConvertFrom-Json)
        if ($run.status -eq 'completed') { break }
        Start-Sleep -Seconds 10
    } while ((Get-Date) -lt $deadline)
    if ($run.status -ne 'completed') { throw 'ビルドが時間内に完了しませんでした。' }
    if ($run.conclusion -ne 'success') { throw "ビルド失敗: $($run.url)" }

    $downloadRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\moNa2-builds'
    $outputDir = Join-Path $downloadRoot ("$($run.databaseId)-$(Get-Date -Format yyyyMMdd-HHmmss)")
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Invoke-Gh @('run', 'download', [string]$run.databaseId, '-R', $Repository,
        '-n', 'firmware', '-D', $outputDir) | Out-Null
    $candidates = @(Get-ChildItem -LiteralPath $outputDir -File -Recurse -Filter '*.uf2' |
        Where-Object { Test-SideUf2 $_ $sideCode })
    if ($candidates.Count -ne 1) {
        throw "${sideLabel}UF2が1個に決まりません。成果物を確認してください: $outputDir"
    }
    $uf2 = $candidates[0]
    Write-Host "${sideLabel}UF2: $($uf2.FullName)"
    if ($BuildOnly) { Write-Host 'ビルド成果物の取得まで完了しました。'; exit 0 }

    Write-Host "${sideLabel}をUSB接続し、RESETを素早く2回押してください。UF2ドライブを待っています。"
    $driveDeadline = (Get-Date).AddMinutes(5)
    do {
        $drives = @(Get-XiaoBootDrives)
        if ($drives.Count -gt 1) {
            throw 'XIAOのUF2ドライブが複数あります。1台だけ接続してください。'
        }
        if ($drives.Count -eq 1) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $driveDeadline)
    if ($drives.Count -ne 1) { throw 'XIAOのUF2ドライブが見つかりませんでした。' }
    if (-not (Test-XiaoBootDrive $drives[0])) { throw 'UF2ドライブの識別情報を再確認できませんでした。' }

    Write-Host "XIAOのUF2ドライブから左右は判別できません。${sideLabel}だけがUSB接続されていることを確認してください。"
    $confirmation = Read-Host "${sideLabel}に書き込む場合は $sideConfirmation と入力"
    if ($confirmation -cne $sideConfirmation) { throw '書き込みを中止しました。' }

    Copy-Item -LiteralPath $uf2.FullName -Destination $drives[0] -ErrorAction Stop
    Write-Host "書き込み完了: $($drives[0])"
}
catch {
    Write-Error $_
    exit 1
}
