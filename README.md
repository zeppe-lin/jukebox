OVERVIEW
========

This directory contains *jukebox*, a music player for large collections
of audio files.

This *jukebox* distribution is a fork of squentin's *gmusicbrowser* as
of version 1.1.16 with the following little differences:
  * added Papirus-Light icons
  * added Trinity-like icons to approximate the look and feel to
    [trinity-gtk-theme](https://github.com/zeppe-lin/trinity-gtk-theme)
  * removed Elementary icons
  * updated Artistinfo plugin to show all available albums from last.fm
    and search Artist on torrent trackers
  * updated Notify plugin: more actions and icon buttons if notification
    daemon supports `action-icons` capability
  * added new option "minimize main window instead of hide"
  * ported gmusicbrowser's little fixes and adjustments for new mpv
    versions

The original sources can be downloaded from:
  1. https://github.com/squentin/gmusicbrowser
  2. https://gmusicbrowser.org/download/gmusicbrowser-1.1.16.tar.gz


CAVEATS
=======

**This is a deprecated software!**
While squentin's *gmusicbrowser* is actively maintained and ported to
GTK+3.0, and has a relatively big group of users & hackers that are
continuing development, it's highly recommended to use *gmusicbrowser*
instead of *jukebox*.

The following feature-list is just a copy of *gmusicbrowser*'s features
with some additions described above in the differences.


FEATURES
--------
The main features are almost the same as *gmusicbrowser* has:
  * customizable playback backend:
    gstreamer1.x, mpg123/ogg123/..., mplayer, mpv
  * customizable window layouts
  * artist/album lock: restrict playlist to current artist/album
  * easy access to related songs (same artist/album/title)
  * simple mass-tagging and mass-renaming
  * support multiple genres for each song
  * customizable labels can be set for each song
  * filters with unlimited nesting of conditions
  * customizable weighted random mode
  * equalizer with predefined presets
  * replaygain support
  * custom playlists
  * queue mode

Plugins:
  * Albuminfo: retrieve album-relevant information (review etc.) from
    allmusic
  * App indicator: display a panel indicator in some desktops
  * Autosave: save tags/settings every N minutes
  * Desktop widgets: open special layouts as desktop widgets
  * Export: add menu entries to song contextual menu
  * Gnome mmkeys: make jukebox react to Next/Previous/Play/Stop
    multimedia keys in Gnome
  * Karaoke: display synchonized lyrics of the current song
  * last.fm: submit played songs to last.fm
  * Artistinfo: retrieve artist-relevant information from last.fm
    (albums, biography, similar artists)
  * Lullaby: schedule fade-out and stop
  * Lyrics: search and display lyrics
  * MPRIS v1: control jukebox via DBus using MPRIS v1.0 standard
  * MPRIS v2: control jukebox via DBus using MPRIS v2.0 standard
  * Notify: notify of the playing song with the system's notification
    popups
  * Now playing: run a command when playing a song
  * Picture finder: add a menu entry to artist/album context menu,
    allowing to search the picture/cover in various sources and save
    it
  * Rip: add a button to rip a CD
  * Titlebar: display a special layout in or around the titlebar of the
    focused window
  * Web context: provide context views using MozEmbed or WebKit
    wikipedia, lyrics, and custom webpages


REQUIREMENTS
============

To use mpg321/ogg123/flac123:
  * mpg321 to play mp3 files
  * ogg123 to play ogg and flac files (found in a package named
    vorbis-tools
  * flac123 to play flac files (deprecated)
  * amixer to control the volume (found in a package named alsa-utils)

To use gstreamer-0.10:
  * gstreamer perl bindings >0.06 (libgstreamer-perl or perl-GStreamer)
  * gstreamer-plugins-ugly to play mp3 files
  * gstreamer-plugins-bad to play mpc files
  * gstreamer-plugins-good to play flac files

  Note that some codec may be packaged by themselves in some
  distribution, with names like gstreamer0.10-flac or
  gstreamer0.10-musepack.

  Some additional gstreamer plugins may also be required, depending
  on which output you want to use, like oss, alsa, pulseaudio, esd.

To use mplayer or mpv:
  * mplayer or mpv

To have tray icon:
  * gtk2-trayicon perl bindings (libgtk2-trayicon-perl or
    perl-Gtk2-TrayIcon)

To consult wikipedia pages and search google for lyrics, one of:
  * gtk2-mozembed perl bindings (libgtk2-mozembed-perl or
    perl-Gtk2-MozEmbed)
  * gtk2-webkit perl bindings (perl-Gtk2-WebKit)

To control jukebox through DBus or use the included gnome multimedia
keys plugin:
  * DBus perl bindings (libnet-dbus-perl or perl-Net-DBus)


INSTALL
=======

**WIP**


MIGRATION
=========

Migration from *gmusicbrowser* is highly unrecommended since
*gmusicbrowser* is fine and well maintained program with GTK-3.0 support
(unlike jukebox).  See https://gmusicbrowser.org and
https://github.com/squentin/gmusicbrowser for more information.

Anyway...

1/2. Set library source:
```sh
sed -i 's@/mnt/data/oldmusic@/mnt/hd/actualmusic@g' jukeboxrc
```

2/2. Fix jukeboxrc fingerprint:
```sh
sed -i 's@gmbrc version=1.101502@jukeboxrc version=1.101503@g' jukeboxrc
```


LICENSE
=======

*jukebox* is licensed through the GNU General Public License v3
<https://gnu.org/licenses/gpl.html>.
Read the *COPYING* file for copying conditions.
Read the *COPYRIGHT* file for copyright notices.
