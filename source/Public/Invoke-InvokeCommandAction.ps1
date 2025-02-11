function Invoke-InvokeCommandAction
{
    <#
    .SYNOPSIS
    Call the scriptblock that is given via Datum.

    .DESCRIPTION
    When Datum uses this handler to invoke whatever script block is given to it. The returned
    data is used as configuration data.

    .PARAMETER InputObject
    Script block to invoke

    .PARAMETER Header
    Header of the Datum data string that encapsulates the script block.
    The default is [Command= but can be customized (i.e. in the Datum.yml configuration file)

    .PARAMETER Footer
    Footer of the Datum data string that encapsulates the encrypted data. The default is ]

    .EXAMPLE
    $command | Invoke-ProtectedDatumAction

    .NOTES
    The arguments you can set in the Datum.yml is directly related to the arguments of this function.

    #>
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [object]
        $InputObject,

        [Parameter()]
        [hashtable]
        $Datum,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [object]
        $Node
    )

    $throwOnError = [bool]$datum.__Definition.DatumHandlersThrowOnError

    if ($InputObject -is [array])
    {
        $returnValue = @()
    }
    else
    {
        $returnValue = $null
    }

    foreach ($value in $InputObject)
    {
        $regexResult = ($datumInvokeCommandRegEx.Match($value).Groups['Content'].Value)
        if (-not $regexResult -and $throwOnError)
        {
            Write-Error "Could not get the content for the Datum.InvokeCommand handler, RegEx '$($datumInvokeCommandRegEx.ToString())' did not succeed." -ErrorAction Stop
        }
        elseif (-not $regexResult -and -not $throwOnError)
        {
            Write-Warning "Could not get the content for the Datum.InvokeCommand handler, RegEx '$($datumInvokeCommandRegEx.ToString())' did not succeed."
            $returnValue += $value
            continue
        }

        $datumType = Get-ValueKind -InputObject $regexResult -ErrorAction (& { if ($throwOnError)
                {
                    'Stop'
                }
                else
                {
                    'Continue'
                } })

        if ($datumType)
        {
            try
            {
                $file = $null

                # avoid TerminatingError in log if $value is an attribute of node.yml
                # -> in this case $value.__File is $null
                if( $value.__File )
                {
                    $file = Get-Item -Path $value.__File -ErrorAction Ignore
                }
            }
            catch
            {
                Write-Verbose 'Invoke-InvokeCommandAction: Nothing to catch'
            }

            if (-not $Node -and $file)
            {
                if ($file.Name -ne 'Datum.yml')
                {
                    $Node = Get-DatumCurrentNode -File $file

                    if (-not $Node)
                    {
                        return $value
                    }
                }
            }

            try
            {
                $returnValue += (Invoke-InvokeCommandActionInternal -DatumType $datumType -Datum $Datum -ErrorAction Stop).ForEach({
                        $_ | Add-Member -Name __File -MemberType NoteProperty -Value "$file" -PassThru -Force
                    })

            }
            catch
            {
                $throwOnError = [bool]$datum.__Definition.DatumHandlersThrowOnError

                if ($throwOnError)
                {
                    Write-Error -Message "Error using Datum Handler $Handler, the error was: '$($_.Exception.Message)'. Returning InputObject ($InputObject)." -Exception $_.Exception -ErrorAction Stop
                }
                else
                {
                    Write-Warning "Error using Datum Handler $Handler, the error was: '$($_.Exception.Message)'. Returning InputObject ($InputObject)."
                    $returnValue += $value
                    continue
                }
            }
        }
        else
        {
            $returnValue += $value
        }
    }

    if ($InputObject -is [array])
    {
        , $returnValue
    }
    else
    {
        $returnValue
    }
}
