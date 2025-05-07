$GitecOpsExecutionPath = "D:\GitecOps.Project\src\CSharp\GitecOps.Util\bin\Debug\net9.0\GitecOps.Util.exe"

if (-not (Test-Path $GitecOpsExecutionPath)) {
    Write-Error "C# app not built. Run 'dotnet build' first."
    exit 1
} else {
    Write-Host "C# app found at $GitecOpsExecutionPath"
}
$Name = "GitecOps.Util.exe"
try {
    $output = & $GitecOpsExecutionPath $Name
    if ($LASTEXITCODE -eq 0) {
        $json = $output | ConvertFrom-Json
        Write-Host "Greeting: $($json.greeting)"
        Write-Host "Timestamp: $($json.timestamp)"
    } else {
        Write-Error "App failed with exit code $LASTEXITCODE"
        Write-Host "Output: $output"
    }
} catch {
    Write-Error "Exception: $_"
}