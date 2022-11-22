# Copyright (c) Quentin Sculo  <squentin@free.fr>
# Copyright (c) Alexandr Savca <drop@chinarulezzz.fun>
#
# This file is part of jukebox.
#
# jukebox is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=for gmbplugin Export
name	Export
title	Export plugin
desc	Adds menu entries to song contextual menu
=cut

package GMB::Plugin::Export;

use strict;
use warnings;

use constant {OPT => 'PLUGIN_Export_',};

my $ON;
my %menuentry = (
    topath => {
        label => "Copy to portable player",    #label of the menu entry
        code  => \&Copy,                       #when menu entry selected
        test => \&checkvalidpath,  #the menu entry is displayed if returns true
        notempty => 'IDs',         #display only if at least one song
    },
    tom3u => {
        label    => "Export to .m3u file",
        code     => \&ToM3U,
        notempty => 'IDs',
    },
    toCSV => {
        label    => "Export song properties to a .csv file",
        code     => \&ToCSV,
        notempty => 'IDs',
    },
    tocmd => {
        label => sub {
            ($::Options{OPT . 'tocmd_label'} || "Unnamed custom command")
        },
        code => \&RunCommand,
        test => sub {
            my $c = $::Options{OPT . 'tocmd_cmd'};
            defined $c && $c ne '';
        },
        notempty => 'IDs',
    }
);

my %FLmenuentry = (
    topath => {
        label     => "Copy to portable player",
        code      => \&Copy,
        test      => \&checkvalidpath,
        isdefined => 'filter',
    },
    tom3u => {
        label     => "Export to .m3u file",
        code      => \&ToM3U,
        isdefined => 'filter',
    },
);

my %exportbutton = (
    class    => 'Layout::Button',
    stock    => 'gtk-save',
    tip      => "Export to .m3u file",
    activate => sub {
        my $array = ::GetSongArray($_[0]);
        ToM3U({IDs => $array}) if $array;
    },

    #autoadd_type	=> 'button songs',
);

sub Start {
    $ON = 1;
    updatemenu();
    Layout::RegisterWidget(PluginM3UExport => \%exportbutton);
}

sub Stop {
    $ON = 0;
    updatemenu();
    Layout::RegisterWidget(PluginM3UExport => undef);
}

sub prefbox {
    my $vbox = Gtk2::VBox->new(::FALSE, 2);
    my $sg1  = Gtk2::SizeGroup->new('horizontal');
    my $sg2  = Gtk2::SizeGroup->new('horizontal');

    my $entry1 = ::NewPrefFileEntry(
        OPT . 'path', "Player mounted on :",
        folder => 1,
        sizeg1 => $sg1,
        sizeg2 => $sg2
    );
    my $entry2 = ::NewPrefEntry(
        OPT . 'folderformat', "Folder format :",
        sizeg1 => $sg1,
        sizeg2 => $sg2,
        tip => "These fields can be used :\n" . ::MakeReplaceText('talydnAY')
    );
    my $entry3 = ::NewPrefEntry(
        OPT . 'filenameformat', "Filename format :",
        sizeg1 => $sg1,
        sizeg2 => $sg2,
        tip => "These fields can be used :\n" . ::MakeReplaceText('talydnAYo')
    );
    my $check1 = ::NewPrefCheckButton(
        OPT . 'topath', "Copy to mounted portable player",
        cb     => \&updatemenu,
        widget => ::Vpack($entry1, $entry2, $entry3)
    );

    my $entry4 = ::NewPrefEntry(
        OPT . 'tocmd_label', "Menu entry name",
        sizeg1 => $sg1,
        sizeg2 => $sg2,
        tip    => "Name under which the command will appear in the menu"
    );
    my $entry5 = ::NewPrefEntry(
        OPT . 'tocmd_cmd',
        "System command :",
        sizeg1 => $sg1,
        sizeg2 => $sg2,
        tip    => "These fields can be used :\n"
          . ::MakeReplaceText('ftalydnAY') . "\n"
          . "In this case one command by file will be run\n\n"
          . 'Or you can use the field $files which will be replaced by the list of files, and only one command will be run'

    );
    my $check2 = ::NewPrefCheckButton(
        OPT . 'tocmd', "Execute custom command on selected files",
        cb     => \&updatemenu,
        widget => ::Vpack($entry4, $entry5)
    );

    my $check3 = ::NewPrefCheckButton(
        OPT . 'tom3u',
        "Export to .m3u file",
        cb => \&updatemenu
    );
    my $check4 = ::NewPrefCheckButton(
        OPT . 'toCSV',
        "Export song properties to a .csv file",
        cb => \&updatemenu
    );
    $vbox->pack_start($_, ::FALSE, ::FALSE, 2)
      for $check1, $check2, $check3, $check4;
    return $vbox;
}

