# Autor: LetsBash.de / SirBash.com
# Based on https://www.youtube.com/watch?v=FAn4q_55_mI

function retriveLatestSavegame {
    $lastestpath = $false;
    $lastesttime = $false;
    $savepath = ($ENV:LOCALAPPDATA + "low\Endnight\SonsOfTheForest\Saves\")
    $steamidfolders = Get-ChildItem -path $savepath
    foreach ($steamidfolder in $steamidfolders) {
        foreach ($gametype in @("Multiplayer", "SinglePlayer")) {
            $savegamepath = ($steamidfolder.fullname + "\" + $gametype)
            if (!(test-path -Path $savegamepath)) {
                continue
            }
            $savegamefolders = Get-ChildItem -path $savegamepath
            foreach ($savegamefolder in $savegamefolders) {
                $filepath = ($savegamefolder.fullname + "\SaveData.json")
                $savegame = get-item -path $filepath
                $modifiedtime = $savegame.LastWriteTime
    
                if ($lastesttime -eq $false) {
                    $lastesttime = $modifiedtime
                    $lastestpath = $savegamefolder.fullname
                }
    
                if ($modifiedtime -gt $lastesttime) {
                    $lastesttime = $modifiedtime
                    $lastestpath = $savegamefolder.fullname
                }
            }
        }
    }
    return $lastestpath
}

function reviveAll {
    param(
        [string]$lastestpath
    )

    # Sanatize
    if ($lastestpath -eq $false) {
        write-host "There are not savegames avalible" -ForegroundColor White -BackgroundColor Red
        return $false
    }

    # Create savegamefilepaths
    $GameStateSaveDataPath = ($lastestpath + "\GameStateSaveData.json")
    $SaveDataPath = ($lastestpath + "\SaveData.json")

    # Testing files
    if (!(test-path -path $GameStateSaveDataPath)) {
        write-host ($GameStateSaveDataPath + " is missing") -ForegroundColor White -BackgroundColor Red
        return $false
    }
    if (!(test-path -path $SaveDataPath)) {
        write-host ($SaveDataPath + " is missing") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    # Stage 1 - GameStateSaveData.json
    $content = getSavegame $GameStateSaveDataPath
    $change = $false
    
    if ($content -eq $false) {
        write-host ($GameStateSaveDataPath + " has no data") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    if ($content -like '*\"IsRobbyDead\":true,*') {
        $change = $true
        $content = $content -replace '[\\]["]IsRobbyDead[\\]["][:]true,', '\"IsRobbyDead\":false,'
    }

    if ($content -like '*\"IsVirginiaDead\":true,*') {
        $change = $true
        $content = $content -replace ('[\\]["]IsVirginiaDead[\\]["][:]true,'), '\"IsVirginiaDead\":false,'
    }

    if ($change -eq $true) {
        if (writeSavegame $GameStateSaveDataPath $content) {
            write-host ($GameStateSaveDataPath + " savegame modified") -ForegroundColor green -BackgroundColor Black
        }
        else {
            write-host ($GameStateSaveDataPath + " could not write to savegame") -ForegroundColor yellow -BackgroundColor Black
            return $false
        }
    }
    else {
        write-host ($SaveDataPath + " savegame does not need modification") -ForegroundColor yellow -BackgroundColor Black
        return $false
    }

    # Stage 2 - SaveData.json
    $content = getSavegame $SaveDataPath
    $original = $content 

    if ($content -eq $false) {
        write-host ($SaveDataPath + " has no data") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    if ($content -like '*,\"TypeId\":9,*') {
        $subcontent = $content -split '[,][\\]["]TypeId[\\]["][:]9,'
        $oldnpc = ',\"TypeId\":9,' + ($subcontent[1] -split '[\\]["]StateFlags[\\]["]')[0]
        $newnpc = $oldnpc -replace '[\\]["]Health[\\]["][:][0-9\-\.]*[,]', '\"Health\":100.0,'
        $newnpc = $newnpc -replace '[\\]["]State[\\]["][:][0-9\-]*[,]', '\"State\":2,'
        $content = $content -replace [regex]::escape($oldnpc), $newnpc
        write-host ($SaveDataPath + " type id 9 (Kelvin) is modified") -ForegroundColor green -BackgroundColor Black
    }

    if ($content -like '*,\"TypeId\":10,*') {
        $subcontent = $content -split '[,][\\]["]TypeId[\\]["][:]10,'
        $oldnpc = ',\"TypeId\":10,' + ($subcontent[1] -split '[\\]["]StateFlags[\\]["]')[0]
        $newnpc = $oldnpc -replace '[\\]["]Health[\\]["][:][0-9\-\.]*[,]', '\"Health\":100.0,'
        $newnpc = $newnpc -replace '[\\]["]State[\\]["][:][0-9\-]*[,]', '\"State\":2,'
        $content = $content -replace [regex]::escape($oldnpc), $newnpc
        write-host ($SaveDataPath + " type id 10 (Virginia) is modified") -ForegroundColor green -BackgroundColor Black
    }
    else {
        $find = '[\\]["]Actors[\\]["][:][\[]'
        $replace = '\"Actors\":[{\"UniqueId\":709,\"TypeId\":10,\"FamilyId\":0,\"Position\":{\"x\":-543.530334,\"y\":125.27742,\"z\":419.568665},\"Rotation\":{\"x\":0.0,\"y\":0.990344,\"z\":0.0,\"w\":0.1386319},\"SpawnerId\":-1797797444,\"ActorSeed\":787901937,\"VariationId\":0,\"State\":2,\"GraphMask\":1,\"EquippedItems\":null,\"OutfitId\":-1,\"NextGiftTime\":0.0,\"LastVisitTime\":-100.0,\"Stats\":{\"Health\":120.0,\"Anger\":0.0,\"Fear\":0.0,\"Fullness\":0.0,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":0.0},\"StateFlags\":0},'
        $content = $content -replace $find, $replace
        write-host ($SaveDataPath + " type id 10 (Virginia) was not found in the savegame: adding with unique id 709 on the beginning of actors") -ForegroundColor yellow -BackgroundColor Black
    }

    if ($content -like '*,{\"TypeId\":9,\"PlayerKilled\":*') {
        $content = $content -replace '[{][\\]["]TypeId[\\]["][:]9[,][\\]["]PlayerKilled[\\]["][:][0-9]*[}]', '{\"TypeId\":9,\"PlayerKilled\":0}'
        write-host ($SaveDataPath + " type id 9 (Kelvin) kill counter reset") -ForegroundColor green -BackgroundColor Black
    }

    if ($content -like '*,{\"TypeId\":10,\"PlayerKilled\":*') {
        $content = $content -replace '[{][\\]["]TypeId[\\]["][:]10[,][\\]["]PlayerKilled[\\]["][:][0-9]*[}]', '{\"TypeId\":10,\"PlayerKilled\":0}'
        write-host ($SaveDataPath + " type id 10 (Virginia) kill counter reset") -ForegroundColor green -BackgroundColor Black
    }

    if ($original -ne $content) {
        if (writeSavegame $SaveDataPath $content) {
            write-host ($SaveDataPath + " savegame modified") -ForegroundColor green -BackgroundColor Black
        }
        else {
            write-host ($SaveDataPath + " could not write to savegame") -ForegroundColor yellow -BackgroundColor Black
            return $false
        }
    }
    else {
        write-host ($SaveDataPath + " savegame does not need modification") -ForegroundColor yellow -BackgroundColor Black
        return $false
    }

    return $true

    # Sample Code from a savegame
    #
    # GameStateSaveData.json
    # \"IsRobbyDead\":true,
    # \"IsVirginiaDead\":false,
    #
    # SaveData.json - Kelvin
    # {\"UniqueId\":711,\"TypeId\":9,\"FamilyId\":0,\"Position\":{\"x\":-1236.10144,\"y\":99.1763458,\"z\":1396.66663},\"Rotation\":{\"x\":0.0,\"y\":-0.15448457,\"z\":0.0,\"w\":-0.9879952},\"SpawnerId\":0,\"ActorSeed\":-1228319904,\"VariationId\":0,\"State\":6,\"GraphMask\":1,\"EquippedItems\":[504],\"OutfitId\":-1,\"NextGiftTime\":0.0,\"LastVisitTime\":-100.0,\"Stats\":{\"Health\":100,\"Anger\":60.25404,\"Fear\":99.97499,\"Fullness\":6.249775,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":0.0},\"StateFlags\":0}
    # {\"TypeId\":9,\"PlayerKilled\":1}
    #
    # SaveData.json - Virginia
    # {\"UniqueId\":709,\"TypeId\":10,\"FamilyId\":0,\"Position\":{\"x\":-543.530334,\"y\":125.27742,\"z\":419.568665},\"Rotation\":{\"x\":0.0,\"y\":0.990344,\"z\":0.0,\"w\":0.1386319},\"SpawnerId\":-1797797444,\"ActorSeed\":787901937,\"VariationId\":0,\"State\":2,\"GraphMask\":1,\"EquippedItems\":null,\"OutfitId\":-1,\"NextGiftTime\":0.0,\"LastVisitTime\":-100.0,\"Stats\":{\"Health\":120.0,\"Anger\":0.0,\"Fear\":0.0,\"Fullness\":0.0,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":0.0},\"StateFlags\":0}
    # {\"TypeId\":10,\"PlayerKilled\":0}

}

function getSavegame {
    param(
        [string]$filepath
    )

    if (!(test-path -path $filepath)) {
        write-host ($filepath + " does not exist") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    return (Get-Content -Raw $filepath)
}

function writeSavegame {
    param(
        [string]$filepath,
        [string]$content
    )

    if (!(test-path -path $filepath)) {
        write-host ($filepath + " does not exist") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    $content

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($filepath, $content, $Utf8NoBomEncoding)
    return $true
}

$lastestpath = retriveLatestSavegame
$result = reviveAll $lastestpath
