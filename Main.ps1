##для теста https://steamcommunity.com/sharedfiles/filedetails/?l=russian&id=3298571555
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
    [string] $login,
    [Parameter(Mandatory = $false, Position = 2)]
    [string] $passwd,
    [Parameter(Mandatory = $false, Position = 3)]
    [string] $steam_code,
    [Parameter(Mandatory = $false, Position = 4)]
    [bool] $check_updtates,
    [Parameter(Mandatory = $false, Position = 5)]
    [string] $dir_path
)
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
[string]$rootPath = $myinvocation.MyCommand.Path | split-Path -Parent
$header = $rootPath + '\loader.ps1'
. $header
if ([string]::IsNullOrEmpty($path)) {
    $path = $rootPath
}
#CheckDownloaded -path_to_acf "C:\Users\bigja\source\repos\DownloaderSteamCollection\Test_Kollektion\steamapps\workshop\appworkshop_4000.acf"
$modslst = GetModsList -url $url
if ($null -eq $modslst) {
    return
}
$outp_dir = [string]::Empty
$path_to_outp_acf = [string]::Empty
GeneratePath -path $path -coll_label $modslst.title -appid $modslst.appid -outpath_root ([ref]$outp_dir) -outpath_to_acf ([ref]$path_to_outp_acf)
if (-Not (Test-Path -Path $path_to_outp_acf)) {
    #файла нет
    if ($check_updtates) {
        $k = Read-Host "Check updates is enabled, but .acf not found in directory`nContinue with download all? (y/n[def])"
        if ($k -notlike "^(y|yes|Y|YES)$") {
            return
        }
    }
    foreach ($m in $modslst.Mods) {
        <# $m is tmod$modslst.Mods item #>
        $m.action = [ActionMark]::ToDownload
    }
}
else {
    #файл есть. если включен апдейт, проверям на апдейт, если нет - предупреждение о замене и перекачке
    #а еще надо проверить что все ли скачано.. а потом уже спрашивать о перезаписи
    #пометили файлы к загрузке, или записали время последнего апдейта
    CheckDownloaded -path_to_acf $path_to_outp_acf -mod_coll $modslst
    if ($check_updtates) {
        #помечаем файлы к обновлению или пропуску
        CheckUpdates -mod_coll $modslst        
    }
    else {
        
        $k = Read-Host "Check updates is disabled, .acf is found in directory`nContinue with download all? (y/n[def])"
        if ($k -notlike "^(y|yes|Y|YES)$") {
            return
        }
    }
}