sub updatemenu {
    my $removeall = !$ON;
    for my $eid (keys %menuentry) {
        my $menu  = \@::SongCMenu;
        my $entry = $menuentry{$eid};
        if (!$removeall && $::Options{OPT . $eid}) {
            push @$menu, $entry unless (grep $_ == $entry, @$menu);
        }
        else {
            @$menu = grep $_ != $entry, @$menu;
        }
    }
    for my $eid (keys %FLmenuentry) {
        my $menu  = \@FilterList::FLcMenu;
        my $entry = $FLmenuentry{$eid};
        if (!$removeall && $::Options{OPT . $eid}) {
            push @$menu, $entry unless (grep $_ == $entry, @$menu);
        }
        else {
            @$menu = grep $_ != $entry, @$menu;
        }
    }
}

sub checkvalidpath {
    my $p = ::decode_url($::Options{OPT . 'path'});
    $p && (-d $p || $p =~ m/[%\$]/);
}

sub Copy {
    my $IDs  = $_[0]{IDs} || $_[0]{filter}->filter;
    my $path = ::decode_url($::Options{OPT . 'path'});
    ::CopyMoveFiles(
        $IDs,
        copy           => 1,
        basedir        => $path,
        dirformat      => $::Options{OPT . 'folderformat'},
        filenameformat => $::Options{OPT . 'filenameformat'},
    );
}

sub ToM3U {
    my $IDs = $_[0]{IDs} || $_[0]{filter}->filter;
    return unless @$IDs;
    my $file = ::ChooseSaveFile(
        undef,
        "Write filenames to ...",
        Songs::Get($IDs->[0], 'path'), 'list.m3u'
    );
    return unless defined $file;
    my $content = "#EXTM3U\n";
    for my $ID (@$IDs) {
        my ($file, $length, $artist, $title) =
          Songs::Get($ID, qw/fullfilename length artist title/);
        ::_utf8_on($file);    # for file, so it doesn't get converted in utf8
        $content .= "\n#EXTINF:$length,$artist - $title\n$file\n";
    }
    {
        my $fh;
        open($fh, '>:utf8', $file)
          && (print $fh $content)
          && close($fh)
          && last;
        my $res = ::Retry_Dialog(
            $!,
            "Error writing .m3u file",
            details => ::__x("file: {filename}", filename => $file)
        );
        redo if $res eq 'retry';
    }
}

sub ToCSV {
    my $IDs = $_[0]{IDs} || $_[0]{filter}->filter;
    my $check =
      ::NewPrefCheckButton(OPT . 'toCSV_notitlerow', "Do not add a title row");
    my $file = ::ChooseSaveFile(undef, "Write filenames to ...",
        undef, 'songs.csv', $check);
    return unless defined $file;
    my @fields =
      (qw/file path/, sort grep !m/^file$|^path$/, (Songs::PropertyFields()))
      ;    #make sure file and path are in position 0 and 1

    my $retry;
    {
        if ($retry) {
            my $res = ::Retry_Dialog(
                $!,
                "Error writing .csv file",
                details => ::__x("file: {filename}", filename => $file)
            );
            last unless $res eq 'retry';
        }
        $retry = 1;

        open my $fh, '>:utf8', $file or redo;
        unless ($::Options{OPT . 'toCSV_notitlerow'})    #print a title row
        {
            print $fh join(',', map Songs::FieldName($_), @fields) . "\n"
              or redo;
        }
        for my $ID (@$IDs) {
            my @val;
            push @val, Songs::Get($ID, @fields);
            s/\x00/\t/g for @val;                        #for genres and labels
            s/"/""/g for @val;
            ::_utf8_on($val[0])
              ;    # for file and path, so it doesn't get converted in utf8
            ::_utf8_on($val[1]);    # FIXME find a cleaner way to do that

            #print STDERR join(',',@val)."\n";
            print $fh join(',', map '"' . $_ . '"', @val) . "\n" or redo;
        }
        close $fh or redo;
    }
}

sub RunCommand {
    my $IDs = $_[0]{IDs} || $_[0]{filter}->filter;
    my $cmd = $::Options{OPT . 'tocmd_cmd'};
    ::run_system_cmd($cmd, $IDs, 0);
}

1;

# vim:sw=4:ts=4:sts=4:et:cc=80
# End of file
