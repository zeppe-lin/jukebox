# Copyright (c) Quentin Sculo  <squentin@free.fr>
# Copyright (c) Alexandr Savca <alexandr.savca89@gmail.com>
#
# This file is part of jukebox.
#
# jukebox is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=for gmbplugin RIP
name   Rip
title  Rip plugin
desc   Add a button to rip a CD
=cut

package GMB::Plugin::RIP;

use strict;
use warnings;

use constant {
    OPT => 'PLUGIN_RIP_',    #used to identify the plugin and its options
};

::SetDefaultOptions(OPT, program => 'soundjuicer');

my %Programs = (
    # id => [name,cmd]
    soundjuicer => ['sound-juicer', 'sound-juicer'],
    grip        => ['grip',         'grip'],
    xcfa        => ['xcfa',         'xcfa'],
    custom      => ['custom'],
);

my %button_definition = (
    class        => 'Layout::Button',
    stock        => 'gtk-cdrom',
    tip          => 'Launch ripping program',
    activate     => \&Launch,
    autoadd_type => 'button main',
);

sub Start {
    Layout::RegisterWidget(PluginRip => \%button_definition);
}

sub Stop {
    Layout::RegisterWidget('PluginRip');
}

sub prefbox {
    my $vbox  = Gtk2::VBox->new(::FALSE, 2);
    my $sg1   = Gtk2::SizeGroup->new('horizontal');
    my $sg2   = Gtk2::SizeGroup->new('horizontal');
    my $entry = ::NewPrefEntry(
        OPT . 'custom', "Custom command :",
        sizeg1 => $sg1,
        sizeg2 => $sg2,
        tip    => 'Command to launch when the button is pressed'
    );
    my %list  = map { $_, $Programs{$_}[0] } keys %Programs;
    my $combo = ::NewPrefCombo(
        OPT . 'program',
        \%list,
        text => "Ripping software :",
        cb   => sub {
            $entry->set_sensitive($::Options{OPT . 'program'} eq 'custom');
        },
        sizeg1 => $sg1,
        sizeg2 => $sg2
    );
    $entry->set_sensitive($::Options{OPT . 'program'} eq 'custom');
    $vbox->pack_start($_, ::FALSE, ::FALSE, 2) for $combo, $entry;
    return $vbox;
}

sub Launch {
    my $program = $::Options{OPT . 'program'};
    my $cmd =
        $program eq 'custom'
      ? $::Options{OPT . 'custom'}
      : $Programs{$program}[1];
    ::forksystem($cmd) if $cmd;
}

1;

# vim: sw=4 ts=4 sts=4 et cc=80
# End of file.
