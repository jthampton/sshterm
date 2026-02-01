import std/[nre, strutils, options, os]
import ssh2
import base_connection, terminal

type
  SSHConnection* = ref object of BaseConnection
    session: Session
    channel: Channel
    privateKeyPath: Option[string]
    publicKeyPath: Option[string]
    passphrase: Option[string]

proc newSSHConnection*(host: string, username: string, password: string = "",
    port: int = 22, basePromptRegex: Option[Regex] = none[Regex](),
    pagingRegex: Regex = re"(?i)--More--|RETURN|lines \d+-\d+",
    pagingAction: string = " ", disablePagingCommand: string = "",
    timeout: int = 10, privateKeyPath: Option[string] = none[string](),
    publicKeyPath: Option[string] = none[string](),
    passphrase: Option[string] = none[string]()): SSHConnection =
  let res = SSHConnection(
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
    disablePagingCommand: disablePagingCommand,
    privateKeyPath: privateKeyPath,
    publicKeyPath: publicKeyPath,
    passphrase: passphrase
  )
  return res

method connect*(self: SSHConnection) =
  self.session = newSession(self.host, self.port.Port)
  if self.privateKeyPath.isSome:
    let pub = if self.publicKeyPath.isSome: self.publicKeyPath.get() else: ""
    let pass = if self.passphrase.isSome: self.passphrase.get() else: ""
    self.session.authPublicKeyFile(self.username, pub, self.privateKeyPath.get(),
        pass)
  else:
    self.session.authPassword(self.username, self.password)
  self.channel = self.session.openSession()
  self.channel.requestPty("vt100")
  self.channel.shell()
  # Set non-blocking if possible for reading
  self.channel.setBlocking(false)
  self.detectPrompt(self.timeout)
  self.disablePaging()

method disconnect*(self: SSHConnection) =
  if self.channel != nil:
    self.channel.close()
  if self.session != nil:
    self.session.disconnect()

method writeChannel*(self: SSHConnection, data: string) =
  discard self.channel.write(data)

method readChannel*(self: SSHConnection): string =
  var buf = newString(4096)
  let n = self.channel.read(buf)
  if n > 0:
    buf.setLen(n)
    return stripAnsi(buf)
  return ""
