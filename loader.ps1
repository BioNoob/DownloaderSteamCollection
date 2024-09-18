#алгоритм
#1. Грузим состав коллекции (GetModsList)
#2. Чекаем есть ли папка по пути с параметра (или дефолт), если есть смотрим флаг проверки апдейтов
#2.1 Если проверять, то смотрим дату скачки (CheckDownloaded), грузим инфу по модам, составляем список к закачке (CreateFileForSteamCMD)
#2.2 Если не проверять, то сразу составляем список к закачке (CreateFileForSteamCMD)
#если нету директории, то сразу составляем список к закачке (CreateFileForSteamCMD)
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

enum ActionMark {
    ToDownload
    ToUpdate
    ToResume
    Unknown
}
class ModCls {
    [string] $hreff_id
    [string] $title
    [int32] $updated_time
    [int32] $downloaded_time_file
    [ActionMark] $action
    ModCls() {
        $this.hreff_id = 
        $this.title = ""
        $this.updated_time = 0
        $this.downloaded_time_file = 0
        $this.action = [ActionMark]::Unknown
    }
    ModCls([string] $rf, [string]$tl) {
        $this.hreff_id = $rf
        $this.title = $tl
        $this.updated_time = 0
        $this.downloaded_time_file = 0
        $this.action = [ActionMark]::Unknown
    }
}
class ModToDelete {
    [string] $path
    [string] $id
    ModToDelete([string] $_path, [string] $_id) {
        $this.path = $_path
        $this.id = $_id
    }
}
class ModCollInfo {
    [string] $appid
    [string] $title
    [ModCls[]] $Mods
    [ModToDelete[]] $ToDelete
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
        [ref]$outpath_root,
        [ref]$outpath_to_acf
    )
    $outpath_root.Value = $path + "\$coll_label"
    $outpath_to_acf.Value = "$($outpath_root.Value)\steamapps\workshop\appworkshop_$appid.acf"
}
function CreateFileForSteamCMD {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ModCollInfo] $data,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $path = "",
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $stm_lgn = "anonymous",
        [Parameter(Mandatory = $false, Position = 3)]
        [string] $stm_passwd = "",
        [Parameter(Mandatory = $false, Position = 4)]
        [string] $stm_code = ""         
    )
    if ([string]::IsNullOrEmpty($path)) {
        $path = $rootPath
    }
    $pp = $path + "\$($data.title)"
    if (-Not (Test-Path -Path $pp)) {
        New-Item -Path $path -Name $data.title -ItemType "directory"
    }
    [string]$script = "force_install_dir $($pp)`n"
    $script += "login $stm_lgn $stm_passwd $stm_code`n"
    $data.Mods | Where-Object { $_.action -eq [ActionMark]::ToUpdate -or $_.action -eq [ActionMark]::ToDownload } | ForEach-Object {
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
<#
.SYNOPSIS
    Вернет ModCollInfo которые находятся в запрошенной коллекции
#>
function GetModsList {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $url
    )
    $libPath = ".\HtmlAgilityPack.dll"
    Add-Type -Path $libPath
    $web = New-Object -TypeName "HtmlAgilityPack.HtmlWeb"
    $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
    try {
        $dom = $web.Load($url)    
    }
    catch {
        Write-Host "Download Error. Pls try again"
        return $null
    }
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
    return  [ModCollInfo]::new($appid, $boxtitle, $modslist)
}
#Использовать если проверяем уже скаченное
function CheckUpdates {
    param (
        [ModCollInfo]$mod_coll
    )
    $postParams = @{itemcount = "$($Mods.Count)" }
    [int]$ii = 0;
    foreach ($md in $mod_coll.Mods) {
        $postParams += @{"publishedfileids[$ii]" = "$($md.hreff_id)" }
        $ii++;
    }
    $YTE = Invoke-WebRequest -Uri "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/" -Method POST -UseBasicParsing -Body $postParams
    $GettedInfo = ($YTE.Content | ConvertFrom-Json).response.publishedfiledetails
    foreach ($modinf in $GettedInfo) {
        ($mod_coll.Mods | Where-Object { $_.hreff_id -eq $modinf.publishedfileid })[0].updated_time = $modinf.time_updated
    }
    foreach ($modinf in $mod_coll.Mods) {
        if ($modinf.updated_time -gt $modinf.downloaded_time_file) {
            $modinf.action = [ActionMark]::ToUpdate 
        }
        else {
            $modinf.action = [ActionMark]::ToResume 
        }
    }
}
function AcfToJson {
    param (
        [string]$path_to_acf
    )
    if (-Not (Test-Path -Path $path_to_acf)) {
        Write-Host "Not found .acf file. All marked to download"
    }
    else {
        $k = Get-Content $path_to_acf
        [string]$outjson = "{`n"
        for ($i = 0; $i -lt $k.Count; $i++) {
            #если текущая не откр. скобка
            $cur = $k[$i].Trim()
            if (($i + 1) -ge $k.Count) {
                $outjson += "}`n}"
                return $outjson
            }
            $nex = $k[$i + 1].Trim()
            if ($cur -ne '{') {
                #если след линия не откр скобка               
                if ($nex -ne '{') {
                    #то "":""
                    $a = $cur -split '\t+'
                    $a = $a -join ': '
                    #если не последний элемент
                    if ($nex -ne '}') {
                        $a += ",`n"
                    }
                    else {
                        #если последний, не ставим запятую
                        $a += "`n"
                    }
                    $outjson += $a
                }
                else {
                    #если след открыв. скобка
                    #то "" :\n
                    $outjson += $cur + ":`n"
                }
            }
            else {
                $outjson += $cur + "`n"
            }
        }
    }
}
function CheckDownloaded {
    param (
        [string]$path_to_acf,
        [ModCollInfo]$mod_coll
    )
    $json = (AcfToJson -path_to_acf $path_to_acf | ConvertFrom-Json).AppWorkshop
    $mods_j = $json.WorkshopItemDetails
    foreach ($mod in $mod_coll.Mods) {
        if (-not ($mods_j.PSObject.Properties.Name -contains $mod.hreff_id)) {
            #в файле нету записи
            $mod.action = [ActionMark]::ToDownload
        }
        else {
            $el = ($mods_j.PSObject.Properties | Where-Object Name -Contains $mod.hreff_id)[0]
            if ($null -ne $el) {
                $el = $el.Value
            }
            else {
                Write-Host "Coll check error"
                return
            }
            if ($el.manifest -ne "-1") {
                #записали время скачки по файлу
                $mod.downloaded_time_file = $el.timetouched
                #вставляем сразу, если что поменяем в скрипте проверки
                $mod.action = [ActionMark]::ToResume
            }
            else {
                #файл недокачался когда то
                $mod.action = [ActionMark]::ToDownload   
            }
        }
    }
    #проверка модов к удалению (если нету в списке модов, но есть в файле)
    $mod_coll.ToDelete = @()
    foreach ($file_mod in $mods_j.PSObject.Properties.Name) {
        $b = $mod_coll.Mods | Where-Object { $_.hreff_id -Contains $file_mod }
        if ($null -eq $b) {
            $mod_coll.ToDelete += [ModToDelete]::new(($path_to_acf | Split-Path) + "\content\$($mod_coll.appid)\$file_mod", $file_mod)
        }
    }
}
