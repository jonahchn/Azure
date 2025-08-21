$regKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,
                                                   [Microsoft.Win32.RegistryView]::Registry64)
$subKey = $regKey.OpenSubKey("SOFTWARE\Microsoft\Windows Advanced Threat Protection")

if ($subKey) {
    # Read the OnboardedInfo value
    $onboardedInfoJson = $subKey.GetValue("OnboardedInfo")
    if ($onboardedInfoJson) {
        # Parse JSON and extract OrgId
        $parsed = $onboardedInfoJson | ConvertFrom-Json
        $parsed.body

        }}
