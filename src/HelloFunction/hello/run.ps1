using namespace System.Net

param($Request, $TriggerMetadata)

$responseBody = @{
    message = 'hello from private function'
    utcTime = [DateTime]::UtcNow.ToString('o')
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Headers = @{
        'Content-Type' = 'application/json'
    }
    Body = ($responseBody | ConvertTo-Json -Depth 3)
})
