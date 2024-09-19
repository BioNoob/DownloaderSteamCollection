#GM   для теста https://steamcommunity.com/sharedfiles/filedetails/?id=3298571555
#l4d2 для теста https://steamcommunity.com/sharedfiles/filedetails/?id=2921245893
#MAIN
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
    [string] $dir_path,
    [Parameter(Mandatory = $false, Position = 2)]
    [string] $login,
    [Parameter(Mandatory = $false, Position = 3)]
    [string] $passwd,
    [Parameter(Mandatory = $false, Position = 4)]
    [string] $steam_code,
    [Parameter(Mandatory = $false, Position = 5)]
    [bool] $check_updtates,
    [Parameter(Mandatory = $false, Position = 6)]
    [bool] $delete_excess,
    [Parameter(Mandatory = $false, Position = 7)]
    [int] $m,
    [Parameter(Mandatory = $false, Position = 8)]
    [int] $tries_times = 1
)
#объяснение про моды работы
#m = 1 - создается папка на каждую коллекцию
#m = 2 - смотрим директорию для модов, и по айдишнику игры смотрим какие моды там есть
# аля dir/steamapps/workshop/ --.acf files
## dir/steamapps/workshop/content/_game_id/
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
[string]$rootPath = $myinvocation.MyCommand.Path | split-Path -Parent
$header = $rootPath + '\loader.ps1'
. $header
if ([string]::IsNullOrEmpty($path)) {
    $path = $rootPath
}
$modslst = GetModsList -url $url
if ($null -eq $modslst) {
    return
}
$outp_dir = [string]::Empty
$path_to_outp_acf = [string]::Empty
GeneratePath -path $path -coll_label $modslst.title -appid $modslst.appid -outpath_root ([ref]$outp_dir) -outpath_to_acf ([ref]$path_to_outp_acf)
if (-Not (Test-Path -Path $path_to_outp_acf)) {
    #файла нет
    foreach ($m in $modslst.Mods) {
        $m.action = [ActionMark]::ToDownload
    }
}
else {
    #файл есть. если включен апдейт, проверям на апдейт
    #пометили файлы к загрузке, или записали время последнего апдейта
    CheckDownloaded -path_to_acf $path_to_outp_acf -mod_coll $modslst
    if ($check_updtates) {
        #помечаем файлы к обновлению или пропуску
        CheckUpdates -mod_coll $modslst        
    }
}
Write-Host "Mods to Download:"
$modslst.Mods | Where-Object { $_.action -eq [ActionMark]::ToDownload } | ForEach-Object {
    Write-Host "$($_.hreff_id) : $($_.title)"
}
if ($check_updtates) {
    Write-Host "Mods to Update:"
    $modslst.Mods | Where-Object { $_.action -eq [ActionMark]::ToUpdate } | ForEach-Object {
        Write-Host "$($_.hreff_id) : $($_.title)"
    }
}
if ($delete_excess) {
    Write-Host "Mods id to delete:"
    $modslst.ToDelete | ForEach-Object {
        Write-Host "$($_.id)"
    }
}
[string]$k = Read-Host "Confirm this actions? (y/n[def])"
if ($k -notmatch "(y|yes|Y|YES)") {
    return
}
#delete files
if ($delete_excess) {
    $modslst.ToDelete | ForEach-Object {
        if (-Not (Test-Path -Path $_.path)) {
            Write-Host "Skipped directory, bcs dir not found"
        }
        else {
            Remove-Item -Path $_.path -Recurse -Force
            Write-Host "Deleted $($_.id) directory"
        }
    }
}
#download new / update
if ([string]::IsNullOrEmpty($login)) {
    $login = "anonymous"
}
if ((Get-Process | Where-Object { $_.Name -like "Steam*" }).Count -gt 0) {
    [string]$k = Read-Host "Finded running Steam process`nRecomended close process. Continue? (y/n[def])"
    if ($k -notmatch "(y|yes|Y|YES)") {
        return
    }
}
CreateFileForSteamCMD -data $modslst -path $outp_dir -stm_lgn $login -stm_passwd $passwd -stm_code $steam_code -tries_times $tries_times
Read-Host "And now we done!"