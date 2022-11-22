# Copyright (c) Quentin Sculo  <squentin@free.fr>
# Copyright (c) Alexandr Savca <drop@chinarulezzz.fun>
#
# This file is part of jukebox.
#
# jukebox is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=for gmbplugin GMMKEYS
name	Gnome mmkeys
title	Gnome multimedia keys plugin
desc	Makes jukebox react to the Next/Previous/Play/Stop multimedia keys in gnome.
req	perl(Net::DBus, libnet-dbus-perl perl-Net-DBus)
=cut

package GMB::Plugin::GMMKEYS;

use strict;
use warnings;

use Net::DBus;

my %Names = (
    gnome  => 'org.gnome.SettingsDaemon /org/gnome/SettingsDaemon/MediaKeys',
    ognome => 'org.gnome.SettingsDaemon /org/gnome/SettingsDaemon'
    ,    # for gnome version until ~2.20  <2.22, I should probably remove it
    mate => 'org.mate.SettingsDaemon  /org/mate/SettingsDaemon/MediaKeys',
);

my $object;
for my $desktop (qw/gnome mate ognome/) {
    if ($object = GMB::DBus::simple_call($Names{$desktop})) {
        $object->connect_to_signal(MediaPlayerKeyPressed => \&callback);
        last;
    }
}
die "Can't find the dbus Settings Daemon for gnome or MATE\n" if $@;

my %cmd = (
    Previous => 'PrevSong',
    Next     => 'NextSong',
    Play     => 'PlayPause',
    Stop     => 'Stop',
);

sub Start {
    $object->GrabMediaPlayerKeys('jukebox', 0);
}

sub Stop {
    $object->ReleaseMediaPlayerKeys('jukebox');
}

sub prefbox {
}

sub callback {
    my ($app, $key) = @_;
    return unless $app eq 'jukebox';
    if   (my $cmd = $cmd{$key}) { ::run_command(undef, $cmd); }
    else                        { warn "gnome_mmkeys : unknown key : $key\n" }
}

1;

# vim:sw=4:ts=4:sts=4:et:cc=80
# End of file
