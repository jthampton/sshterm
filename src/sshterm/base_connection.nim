import std/[re, options, times, os]
import terminal

type
  BaseConnection* = ref object of RootObj
    host*: string
    username*: string
    password*: string
    port*: int
    basePromptRegex*: Option[Regex]
    pagingRegex*: Regex
    buffer*: TerminalBuffer
    lastCommand*: string
    timeout*: int
    pagingAction*: string
    disablePagingCommand*: string

proc newBaseConnection*(host: string, username: string, password: string = "",
    port: int = 22, basePromptRegex: Option[Regex] = none[Regex](),
    pagingRegex: Regex = re"(?i)--More--|RETURN|lines \d+-\d+",
    pagingAction: string = " ", disablePagingCommand: string = "",
    timeout: int = 10): BaseConnection =
  BaseConnection(
    host: host,
    username: username,
    password: password,
    port: port,
    basePromptRegex: basePromptRegex,
    pagingRegex: pagingRegex,
    buffer: newTerminalBuffer(),
    lastCommand: "",
    timeout: timeout,
    pagingAction: pagingAction,
    disablePagingCommand: disablePagingCommand
  )

method connect*(self: BaseConnection) {.base.} =
  raise newException(CatchableError, "Not implemented")

method disconnect*(self: BaseConnection) {.base.} =
  raise newException(CatchableError, "Not implemented")

method writeChannel*(self: BaseConnection, data: string) {.base.} =
  raise newException(CatchableError, "Not implemented")

method readChannel*(self: BaseConnection): string {.base.} =
  raise newException(CatchableError, "Not implemented")

proc promptHeuristic*(self: BaseConnection): Regex =
  ## Heuristic to find the prompt if not set.
  ## Network gear (# or >) and POSIX shells ($ or #).
  return re".+[#>$] ?$"

proc waitForPrompt*(self: BaseConnection, promptRegex: Option[Regex] = none[
    Regex](), timeout: int = 10): string =
  let targetRegex =
    if promptRegex.isSome:
      promptRegex.get()
    elif self.basePromptRegex.isSome:
      self.basePromptRegex.get()
    else:
      self.promptHeuristic()
  let startTime = epochTime()

  while epochTime() - startTime < timeout.float:
    let output = self.readChannel()
    if output.len > 0:
      self.buffer.append(output)

      if self.buffer.isPromptAtEnd(targetRegex):
        let res = self.buffer.data
        self.buffer.clear()
        if self.basePromptRegex.isNone:
          self.basePromptRegex = some(targetRegex)
        return res

      # Check for paging after prompt check so a real prompt wins
      if self.buffer.findPrompt(self.pagingRegex).isSome:
        self.writeChannel(self.pagingAction)
        # Continue reading until we find the real prompt
        continue

    sleep(100)

  raise newException(CatchableError, "Timeout waiting for prompt")

proc sendCommand*(self: BaseConnection, command: string, expectPrompt: Option[
    Regex] = none[Regex](), timeout: int = 10): string =
  self.lastCommand = command
  self.writeChannel(command & "\n")
  let output = self.waitForPrompt(expectPrompt, timeout)
  return stripCommandEcho(output, command)

proc detectPrompt*(self: BaseConnection, timeout: int = 10) =
  ## Detects and stores the prompt regex if not already set.
  if self.basePromptRegex.isSome:
    return
  let heuristic = self.promptHeuristic()
  discard self.waitForPrompt(some(heuristic), timeout)
  self.basePromptRegex = some(heuristic)

proc sendCommandParse*(self: BaseConnection, command: string, parser: proc(
    output: string): string, expectPrompt: Option[Regex] = none[Regex](),
    timeout: int = 10): string =
  let output = self.sendCommand(command, expectPrompt, timeout)
  return parser(output)

method disablePaging*(self: BaseConnection) {.base.} =
  if self.disablePagingCommand != "":
    discard self.sendCommand(self.disablePagingCommand)
