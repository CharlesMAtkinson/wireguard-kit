- [wireguard-kit](#wireguard-kit)
  - [Introduction](##introduction)
  - [Client and server](#client-and-server)
  - [Tested versions](#tested-versions)
  - [wireguard-kit components](#wireguard-kit-components)
  - [License and programming language](#license-and-programming-language)
  - [Installation](#installation)
  - [More](#more)
  - [Forking](#forking)

# wireguard-kit

## Introduction

WireGuard follows the Unix philosophy of doing one thing and doing it well.  It is not a complete production VPN solution.  

wireguard-kit extends WireGuard into a complete production VPN solution.

## Client and server

WireGuard itself is a peer to peer technology.

wireguard-kit configures one computer as a server and the rest as clients.
The clients have only a WireGuard connection to the server and connect to other clients via the server.

The server has:
- a WireGuard configuration stanza for each client
- an active clients log
- optionally a firewall to separate client subnets

## Tested versions

wireguard-kit server:
- was tested on Debian Bullseye
- may work on Debian derivatives including Ubuntu and its derivatives

Client configuration generated by wireguard-kit:
- was tested on:
  - Debian Buster and Bullseye clients
  - macOS 13 Ventura
  - Windows 10
- is expected to work on:
  - Android
  - iOS
  - Linux other than the tested Debian releases
  - macOS other than 13 Ventura
  - OpenWRT
  - Windows 7, 8 and 11

## wireguard-kit components

For use on the server:
- a script to:
  - generate, for a new client, the client and server configuration stanzas
  - effect the server configuration stanza
  - optionally to install on ssh-accessible Linux clients: WireGuard, the client configuration stanza and a systemd service to restart WireGuard on loss of connection
- for logging current clients:
  - a script to generate log messages
  - wireguard-logger.service and timer to run the script
  - an example crontab line to use instead of the above service
  - a logrotate configuration file to rotate the log
- to synchronise the WireGuard server configuration to a standby server:
  - a script to do the synchronisation
  - sync_wireguard_to_standby.service and timer to run the script
  - an example crontab line to use instead of the above service
- a logcheck filters file

## License and programming language

wireguard-kit uses the GPL-2.0+ license.  Its scripts are written in bash 

## Installation

wireguard-kit server can be installed using the procedure in "source/usr/share/doc/wireguard-kit/wireguard-kit user guide" .odt, .htm or .pdf either:
- from wireguard-kit_<version>.installation.tgz available from https://github.com/CharlesMAtkinson/wireguard-kit/releases
- from wireguard-kit_<version>_all.deb available from https://github.com/CharlesMAtkinson/bung_debian_packaging/releases

## More

Full documentation is in source/usr/share/doc/wireguard-kit

## Forking

When forking, please read tools/git-store-meta/README-for-wireguard-kit.md
