# NB this file has to be idempotent. it will be run several times if the computer needs to be restarted.
#    when that happens, Boxstarter schedules this script to run again with an auto-logon.
# NB always remember to pass -y to choco install!
# NB already installed packages will refuse to install again; so we are safe to run this entire script again.

# NB make sure this is the first software you install, because, as a side
#    effect, this will trigger a reboot, which in turn, will fix the vagrant bug
#    that prevents the machine from rebooting after setting the hostname.
choco install -y googlechrome

choco install -y firefox --version 33.1

choco install -y jre8

choco install -y pstools

#choco install -y 7zip

# Enable Show Window Contents While Dragging
reg ADD "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 1 /f
#taskkill /IM explorer.exe /F ; explorer.exe

# disable password complexity.
echo 'Disabling password complexity...'
secedit /export /cfg policy.cfg
(gc policy.cfg) -replace '(PasswordComplexity\s*=\s*).+', '${1}0' | sc policy.cfg
secedit /configure /db $env:windir\security\policy.sdb /cfg policy.cfg /areas SECURITYPOLICY
del policy.cfg

####

# get latest selenium standalone server
$site = "http://selenium-release.storage.googleapis.com/" 
$infopage = Invoke-WebRequest -URI $Site -UseBasicParsing
$a = [xml]$infopage.Content
$SELENIUM_VERSION = '';

# determine the latest version of selenium server and download it
foreach ($a in $a.ListBucketResult.Contents) {
  if ($a.key -like '*selenium-server-standalone*') {
    $arr = $a.key.split("/");
    $SELENIUM_VERSION = $a[0];
    break;
  }
}
$downloadurl = "https://selenium-release.storage.googleapis.com/" + $SELENIUM_VERSION
Invoke-WebRequest -Uri $downloadurl -OutFile "selenium-server-standalone.jar" -UseBasicParsing

# determine the latest chrome driver
$site = "http://chromedriver.storage.googleapis.com/LATEST_RELEASE"
$versionpage = Invoke-WebRequest -URI $Site -UseBasicParsing
$CHROMEDRIVER_VERSION = $versionpage.Content
$infopage = "http://chromedriver.storage.googleapis.com/"
$a = [xml]$infopage.Content
foreach ($a in $a.ListBucketResult.Contents) {
  $stringmatch = "*" + $CHROMEDRIVER_VERSION + "*";
  if ($a.key -like $stringmatch) {
    $downloadurl = "http://chromedriver.storage.googleapis.com/" + $a.key;
    Invoke-WebRequest -Uri $downloadurl -OutFile "chromedriver_win32.zip" -UseBasicParsing
    Expand-Archive "chromedriver_win32.zip"
  }
}
####

# create the selenium-server user account.
echo 'Creating selenium-server user account...'
$seleniumServerPassword = "password"
net user selenium-server $seleniumServerPassword /add /y /fullname:"Selenium Server"
wmic useraccount where "name='selenium-server'" set PasswordExpires=FALSE
# grant it Remote Desktop access.
net localgroup 'Remote Desktop Users' selenium-server /add

#add selenium cmd script to registry
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v selenium-server-standalone /t REG_EXPAND_SZ /d "C:\Vagrant\start-selenium.cmd" /f

# install selenium server and setup Windows to Run it on logon.
#echo 'Waiting for C:\Vagrant to be available...'
# NB for some whacky reason we need to start a new explorer window to speedup
#    the mounting of C:\Vagrant...
#Start-Process explorer
#while (-not (Test-Path -Path C:\Vagrant\Vagrantfile)) { Sleep 3 }
#@'
#echo 'Waiting for the USERPROFILE to become available...'
#while (-not (Test-Path -Path $env:USERPROFILE)) { Sleep 3 }
#echo 'Configuring logon to run Selenium Server Hub and Node...'
#reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v selenium-server-hub /t REG_EXPAND_SZ /d "%USERPROFILE%\selenium-server\selenium-server-hub.cmd" /f
#reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v selenium-server-node /t REG_EXPAND_SZ /d "%USERPROFILE%\selenium-server\selenium-server-node.cmd" /f
#echo 'DONE installing the Selenium Server!'
#Sleep 5
#'@ | Out-File C:\tmp\install-selenium-server.ps1

# diable windows firewall
echo 'Disabling windows firewall'
netsh advfirewall set allprofiles state off
