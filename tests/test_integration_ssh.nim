import std/[unittest, os, strutils, nre]
import ../src/sshterm/[ssh_connection, base_connection]

# Integration test against local dockerized OpenSSH server.
# Requires: RUN_SSH_INTEGRATION=1 and sshd-test running on localhost:2222
# (started via docker-compose.test.yml).

let runIntegration = getEnv("RUN_SSH_INTEGRATION") != ""

when isMainModule:
  if not runIntegration:
    echo "Skipping SSH integration tests (set RUN_SSH_INTEGRATION=1 to enable)."
    quit(0)

  suite "SSH Integration":
    test "password auth executes command":
      var conn = newSSHConnection(
        host = "127.0.0.1",
        username = "testuser",
        password = "testpass",
        port = 2222,
        basePromptRegex = some(re".*[$#] ?$"),
        timeout = 10
      )
      conn.connect()
      defer: conn.disconnect()
      let first = conn.sendCommand("echo ready", timeout = 10)
      check first.contains("ready")
      let second = conn.sendCommand("pwd", timeout = 10)
      check second.len > 0

    test "key auth executes command":
      let priv = "tests/fixtures/keys/id_rsa"
      let pub = "tests/fixtures/keys/id_rsa.pub"
      if not (fileExists(priv) and fileExists(pub)):
        skip()
      
      var conn = newSSHConnection(
        host = "127.0.0.1",
        username = "testuser",
        port = 2222,
        basePromptRegex = some(re".*[$#] ?$"),
        privateKeyPath = some(priv),
        publicKeyPath = some(pub),
        passphrase = none[string](),
        timeout = 10
      )
      conn.connect()
      defer: conn.disconnect()
      let output = conn.sendCommand("echo keyready", timeout = 10)
      check output.contains("keyready")
      let second = conn.sendCommand("whoami", timeout = 10)
      check second.contains("testuser")
