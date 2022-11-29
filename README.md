# signed-http-ping
Simple, HTTP-based Client Server Monitoring with rotating values

## Your Situation

- You need to monitor the availability of a system via network.
- You want a bit more than a predictable string

## Assumptions

- Monitoring Client and Server return identical System Times
- Ports/Networking are available

## How it works

- The Client computes a Hash value out of the current time/minute and a shared secret in a loop.
- Every minute, the Client sends such a new value as http get request to the Server.
- The Server pre-computes a window of 10 hashes using the same time and the same shared secret.
- When the server receives a valid hash request from the client, the hash is removed from the list of expected hashes.
- Every five minutes, the server checks the list of remaining hashes. If not enough hashes were received /removed (monitoring failed), an e-Mail is sent to notify that there are gaps in the monitoring.

