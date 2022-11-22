# Copyright (c) Quentin Sculo  <squentin@free.fr>
# Copyright (c) Alexandr Savca <drop@chinarulezzz.fun>
#
# This file is part of jukebox.
#
# jukebox is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=for gmbplugin TitleBar
name	Titlebar
title	Titlebar overlay plugin
desc	Display a special layout in or around the titlebar of the focused window
req	perl(Gnome2::Wnck, libgnome2-wnck-perl perl-Gnome2-Wnck)
=cut

package GMB::Plugin::TitleBar;

use strict;
use warnings;

use Gnome2::Wnck;

use constant {OPT => 'PLUGIN_TITLEBAR_',};

::SetDefaultOptions(OPT,
    offy         => 4,
    offx         => 24,
    refpoint     => 'upper_left',
    layout       => 'O_play',
    textcolor    => 'white',
    textfont     => 'Sans 7',
    set_textfont => 1
);

my ($Screen, $Handle, $Popupwin, $ActiveWindow);

my %refpoints = (
    upper_left  => "Upper left",
    upper_right => "Upper right",
    lower_left  => "Lower left",
    lower_right => "Lower right",
);

sub Start {
    $Screen = Gnome2::Wnck::Screen->get_default;
    $Handle =
      $Screen->signal_connect(active_window_changed => \&window_changed);
    init();
}

sub Stop {
    $Popupwin->close_window if $Popupwin;
    $Screen->signal_handler_disconnect($Handle);
    $ActiveWindow->signal_handler_disconnect($ActiveWindow->{handle})
      if $ActiveWindow && $ActiveWindow->{handle};
    $ActiveWindow = $Popupwin = $Screen = $Handle = undef;
}

sub prefbox {
    my $vbox   = Gtk2::VBox->new(::FALSE, 2);
    my $sg1    = Gtk2::SizeGroup->new('horizontal');
    my $sg2    = Gtk2::SizeGroup->new('horizontal');
    my $layout = ::NewPrefLayoutCombo(
        OPT . 'layout' => 'O',
        "Overlay layout :", $sg1, $sg2, \&init
    );
    my $refpoint = ::NewPrefCombo(
        OPT . 'refpoint' => \%refpoints,
        cb               => \&move,
        text             => "Reference point :",
        sizeg1           => $sg1,
        sizeg2           => $sg2
    );
    my $offx = ::NewPrefSpinButton(
        OPT . 'offx', -999, 999,
        cb     => \&move,
        step   => 1,
        page   => 5,
        text   => "x offset :",
        sizeg1 => $sg1
    );
    my $offy = ::NewPrefSpinButton(
        OPT . 'offy', -999, 999,
        cb     => \&move,
        step   => 1,
        page   => 5,
        text   => "y offset :",
        sizeg1 => $sg1
    );
    my $notdialog = ::NewPrefCheckButton(
        OPT . 'notdialog',
        "Don't add the overlay to dialogs",
        cb => \&init
    );

    my $textcolor = Gtk2::ColorButton->new_with_color(
        Gtk2::Gdk::Color->parse($::Options{OPT . 'textcolor'}));
    $textcolor->signal_connect(
        color_set => sub {
            $::Options{OPT . 'textcolor'} = $_[0]->get_color->to_string;
            init();
        }
    );
    my $set_textcolor = ::NewPrefCheckButton(
        OPT . 'set_textcolor', "Change default text color",
        cb         => \&init,
        widget     => $textcolor,
        horizontal => 1
    );

    my $font = Gtk2::FontButton->new_with_font($::Options{OPT . 'textfont'});
    $font->signal_connect(font_set =>
          sub { $::Options{OPT . 'textfont'} = $_[0]->get_font_name; init(); }
    );
    my $set_font = ::NewPrefCheckButton(
        OPT . 'set_textfont', "Change default text font and size",
        cb         => \&init,
        widget     => $font,
        horizontal => 1
    );

    $vbox->pack_start($_, ::FALSE, ::FALSE, 2)
      for $layout, $refpoint, $offx, $offy, $set_textcolor, $set_font,
      $notdialog;
    return $vbox;
}

sub init {
    my @moreoptions;
    push @moreoptions, DefaultFontColor => $::Options{OPT . 'textcolor'}
      if $::Options{OPT . 'set_textcolor'};
    push @moreoptions, DefaultFont => $::Options{OPT . 'textfont'}
      if $::Options{OPT . 'set_textfont'};
    $Popupwin = Layout::Window->new(
        $::Options{OPT . 'layout'},
        fallback    => 'O_play',
        title       => "jukebox_titlebar_overlay",
        uniqueid    => 'titlebar',
        ifexist     => 'replace',
        wintype     => 'popup',
        transparent => 1,
        ontop       => 1,
        sticky      => 1,
        typehint    => 'dock',
        @moreoptions,
    );
    window_changed($Screen);
}

sub move {
    return unless $Popupwin && $ActiveWindow;
    my ($x,    $y,    $w,  $h)  = $ActiveWindow->get_geometry;
    my (undef, undef, $pw, $ph) = $Popupwin->window->get_geometry;
    my $ref  = $::Options{OPT . 'refpoint'};
    my $offx = $::Options{OPT . 'offx'};
    my $offy = $::Options{OPT . 'offy'};
    if ($ref =~ m/right/) { $x += $w - $pw; $offx *= -1; }
    if ($ref =~ m/lower/) { $y += $h - $ph; $offy *= -1; }
    $x += $offx;
    $y += $offy;
    $Popupwin->move($x, $y);

    if (1)    #hide it if there is a window above
    {
        for my $win (
            reverse $Screen->get_windows_stacked
          )    #go through windows from top to bottom
        {
            last if $ActiveWindow == $win;    #until the active window
            next
              unless $win->is_visible_on_workspace(
                $ActiveWindow->get_workspace);
            my ($x0, $y0, $w0, $h0) = $win->get_geometry;
            if (   $x + $pw > $x0
                && $x0 + $w0 > $x
                && $y + $ph > $y0
                && $y0 + $h0 > $y)
            {
                $Popupwin->hide;
                return;
            }
        }
    }
    $Popupwin->show;
    $Popupwin->move($x, $y)
      ;    #repeat because it probably didn't move if it was hidden
}

sub window_changed {
    my $screen = shift;
    my $active = $screen->get_active_window;
    return
         if !$active
      && $ActiveWindow
      && $ActiveWindow->is_visible_on_workspace($screen->get_active_workspace);
    if ($ActiveWindow && $ActiveWindow->{handle}) {
        $ActiveWindow->signal_handler_disconnect($ActiveWindow->{handle});
    }
    $ActiveWindow = $active;
    if ($ActiveWindow) {
        my $type = $ActiveWindow->get_window_type;
        $ActiveWindow = undef
          unless $type eq 'normal'
          || ($type eq 'dialog' && !$::Options{OPT . 'notdialog'});
    }
    if ($ActiveWindow && !$ActiveWindow->is_fullscreen) {
        $ActiveWindow->{handle} =
          $ActiveWindow->signal_connect(geometry_changed => \&move);
        move();
    }
    else {
        $Popupwin->hide;
    }
}

1;

# vim:sw=4:ts=4:sts=4:et:cc=80
# End of file
