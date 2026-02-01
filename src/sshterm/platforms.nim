import std/tables
import base_connection

type
  PlatformConfig* = object
    disablePagingCommand*: string
    # Add more platform-specific settings here later (e.g. default prompts)

let PlatformConfigs* = {
  "cisco_ios": PlatformConfig(disablePagingCommand: "terminal length 0"),
  "cisco_asa": PlatformConfig(disablePagingCommand: "terminal length 0"),
  "cisco_nxos": PlatformConfig(disablePagingCommand: "terminal length 0"),
  "paloalto_panos": PlatformConfig(disablePagingCommand: "set cli pager off"),
  "arista_eos": PlatformConfig(disablePagingCommand: "terminal length 0"),
  "juniper_junos": PlatformConfig(disablePagingCommand: "set cli screen-length 0"),
  "hp_procurve": PlatformConfig(disablePagingCommand: "no page"),
}.toTable

proc setPlatform*(self: BaseConnection, platform: string) =
  if PlatformConfigs.contains(platform):
    self.disablePagingCommand = PlatformConfigs[platform].disablePagingCommand
