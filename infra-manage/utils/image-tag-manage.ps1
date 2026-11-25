$ErrorActionPreference = "Stop"
$tag = Get-Date -Format "yyyyMMddHHmmssfff"
$repoDir = Split-Path -Parent $PSScriptRoot
$projectsDir = Split-Path -Parent $repoDir
$viteDir = Join-Path $projectsDir "main-vite-web"
$serverDir = Join-Path $projectsDir "main-server"
$aiDir = Join-Path $projectsDir "main-ai-model"

$builds = @(
    @{ Image = "vite-web"; Context = $viteDir; Dockerfile = (Join-Path $viteDir "orchestration.Dockerfile"); Manifest = "kubernetes\vite\deployment.yaml" }
    @{ Image = "spring-server"; Context = $serverDir; Manifest = "kubernetes\spring\deployment.yaml" }
    @{ Image = "embedding"; Context = $aiDir; Target = "embedding"; Manifest = "kubernetes\embedding\deployment.yaml" }
    @{ Image = "ai-model"; Context = $aiDir; Target = "ai"; Manifest = "kubernetes\agent\deployment.yaml" }
    @{ Image = "kb-ingest"; Context = $aiDir; Target = "ingest"; Manifest = "kubernetes\ingest\deployment.yaml" }
    @{ Image = "qdrant-init"; Context = $aiDir; Target = "qdrant-init"; Manifest = "kubernetes\qdrant\job.yaml" }
)

foreach ($build in $builds) {
    if (-not (Test-Path -LiteralPath $build.Context -PathType Container)) {
        throw "Build context not found: $($build.Context)"
    }
    $dockerfile = if ($build.Dockerfile) { $build.Dockerfile } else { Join-Path $build.Context "Dockerfile" }
    if (-not (Test-Path -LiteralPath $dockerfile -PathType Leaf)) {
        throw "Dockerfile not found: $dockerfile"
    }

    $build.ManifestPath = Join-Path $repoDir $build.Manifest
    $build.Original = [System.IO.File]::ReadAllText($build.ManifestPath)
    $imageName = [regex]::Escape($build.Image)
    $build.Pattern = '(?m)^([ \t]*(?:-[ \t]*)?image:[ \t]*)([''"]?)' + $imageName + ':[A-Za-z0-9_][A-Za-z0-9_.-]*\2([ \t]*(?:#[^\r\n]*)?)(?=\r?$)'
    if ([regex]::Matches($build.Original, $build.Pattern).Count -ne 1) {
        throw "Expected one image reference for $($build.Image) in $($build.ManifestPath)."
    }
}

foreach ($build in $builds) {
    $buildArgs = @("build", "-t", "$($build.Image):$tag")
    if ($build.Dockerfile) {
        $buildArgs += @("-f", $build.Dockerfile)
    }
    if ($build.Target) {
        $buildArgs += @("--target", $build.Target)
    }
    $buildArgs += $build.Context

    & docker @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Docker build failed for $($build.Image) (exit $LASTEXITCODE); manifests were not updated."
    }
}

foreach ($build in $builds) {
    if ([System.IO.File]::ReadAllText($build.ManifestPath) -cne $build.Original) {
        throw "Manifest changed during the build: $($build.ManifestPath). No manifests were updated."
    }
}

foreach ($build in $builds) {
    $replacement = [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $match.Groups[1].Value + $match.Groups[2].Value + $build.Image + ":" + $tag +
            $match.Groups[2].Value + $match.Groups[3].Value
    }
    $updated = [regex]::Replace($build.Original, $build.Pattern, $replacement)
    [System.IO.File]::WriteAllText($build.ManifestPath, $updated, [System.Text.UTF8Encoding]::new($false))
    Write-Output "$($build.Manifest): $($build.Image):$tag"
}

Write-Output "Manifest images updated. Load images into Kubernetes nodes if needed, then apply the manifests."