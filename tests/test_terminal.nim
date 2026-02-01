import std/[unittest, nre, strutils]
import ../src/sshterm/terminal

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
