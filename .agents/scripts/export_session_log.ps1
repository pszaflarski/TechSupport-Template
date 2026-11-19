$ErrorActionPreference = "SilentlyContinue"

try {
    $raw = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $data = $raw | ConvertFrom-Json
        $transcriptStr = if ($data.transcriptPath) { $data.transcriptPath.ToString() } else { "" }
        $convId = if ($data.conversationId) { $data.conversationId.ToString() } else { "unknown" }

        if ($transcriptStr -and (Test-Path -LiteralPath $transcriptStr)) {
            $transcriptFile = Get-Item -LiteralPath $transcriptStr
            $fullPath = Join-Path $transcriptFile.DirectoryName "transcript_full.jsonl"
            $sourcePath = if (Test-Path -LiteralPath $fullPath) { $fullPath } else { $transcriptStr }

            $entries = New-Object System.Collections.Generic.List[string]
            foreach ($line in (Get-Content -LiteralPath $sourcePath -Encoding UTF8)) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try {
                    $step = $line | ConvertFrom-Json
                } catch {
                    continue
                }
                $content = $step.content
                if ($content -is [string] -and -not [string]::IsNullOrWhiteSpace($content)) {
                    $ts = if ($step.created_at) { $step.created_at.ToString() } else { "" }
                    if ($step.type -eq "USER_INPUT") {
                        $text = $content
                        if ($content -match '(?s)<USER_REQUEST>\s*(.*?)\s*</USER_REQUEST>') {
                            $text = $Matches[1]
                        }
                        $text = $text.Trim()
                        if ($text) { $entries.Add("[$ts] USER: $text") }
                    } elseif ($step.type -eq "PLANNER_RESPONSE") {
                        $entries.Add("[$ts] ASSISTANT: $($content.Trim())")
                    }
                }
            }

            if ($entries.Count -gt 0) {
                $rootDir = (Get-Item -LiteralPath $PSScriptRoot).Parent.Parent.FullName
                $logsDir = Join-Path $rootDir "logs"
                if (-not (Test-Path -LiteralPath $logsDir)) {
                    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
                }
                $dateStr = (Get-Date).ToString("yyyy-MM-dd")
                $shortId = if ($convId.Length -ge 8) { $convId.Substring(0, 8) } else { $convId }
                $outPath = Join-Path $logsDir "session_${dateStr}_${shortId}.log"
                $header = "=== TechSupport Session $convId ===`r`n`r`n"
                $body = ($entries -join "`r`n`r`n") + "`r`n"
                [System.IO.File]::WriteAllText($outPath, $header + $body, [System.Text.Encoding]::UTF8)
            }
        }
    }
} catch {
}

Write-Output '{"decision":"allow"}'
exit 0
