param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
        If ($_ -match "https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)") {
            $True
          }
          else {
            Throw "$_ valid URL to mod is required"
          }
    })]
    [string] $url
)
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
[string]$rootPath = $myinvocation.MyCommand.Path | split-Path -Parent
class ModCls {
    [string] $hreff_id
    [string] $title
    ModCls() {
        $this.hreff_id = 
        $this.title = ""
    }
    ModCls([string] $rf, [string]$tl) {
        $this.hreff_id = $rf
        $this.title = $tl
    }
}
class ToSteamCls {
    [string] $appid
    [string] $title
    [ModCls[]] $Mods
    ToSteamCls([string] $id, [string]$tl, [ModCls[]] $mds) {
        $this.appid = $id
        $this.title = $tl
        $this.Mods = $mds
    }
}
function CreateFileForSteamCMD {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ToSteamCls] $data,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $path   
    )
    if ([string]::IsNullOrEmpty($path)) {
        $path = $rootPath
    }
    $pp = $path+"\$($data.title)"
    if (-Not (Test-Path -Path $pp)) {
        New-Item -Path $path -Name $data.title -ItemType "directory"
    }
    [string]$script = "force_install_dir $($pp)`nlogin anonymous`n"
    foreach ($mod in $data.Mods) {
        $script += "workshop_download_item $($data.appid) $($mod.hreff_id)`n"
    }
    $script += "quit"
    New-Item -Path . -Name "temp_cmd" -ItemType "file" -Value $script -Force
    #вызвать стим с перехватом вывода, удалить временный файл (выше), открыть директорию
    $prc = Start-Process -PassThru -NoNewWindow -FilePath ".\steamcmd\steamcmd.exe" -ArgumentList "+runscript ..\temp_cmd"
    $prc.WaitForExit()
    Invoke-Item "$pp\steamapps\workshop\content\$($data.appid)\"
    Remove-Item -Path ".\temp_cmd"
}
function GetModsList {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $url
    )
    #че нада. 1. название сборки+
    #2. список модов в виде ссылок на них+
    #3. appID+
    $WebResponse = Invoke-WebRequest -Uri $url -UseBasicParsing 
    $html = ConvertFrom-Html -Content $WebResponse.Content 

    $appinfo = ($html.SelectNodes('//div') | Where-Object { $_.HasClass('breadcrumbs') }).SelectNodes('.//a')[0] 
    $appid = $appinfo.Attributes[1].Value.split('/')[-1]
    $appname = $appinfo.InnerText.Trim();
    Write-Host "Getted game $appname with $appid id"
    $kekers = [System.Collections.ArrayList]($html.SelectNodes('//div') | Where-Object { $_.HasClass('workshopItemTitle') }) 
    $boxtitle = ($kekers[0].InnerText.Trim() -split (' ')) -join ('_');
    $kekers.remove($kekers[0])
    Write-Host "Getted mods collection as $boxtitle"
    #list модов
    [ModCls[]]$modslist = @()
    foreach ($mod in $kekers) {
        $bu = (Split-Path $mod.ParentNode.Attributes[0].Value -Leaf).replace("?id=", "")
        $modslist += [ModCls]::new($bu, $mod.InnerText)
    }
    Write-Host "Found $($modslist.Count) mods in collection"
    $tostm = [ToSteamCls]::new($appid, $boxtitle, $modslist)
    CreateFileForSteamCMD -data $tostm
}
#проверить есть ли игра в бесплатках //https://steamdb.info/sub/17906/apps/
#проверить обновления для модов - смотреть файл appworkshop.. в папке контент.. есть время скачки - timetouched
#сравнить со временем апдейта по запросу
#https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/?itemcount=КОЛ_ВО_&publishedfileids%5B0%5D=2307494117
#%5B 0-номер %5D
#get steam coll json info https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/?collectioncount=КОЛ_ВО_КОЛЛ&publishedfileids%5B0%5D=АЙДИКОЛЛЕКЦИИ
#GetModsList -url 
#"https://steamcommunity.com/sharedfiles/filedetails/?edit=true&id=3314416910"
GetModsList -url $url