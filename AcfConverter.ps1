function AcfToJson {
    param (
        [string]$path_to_acf
    )
    if (-Not (Test-Path -Path $path_to_acf)) {
        Write-Host "Not found .acf file."
        return ""
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
        return $outjson
    }
}