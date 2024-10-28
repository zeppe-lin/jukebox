# Copyright (C) Quentin Sculo  <squentin@free.fr>
# Copyright (C) Alexandr Savca <alexandr.savca89@gmail.com>
#
# This file is part of jukebox.
#
# jukebox is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=for gmbplugin NOTIFY
name   Notify
title  Notify plugin
desc   Notify you of the playing song with the system's notification popups
req    perl(Gtk2::Notify, p5-gtk2-notify libgtk2-notify-perl perl-Gtk2-Notify)
=cut

package GMB::Plugin::NOTIFY;

use strict;
use warnings;

use constant { OPT => 'PLUGIN_NOTIFY_', };

use Gtk2::Notify -init, ::PROGRAM_NAME;

::SetDefaultOptions(OPT,
    title   => "%S",
    text    => "<i>by</i> %a\\n<i>from</i> %l",
    picsize => 50,
    timeout => 5
);

my $notify;
my ($Daemon_name, $can_actions, $can_action_icons, $can_body);

sub Start {
    $notify = Gtk2::Notify->new('empty', 'empty');

    #$notify->set_urgency('low');
    #$notify->set_category('music'); #is there a standard category for that ?
    my ($name, $vendor, $version, $spec_version) = Gtk2::Notify->get_server_info;
    $Daemon_name = "$name $version ($vendor)";
    my @caps = Gtk2::Notify->get_server_caps;
    for (@caps) {
        if    ($_ eq 'body')         { $can_body         = 1 }
        elsif ($_ eq 'actions')      { $can_actions      = 1 }
        elsif ($_ eq 'action-icons') { $can_action_icons = 1 }
    }
    set_actions();
    ::Watch($notify, 'PlayingSong', \&Changed);
    $::Command{PopupNotify} = [\&Changed, "Popup notify window"];
}

sub Stop {
    ::UnWatch_all($notify);
    $notify = undef;
    delete $::Command{PopupNotify};
}

sub prefbox {
    my $vbox        = Gtk2::VBox->new(::FALSE, 2);
    my $sg1         = Gtk2::SizeGroup->new('horizontal');
    my $sg2         = Gtk2::SizeGroup->new('horizontal');
    my $replacetext = ::MakeReplaceText('talydngLfS');
    my $summary     = ::NewPrefEntry(
        OPT . 'title',
        "Summary :",
        sizeg1 => $sg1,
        sizeg2 => $sg2,
        tip    => $replacetext
    );
    my $body = ::NewPrefEntry(
        OPT . 'text',
        "Body :",
        sizeg1 => $sg1,
        sizeg2 => $sg2,
        width  => 40,
        tip    => $replacetext . "\n\n"
          . "You can use some markup, eg :\n"
          . "<b>bold</b> <i>italic</i> <u>underline</u>\n"
          . "Note that the markup may be ignored by the notification daemon",
    );
    my $size = ::NewPrefSpinButton(
        OPT . 'picsize', 0, 1000,
        step   => 10,
        page   => 40,
        text   => "Picture size : %d",
        sizeg1 => $sg1,
        tip =>
          "Note that some notification daemons resize the displayed picture"
    );
    my $timeout = ::NewPrefSpinButton(
        OPT . 'timeout', 0, 9999,
        step   => 2,
        page   => 5,
        text   => "Timeout : %d seconds",
        sizeg1 => $sg1,
        digits => 1
    );
    my $custom_actions = ::NewPrefCheckButton(
        OPT . 'custom_actions',
        "Display prev/stop/next actions",
        cb => \&set_actions
    );
    my $default_action = ::NewPrefCheckButton(
        OPT . 'default_action',
        "Show main window by clicking the notification",
        cb => \&set_actions
    );
    for ($custom_actions, $default_action) {
        $_->set_sensitive($can_actions);
        $_->set_tooltip_text(
            "Actions are not supported by current notification daemon : "
              . $Daemon_name)
          unless $can_actions;
    }

    $body->set_sensitive($can_body);
    $body->set_tooltip_text(
        "Body text is not supported by current notification daemon : "
          . $Daemon_name)
      unless $can_body;
    my $whenhidden = ::NewPrefCheckButton(OPT . 'onlywhenhidden',
        "Don't notify if the main window is visible");
    $vbox->pack_start($_, ::FALSE, ::FALSE, 2)
      for $summary, $body, $size, $timeout, $custom_actions, $default_action, $whenhidden;
    return $vbox;
}

sub Changed {
    return if $::Options{OPT . 'onlywhenhidden'} && ::IsWindowVisible($::MainWindow);

    my $ID      = $::SongID;
    my $title   = $::Options{OPT . 'title'  };
    my $text    = $::Options{OPT . 'text'   };
    my $size    = $::Options{OPT . 'picsize'};
    my $timeout = $::Options{OPT . 'timeout'} * 1000;

    return unless $title || $text || $size;

    $title = ::ReplaceFields($ID, $title) || " "; # libnotify do not like null summaries
    $notify->update($title, ::ReplaceFieldsAndEsc($ID, $text));
    my $pixbuf;

    if ($size) {
        my $album_gid = Songs::Get_gid($ID, 'album');
        $pixbuf = AAPicture::pixbuf('album', $album_gid, $size, 1);
    }

    # 1x1 transparent pixbuf to remove previous pixbuf
    $pixbuf ||= Gtk2::Gdk::Pixbuf->new_from_xpm_data('1 1 1 1', 'a c none', 'a');

    $notify->set_icon_from_pixbuf($pixbuf);
    $notify->set_timeout($timeout);
    $notify->show;
    set_actions();
}

sub set_actions {
    return unless $can_actions;

    $notify->clear_actions;

    if ($can_action_icons) {
        $notify->clear_hints;
        $notify->set_hint('action-icons' => 1);
    }

    if ($::Options{OPT . 'custom_actions'}) {
        $notify->add_action('stock_media-prev', "Previous", \&::PrevSong);
        $notify->add_action('stock_media-stop', "Stop",     \&::Stop);
        $notify->add_action('stock_media-next', "Next",     \&::NextSong);
    }
    if ($::Options{OPT . 'default_action'}) {
        $notify->add_action('default', 'Default Action', \&::ShowHide);
    }
}

1;

# vim: sw=4 ts=4 sts=4 et cc=80
# End of file
