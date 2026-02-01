import std/[nre, options, net]
import ssh2
import libssh2
import base_connection, terminal

type
  SSHConnection* = ref object of BaseConnection
    session: libssh2.Session
    channel: libssh2.Channel
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
  var sock = newSocket()
  sock.connect(self.host, Port(self.port))

  self.session = session.initSession()
  self.session.setBlocking(true)
  self.session.handshake(sock.getFd())

  if self.privateKeyPath.isSome:
    let pub = if self.publicKeyPath.isSome: self.publicKeyPath.get() else: ""
    let pass = if self.passphrase.isSome: self.passphrase.get() else: ""
    discard self.session.authPublicKey(self.username, self.privateKeyPath.get(),
        pub, pass)
  else:
    discard self.session.authPassword(self.username, self.password)

  self.channel = libssh2.channel_open_session(self.session)
  discard libssh2.channel_request_pty(self.channel, "vt100")
  discard libssh2.channel_shell(self.channel)
  # Non-blocking session already set
  self.detectPrompt(self.timeout)
  self.disablePaging()

proc useKeyAuth*(self: SSHConnection): bool =
  ## Returns true when key-based authentication should be used.
  self.privateKeyPath.isSome

method disconnect*(self: SSHConnection) =
  if self.channel != nil:
    discard libssh2.channel_close(self.channel)
    discard libssh2.channel_free(self.channel)
  if self.session != nil:
    self.session.close_session()

method writeChannel*(self: SSHConnection, data: string) =
  discard libssh2.channel_write(self.channel, data.cstring, data.len)

method readChannel*(self: SSHConnection): string =
  var buf = newString(4096)
  let n = libssh2.channel_read(self.channel, buf.cstring, buf.len)
  if n > 0:
    buf.setLen(n)
    return stripAnsi(buf)
  return ""
