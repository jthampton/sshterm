import std/[re, strutils, options]

type
  TerminalBuffer* = object
    data: string
    maxSize: int

let
  ANSI_ESCAPE_REGEX = re"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"

proc newTerminalBuffer*(maxSize: int = 65535): TerminalBuffer =
  TerminalBuffer(data: "", maxSize: maxSize)

proc append*(buffer: var TerminalBuffer, content: string) =
  buffer.data.add(content)
  if buffer.data.len > buffer.maxSize:
    buffer.data = buffer.data[^buffer.maxSize..^1]

proc stripAnsi*(content: string): string =
  content.replace(ANSI_ESCAPE_REGEX, "")

proc clear*(buffer: var TerminalBuffer) =
  buffer.data = ""

proc data*(buffer: TerminalBuffer): string =
  buffer.data

proc findPrompt*(buffer: TerminalBuffer, promptRegex: Regex): Option[tuple[
    start: int, stop: int]] =
  if contains(buffer.data, promptRegex):
    # With end-anchored patterns, we don't need exact bounds for callers.
    return some((0, buffer.data.len - 1))
  return none[tuple[start: int, stop: int]]()

proc isPromptAtEnd*(buffer: TerminalBuffer, promptRegex: Regex): bool =
  # Patterns are expected to be end-anchored; contains is sufficient.
  contains(buffer.data, promptRegex)

proc stripCommandEcho*(output: string, command: string): string =
  ## Removes the echo of the sent command from the output.
  ## Note: Commands often end with \r\n or \n.
  let cmd = command.strip(leading = false, trailing = true)
  if output.startsWith(cmd):
    var outputStripped = output[cmd.len..^1]
    # Also strip leading newline if present
    outputStripped = outputStripped.strip(leading = true, trailing = false,
        chars = {'\r', '\n'})
    return outputStripped
  return output

proc escapeRegexLiteral*(content: string): string =
  ## Escapes characters with special meaning in regex patterns.
  var res = newStringOfCap(content.len * 2)
  for ch in content:
    if ch in {'\\', '.', '+', '*', '?', '^', '$', '(', ')', '[', ']', '{', '}', '|'}:
      res.add('\\')
    res.add(ch)
  return res
