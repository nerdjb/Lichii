# SPDX-License-Identifier: GPL-3.0-or-later

# Installs the LLVM release that the Windows CI jobs compile with (clang-cl, lld-link, llvm-lib)
# and exports its location as LLVM_ROOT for later steps. The installer is pinned by checksum so a
# runner image update never changes the compiler.

$ErrorActionPreference = 'Stop'

$version = '22.1.8'
$sha256 = '16e5709785fef73c854646241c4a92c5cd574318d1b33c63330dd7721903e55c'

# Release asset downloads from GitHub occasionally fail on the runner; retry before giving up.
function Get-ReleaseAsset {
    param([string]$Uri, [string]$Path, [int]$Attempts = 5)
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Invoke-WebRequest -OutFile $Path $Uri
            return
        } catch {
            if ($attempt -eq $Attempts) { throw }
            Write-Host "Download failed (attempt $attempt/$Attempts): $($_.Exception.Message)"
            Start-Sleep -Seconds (10 * $attempt)
        }
    }
}

$installer = Join-Path $env:RUNNER_TEMP 'llvm.exe'
Get-ReleaseAsset "https://github.com/llvm/llvm-project/releases/download/llvmorg-$version/LLVM-$version-win64.exe" $installer
if ((Get-FileHash -Algorithm SHA256 $installer).Hash -ne $sha256) {
    throw 'LLVM installer checksum mismatch'
}
$root = Join-Path $env:RUNNER_TEMP 'llvm'
Start-Process -Wait -FilePath $installer -ArgumentList '/S', "/D=$root"
$reported = & "$root/bin/clang-cl.exe" --version
$reported
if (-not ($reported -match "clang version $([regex]::Escape($version))")) {
    throw "Unexpected clang-cl: $reported"
}
"LLVM_ROOT=$($root.Replace('\', '/'))" | Out-File -Append -Encoding utf8 $env:GITHUB_ENV
