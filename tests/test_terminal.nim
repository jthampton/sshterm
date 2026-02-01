import std/[unittest, re, strutils, options]
import ../src/sshterm/[terminal, base_connection, ssh_connection]

suite "Terminal Emulation":
  test "ANSI stripping":
    let input = "\x1B[1;31mRed Text\x1B[0m"
    check stripAnsi(input) == "Red Text"

  test "Prompt detection at end":
    var buffer = newTerminalBuffer()
    let promptRegex = re".+[#>] $"
    buffer.append("Switch# ")
    check buffer.isPromptAtEnd(promptRegex) == true

    buffer.append("show ip int brief\r\n")
    check buffer.isPromptAtEnd(promptRegex) == false

    buffer.append("Switch# ")
    check buffer.isPromptAtEnd(promptRegex) == true

  test "New paging pattern detection":
    let pagingRegex = re"(?i)--More--|RETURN|lines \d+-\d+"
    var buffer = newTerminalBuffer()

    buffer.append("--More--")
    check buffer.findPrompt(pagingRegex).isSome

    buffer.clear()
    buffer.append("Press RETURN to continue")
    check buffer.findPrompt(pagingRegex).isSome

    buffer.clear()
    buffer.append("lines 10-20")
    check buffer.findPrompt(pagingRegex).isSome

  test "Command echo stripping":
    let command = "show clock"
    let output = "show clock\r\n09:00:00 UTC Sat Jan 31 2026\r\nSwitch# "
    let stripped = stripCommandEcho(output, command)
    check stripped.startsWith("09:00:00")

type
  FakeConnection = ref object of BaseConnection
    readQueue: seq[string]
    readIndex: int
    writes: seq[string]

proc newFakeConnection(reads: seq[string], disablePagingCommand = ""): FakeConnection =
  FakeConnection(
    host: "h",
    username: "u",
    password: "p",
    port: 22,
    basePromptRegex: none[Regex](),
    pagingRegex: re"(?i)--More--|RETURN|lines \d+-\d+",
    buffer: newTerminalBuffer(),
    lastCommand: "",
    timeout: 1,
    pagingAction: " ",
    disablePagingCommand: disablePagingCommand,
    readQueue: reads,
    readIndex: 0,
    writes: @[]
  )

method connect*(self: FakeConnection) = discard
method disconnect*(self: FakeConnection) = discard
method writeChannel*(self: FakeConnection, data: string) =
  self.writes.add(data)
method readChannel*(self: FakeConnection): string =
  if self.readIndex < self.readQueue.len:
    let res = self.readQueue[self.readIndex]
    self.readIndex.inc
    return res
  return ""

suite "Connection behavior":
  test "detectPrompt stores heuristic when unset":
    var conn = newFakeConnection(@["Switch# "])
    conn.detectPrompt(1)
    check conn.basePromptRegex.isSome

  test "waitForPrompt sends paging action when paging detected":
    var conn = newFakeConnection(@["--More--", "Switch# "])
    let output = conn.waitForPrompt(some(re"Switch# $"), timeout = 1)
    check output.contains("Switch# ")
    check conn.writes.len == 1
    check conn.writes[0] == " "

  test "disablePaging issues command once":
    var conn = newFakeConnection(@["Switch# "], disablePagingCommand = "term len 0")
    conn.disablePaging()
    check conn.writes.len == 1
    check conn.writes[0].startsWith("term len 0")

  test "ssh connection uses key auth when key present":
    let connWithKey = newSSHConnection("h", "u", privateKeyPath = some("/id_rsa"))
    check connWithKey.useKeyAuth()
    let connNoKey = newSSHConnection("h", "u")
    check connNoKey.useKeyAuth() == false
