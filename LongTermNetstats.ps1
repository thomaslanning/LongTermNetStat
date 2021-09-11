$ogTime = Get-Date

##how much time per save file in minutes
$saveInterval = .25

##how much time between tests in seconds
$testInterval = 1

$path = ".\logs\"
$name = (Get-Date -format 'yyyy.MM.dd.hh.mm') + ".csv"


#check if log folder exists
if (!(Test-Path -Path ($path))){
    New-Item -ItemType Directory -Force -Path $path
}

#check if log file exists
if (!(Test-Path -Path ($path + $name))){
    New-Item -Path $path -Name $name
}

##set test IP addresses, I'm using multiple DNS services for this and will average the 4 fastest out to rule out issues server side.
$testArray = @("1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4", "208.67.222.222", "208.67.220.220")

$startTime = Get-Date
while ($true){

    ##Keep track of how many of these tests were run
    $count = 0;
    $errors = 0

    ##create array list for all values to be stored during the designated timeframe
    $pingArray = [System.Collections.ArrayList]@()
    while ((New-Timespan –Start $startTime –End (Get-Date)).TotalMinutes -le $saveInterval) {
        
        $count++

        ##create array list for ping values inside of loop
        $pingTempArray = [System.Collections.ArrayList]@()

        $time = Get-Date
        foreach ($ip in $testArray) {
            $ComputerName = $ip
            $Timeout = $testInterval * 1000
            $Filter = 'Address="{0}" and Timeout={1}' -f $ComputerName, $Timeout
            $test = Get-WmiObject -Class Win32_PingStatus -Filter $Filter | Select-Object Address, ResponseTime, Timeout
            if ($test.ResponseTime -gt 0){
                $pingTempArray += ($test).ResponseTime
            }else{
                $errors++
            }
        }

        ##count - 1 = index; index - 2 to remove the 2 last values
        $i = $pingTempArray.Count - 3

        ##remove highest 2 values
        if ($i -gt 0){
            $pingTempArray = ($pingTempArray | sort)[0..$i]
        }

        $pingArray += ($pingTempArray | Measure-Object -Average).Average

        Write-Host (New-Timespan –Start $ogTime –End (Get-Date)).TotalSeconds "seconds have passed."

        $toNextInterval = ($testInterval * 1000) - (New-Timespan –Start $time –End (Get-Date)).TotalMilliseconds

        if ( $toNextInterval -gt 0 ){
            Start-Sleep -Milliseconds $toNextInterval
        }
    }

    $stats = $pingArray | Measure-Object -Average -Maximum -Minimum

    $jitterArray = [System.Collections.ArrayList]@()

    For ($i = 1; $i -le $pingArray.count; $i++) {
        $jitter = $pingArray[$i] - $pingArray[$i - 1]
        $jitterArray += [System.Math]::Abs($jitter)
    }

    $jitterStats = $jitterArray | Measure-Object -Average -Maximum -Minimum

    $results = [psCustomObject][Ordered] @{
        Count = $pingArray.count
        Packet_Loss = (($errors/$testArray.Count) / ($count)) * 100
        Ping_Average = $stats.Average
        Ping_Min = $stats.Minimum
        Ping_Max = $stats.Maximum
        Ping_Jitter_Average = $jitterStats.Average
        Ping_Jitter_Min = $jitterStats.Minimum
        Ping_Jitter_Max = $jitterStats.Maximum
    }

    Write-Host "Saving to file..."
    $results | Export-CSV -Path ($path + $name) -append
    Write-Host "Saved."
    $startTime = Get-Date
}