function Format-TrelloUriToJson {
    param ($url)
    Write-Debug "Formatting $url"
    $prefix = "https://trello.com/b/"
    $url = $url -replace $prefix,""
    $identifier = "$($url.Split("/")[0])"
    $name = "$($url.Split("/")[1])"
    $url = $prefix + $identifier + ".json"
    Write-Debug "Returning $url"
    return $url, $name
}

# Only returns the last 1000 actions from public boards
function Import-TrelloActivity {
    param ($url, $date = $null)
    $actions = @()
    $url, $name = Format-TrelloUriToJson $url
    $j = ConvertFrom-Json $(Invoke-WebRequest $url)     

    $cards = $( 
        $j.cards | where { $_.closed -eq $False -and $(
            if ($date) { 
                $(get-date $_.dateLastActivity) -ge $(get-date $date)
            } else {
                $true
            } 
        )} | select @{n="Cards"; e={"* $($_.Name.SubString(0, $( if ($_.Name.Length -lt 50){ $_.Name.Length } else { 50 } )))"}}, @{n="LastActivity";e={"$(get-date $_.dateLastActivity)"}} |
        sort "LastActivity" -Descending
    ) 

     
    foreach ($action in $j.actions){
        $actions += [pscustomobject]@{ 
            Username = $($action.memberCreator.username); 
            ActionType = $action.type; 
            Date = $(Get-Date $action.date); 
        } 
    }
      
    $acts = $( 
        $actions | 
        where { 
            if ($date) { 
                $(get-date $_.Date) -ge $(get-date $date)
            } else {
                $true
            } 
        } | select username, @{name="date";e={"$($(get-date $_.date).Date)"}} | group date, username | select Count, @{n="Date";e={$($_.Name -split ",")[0] -replace ' 00:00:00',''}}, @{n="User";e={$_.Group.Username | select -Unique}} | sort Date -Descending
    )
    
    return $cards, $acts, $name
}

$trello_boards = @{
    "dbatools-io"="https://trello.com/b/atkqo18g/dbatools-io"
}

$asOfDate = $(Get-Date).AddDays(-10).Date

$trello_boards | %{ 
    $_.Values | % {        
        $board_cards, $board_actions, $board_name = Import-TrelloActivity $_ $asOfDate           
        write-output "** $board_name activity since $asOfDate **"
        $board_actions | ft
        write-output "** $board_name cards touched since $asOfDate **"
        $board_cards | ft
    }
}