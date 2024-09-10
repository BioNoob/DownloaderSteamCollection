#алгоритм
#1. Грузим состав коллекции (GetModsList)
#2. Чекаем есть ли папка по пути с параметра (или дефолт), если есть смотрим флаг проверки апдейтов
#2.1 Если проверять, то смотрим дату скачки (CheckDownloaded), грузим инфу по модам, составляем список к закачке (CreateFileForSteamCMD)
#2.2 Если не проверять, то сразу составляем список к закачке (CreateFileForSteamCMD)
#3. Открываем директорию

#проверить есть ли игра в бесплатках //https://steamdb.info/sub/17906/apps/
#проверить обновления для модов - смотреть файл appworkshop.. в папке контент.. есть время скачки - timetouched
#сравнить со временем апдейта по запросу
#https://steamapi.xpaw.me/#ISteamRemoteStorage/GetPublishedFileDetails
#https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/?itemcount=КОЛ_ВО_&publishedfileids%5B0%5D=2307494117
#%5B 0-номер %5D
#get steam coll json info https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/?collectioncount=КОЛ_ВО_КОЛЛ&publishedfileids%5B0%5D=АЙДИКОЛЛЕКЦИИ
#GetModsList -url 
#"https://steamcommunity.com/sharedfiles/filedetails/?edit=true&id=3314416910"

#для теста https://steamcommunity.com/sharedfiles/filedetails/?l=russian&id=3298571555
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
    [string] $url,
    [Parameter(Mandatory = $false, Position = 1)]
    [string] $login,
    [Parameter(Mandatory = $false, Position = 2)]
    [string] $passwd,
    [Parameter(Mandatory = $false, Position = 3)]
    [bool] $check_updtates,
    [Parameter(Mandatory = $false, Position = 4)]
    [string] $dir_path
)
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
[string]$rootPath = $myinvocation.MyCommand.Path | split-Path -Parent
class ModCls {
    [string] $hreff_id
    [string] $title
    [int32] $updated_time
    [int32] $downloaded_time
    ModCls() {
        $this.hreff_id = 
        $this.title = ""
        $this.updated_time = 0
        $this.downloaded_time = 0
    }
    ModCls([string] $rf, [string]$tl) {
        $this.hreff_id = $rf
        $this.title = $tl
        $this.updated_time = 0
        $this.downloaded_time = 0
    }
}
class ModCollInfo {
    [string] $appid
    [string] $title
    [ModCls[]] $Mods
    ModCollInfo([string] $id, [string]$tl, [ModCls[]] $mds) {
        $this.appid = $id
        $this.title = $tl
        $this.Mods = $mds
    }
}
function GeneratePath {
    param (
        [string]$path,
        [string]$coll_label,
        [string]$appid,
        [string][ref]$outpath_root,
        [string][ref]$outpath_to_acf
    )
    if ([string]::IsNullOrEmpty($path)) {
        $path = $rootPath
    }
    $outpath_root = $path+"\$coll_label"
    $outpath_to_acf = "$outpath_root\steamapps\workshop\appworkshop_$appid.acf"
}
function CreateFileForSteamCMD {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ModCollInfo] $data,
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
    #$WebResponse = Invoke-WebRequest -Uri $url -UseBasicParsing
    $libPath = ".\HtmlAgilityPack.dll"
    Add-Type -Path $libPath
    $web = New-Object -TypeName "HtmlAgilityPack.HtmlWeb"
    $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
    #$dom.Load($WebResponse.Content, [System.Text.Encoding]::UTF8)
    try {
        $dom = $web.Load($url)    
    }
    catch {
        Write-Host "Download Error. Pls try again"
        return
    }
    
    #$html = ConvertFrom-Html -Content $WebResponse.Content 
    $html = $dom.DocumentNode
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
    $tostm = [ModCollInfo]::new($appid, $boxtitle, $modslist)
    CheckUpdates -mod_coll $tostm
    #CreateFileForSteamCMD -data $tostm
}
#Использовать если проверяем уже скаченное
function CheckUpdates {
    param (
        [ModCollInfo] $mod_coll,
        [bool] $check_upd
    )
    
    GeneratePath 

    $postParams = @{itemcount="$($Mods.Count)"}
    [int]$ii = 0;
    foreach ($md in $mod_coll.Mods) {
        $postParams += @{"publishedfileids[$ii]"="$($md.hreff_id)"}
        $ii++;
    }
    $YTE = Invoke-WebRequest -Uri "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/" -Method POST -UseBasicParsing -Body $postParams
    $GettedInfo = ($YTE.Content | ConvertFrom-Json).response.publishedfiledetails
    foreach ($modinf in $GettedInfo) {
        ($mod_coll.Mods | Where-Object { $_.hreff_id -eq $modinf.publishedfileid})[0].updated_time = $modinf.time_updated
    }
    [ModCls[]]$Mods_modify = @()
    foreach ($modinf in $mod_coll.Mods) {
        if($modinf.updated_time -gt $modinf.downloaded_time) {
            $Mods_modify.Add($modinf)
        }
    }
}
function CheckDownloaded {
    param (
        [string]$path_to_acf,
        [ModCls[]]$mods
    )
    if (-Not (Test-Path -Path $path_to_acf)) {
        Write-Host "Not found .acf file. All marked to download"
    }
    else {
        $k = Get-Content -raw $path_to_acf
        $k = $k.Insert(0,"{`n")
        $k = $k -replace '\t*\"\n{', ('": {')
        $k = $k -replace '\t*\"\n\t+{', ('": [' + "`n{")
        #надо добавить теперь запятые..
        foreach($line in Get-Content $path_to_acf) {
            if($line -contains '{' -or $line -contains '}' ) {
                continue
            }

        }
    }

    #смотрим файл appworkshop
    #WorkshopItemDetails -> id -> latest_manifest != -1 -> да - смотреть timetouched / нет - скачать

}
CheckDownloaded -path_to_acf "C:\Users\bigja\source\repos\DownloaderSteamCollection\Test_Kollektion\steamapps\workshop\appworkshop_4000.acf"
GetModsList -url $url