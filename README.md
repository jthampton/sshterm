# sshterm

Interactive SSH terminal library for Nim. It opens an interactive shell over SSH, auto-detects prompts, handles paging prompts, and provides convenience helpers to send commands and capture output with command echo stripped.

## Features
- Interactive shell session over SSH
- Prompt auto-detection with optional user-provided prompt regex
- Paging handling (`--More--` style) with automatic advancement
- Password and key-based authentication (via libssh2/ssh2 bindings)
- Command helpers that strip echoed input

## Installation
Add to your Nim project:
```
nimble install sshterm
```

## Usage
```nim
import sshterm/ssh_connection

var conn = newSSHConnection(
  host = "192.0.2.10",
  username = "admin",
  password = "secret",          # or use privateKeyPath/publicKeyPath
  port = 22,
  basePromptRegex = some(re".*[#>$] ?$"),  # optional; auto-detect if omitted
  pagingRegex = re"(?i)--More--|RETURN|lines \d+-\d+",
  pagingAction = " ",
  disablePagingCommand = "term len 0",    # optional: sent after connect
  timeout = 10
)

conn.connect()
defer: conn.disconnect()

let output = conn.sendCommand("show version", timeout = 15)
echo output
```

## Testing
### Unit tests
```
nimble test -y
```

### SSH integration tests (opt-in)
Requirements: Docker available.
1) Generate test keys (not checked in):
```
ssh-keygen -t rsa -N "" -f tests/fixtures/keys/id_rsa
# Lock down permissions (required by ssh):
chmod 600 tests/fixtures/keys/id_rsa
```
2) Start test sshd on port 2222:
```
docker compose -f docker-compose.test.yml up -d sshd-test
```
3) Run the integration suite:
```
RUN_SSH_INTEGRATION=1 nim c -r tests/test_integration_ssh.nim
```
4) Tear down:
```
docker compose -f docker-compose.test.yml down
```

## Notes
- No private keys are stored in the repo; generate your own before running integration tests.
- Prompt detection falls back to a heuristic (`.+[#>$] ?$`) if none is provided.
- Paging detection defaults to common `--More--/RETURN/lines` patterns; override per-device as needed.

If you want additional examples (e.g., with custom prompt regexes for specific network gear) or API docs, let me know.
