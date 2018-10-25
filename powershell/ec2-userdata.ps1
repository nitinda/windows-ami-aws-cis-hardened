<powershell>

net user Administrator '###############' # 16 Characters Long
wmic useraccount where "name='Administrator'" set PasswordExpires=FALSE

write-output "Running User Data Script"
write-host "(host) Running User Data Script"

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore

Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service' -Name 'AllowBasic' -Value 1 -Type DWord -Force
Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service' -Name 'AllowUnencryptedTraffic' -Value 1 -Type DWord -Force
Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowBasic' -Value 1 -Type DWord -Force
Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowUnencryptedTraffic' -Value 1 -Type DWord -Force

# Don't set this before Set-ExecutionPolicy as it throws an error
$ErrorActionPreference = "stop"

# Remove HTTP listener
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse

Set-Item WSMan:\localhost\MaxTimeoutms 1800000
Set-Item WSMan:\localhost\Service\Auth\Basic $true

Enable-PSRemoting -force
Set-Item WSMan:\localhost\Client\trustedhosts -value * -force

$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer"
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force

# WinRM
write-output "Setting up WinRM"
write-host "(host) setting up WinRM"

winrm quickconfig -q
winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
winrm set "winrm/config/service" '@{AllowUnencrypted="true"}'
winrm set "winrm/config/client" '@{AllowUnencrypted="true"}'
winrm set "winrm/config/service/auth" '@{Basic="true"}'
winrm set "winrm/config/client/auth" '@{Basic="true"}'
winrm set "winrm/config/service/auth" '@{CredSSP="true"}'
winrm set "winrm/config/listener?Address=*+Transport=HTTPS" "@{Port=`"5986`";Hostname=`"packer`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}"
netsh firewall set service type=remoteadmin mode=enable
netsh advfirewall firewall set rule group="remote administration" new enable=yes
netsh firewall add portopening TCP 5986 "Port 5986"
Stop-Service -Name WinRM
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

</powershell>