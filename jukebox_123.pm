# Copyright (c) Quentin Sculo  <squentin@free.fr>
# Copyright (c) Alexandr Savca <drop@chinarulezzz.fun>
#
# This file is part of jukebox.
#
# jukebox is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

package Play_123;

use strict;
use warnings;

use IO::Handle;
use POSIX ':sys_wait_h';    #for WNOHANG in waitpid

#use IPC::Open3;		#for open3 to read STDERR from ogg123 / mpg321 in Play function

#$SIG{CHLD} = 'IGNORE';  # to make sure there are no zombies #cause crash after displaying a file dialog and then runnning an external command with mandriva's gtk2
#$SIG{CHLD} = sub { while (waitpid(-1, WNOHANG)>0) {} };

my (@cmd_and_args, $file, $ChildPID, $WatchTag, $WatchTag2, $OUTPUTfh,
    @pidToKill);
my ($Paused, $SkipTo);
my ($CMDfh,  $RemoteMode);
my $alsa09;
my $Error;
our %Commands = (
    mpg321 => {
        type    => 'mp3',
        devices => 'oss alsa esd arts sun',
        cmdline => \&mpg321_cmdline,
    },
    ogg123 => {
        type    => 'oga flac',
        devices => 'pulse alsa arts esd oss',
        cmdline => \&ogg123_cmdline,
    },    #FIXME could check if flac codec is available
    mpg123 => {
        type    => 'mp3',
        devices => sub {
            return grep $_ ne 'dummy', map m/^(\w+)\s+output*/g,
              qx/mpg123 --list-modules/;
        },
        remote => {
            PAUSE   => 'P',
            RESUME  => 'P',
            QUIT    => 'Q',
            LOAD    => sub {"L $_[0]"},
            JUMP    => sub {"J $_[0]s"},
            watcher => \&_remotemsg,
        },
        cmdline  => \&mpg123_cmdline,
        priority => 1,                  #makes it higher priority than mpg321
    },
    flac123 => {
        type    => 'flac',
        devices => 'oss esd arts ',
        remote  => {
            PAUSE   => 'P',
            RESUME  => 'P',
            QUIT    => 'Q',
            LOAD    => sub {"L $_[0]"},
            JUMP    => sub {"J $_[0]"},
            watcher => \&_remotemsg,
        },
        cmdline  => \&flac123_cmdline,
        priority => 1
        , #makes it higher priority than ogg123 (because ogg123 can't seek in flac files)
    },
);
our %Supported;

$::PlayPacks{Play_123} = 1;    #register the package

sub init {
    my @notfound;
    my $foundone;
    for my $cmd (
        sort {
            ($Commands{$b}{priority} || 0) <=> ($Commands{$a}{priority} || 0)
        } keys %Commands
      )
    {
        my ($found) = grep -x, map $_ . ::SLASH . $cmd, split /:/, $ENV{PATH};
        while ($found && -l $found) {
            my $real = readlink $found;
            $real = '' if $real eq $found;    #avoid endless loop
            $real =~ m#([^/]+)$#;
            if ($cmd ne $1 && $Commands{$1}) {
                $found = undef;
            } #ignore symbolic links to other known commands (like a mpg123 that is really a symlinked mpg321)
            else { $found = $real }
        }
        for my $ext (split / /, $Commands{$cmd}{type}) {
            push @{$Supported{$ext}}, $cmd if $found;
        }
        $Commands{$cmd}{found} = 1 if $found;
        if   ($found) { $foundone++ }
        else          { push @notfound, $cmd; }
    }
    for my $ext (keys %Supported) {
        my $cmds     = $Supported{$ext};
        my $priority = $::Options{'123priority_' . $ext};
        if ($priority && (grep $priority eq $_, @$cmds)) {
            $Supported{$ext} = $priority;
        }
        else { $Supported{$ext} = $cmds->[0]; }
    }
    $Supported{$_} = $Supported{$::Alias_ext{$_}}
      for grep $Supported{$::Alias_ext{$_}}, keys %::Alias_ext;
    my @missing = grep !$Supported{$_}, qw/mp3 oga flac/;
    if (@missing) {
        warn "These commands were not found : " . join(', ', @notfound) . "\n";
        warn " => these file types won't be played by the 123 output : "
          . join(', ', @missing)
          . "\n";    #FIXME include aliases
    }

    return unless $foundone;
    return bless {}, __PACKAGE__;
}

sub VolInit {
    return Play_amixer::init();    #use amixer for volume
}

sub supported_formats {
    return grep $Supported{$_}, keys %Supported;
}

sub mp3_sec_to_frame               #mpg321 needs a frame number
{
    my $sec = $_[0];
    my ($filetype, $samprate) =
      Songs::Get($::PlayingID, 'filetype', 'samprate');
    my $samperframe = 1152;
    $samperframe = $1 == 1 ? 384 : $2 == 2 ? 576 : 1152
      if $filetype =~ m/mp3 l(\d)v(\d)/;
    my $framepersec = ($samprate || 44100) / $samperframe;
    return sprintf '%.0f', $sec * $framepersec;
}

sub mpg321_cmdline {
    my ($file, $sec, $out, @opt) = @_;
    unshift @opt, '-o', $out if $out;
    push @opt, '-k', mp3_sec_to_frame($sec) if $sec;
    return 'mpg321', @opt, '-vq', '--skip-printing-frames=3', '--', $file;
}

sub ogg123_cmdline {
    my ($file, $sec, $out, @opt) = @_;
    if ($out) {
        $out =~ s/^alsa/alsa09/
          if (defined $alsa09 ? $alsa09 : $alsa09 = qx(ogg123) =~ m/alsa09/)
          ;    #check if ogg123 calls alsa "alsa09" or "alsa"
        unshift @opt, '-d', $out;
    }
    push @opt, '-k', $sec if $sec;
    return 'ogg123', @opt, '--', $file;
}

sub flac123_cmdline {
    my ($file, $sec, $out, @opt) = @_;
    unshift @opt, '-d', $out if $out;
    return 'flac123', @opt, '-R';
}

sub mpg123_cmdline {
    my ($file, $sec, $out, @opt) = @_;
    unshift @opt, '-o', $out if $out;
    return 'mpg123', @opt, '-R';
}

sub Play {
    (undef, $file, my $sec) = @_;
    &Stop if $ChildPID;
    $Error        = $SkipTo = undef;
    @cmd_and_args = ();
    my $device_option;
    my $device = $::Options{Device};
    my ($type) = $file =~ m/\.([^.]*)$/;
    $type = lc $type;
    my $cmd = $Supported{$type};

    if ($cmd) {
        my @extra = split / /, $::Options{'123options_' . $cmd} || '';
        my $out   = $::Options{'123device_' . $cmd};
        $out          = undef if $out && $out eq 'default';
        @cmd_and_args = $Commands{$cmd}{cmdline}($file, $sec, $out, @extra);
    }
    else {
        $type = $::Alias_ext{$type} if $::Alias_ext{$type};
        my $re    = qr/\b$type\b/;
        my @hints = grep $Commands{$_}{type} =~ m/$re/, sort keys %Commands;
        my $msg   = "Can't play this file.\n";
        $msg .=
          @hints > 1
          ? "One of these commands is required to play files of type {type} : {cmd}"
          : @hints
          ? "This command is required to play files of type {type} : {cmd}"
          : "Don't know how to play files of type {type}";
        ::ErrorPlay(::__x($msg, type => $type, cmd => join(', ', @hints)));
        return undef;
    }
    $RemoteMode = $Commands{$cmd}{remote};

    #################################################
    #$ChildPID=open3(my $fh, $OUTPUTfh, $OUTPUTfh, @cmd_and_args, $file);
    pipe $OUTPUTfh, my $wfh;
    pipe my ($rfh), $CMDfh;
    $ChildPID = fork;
    if (!defined $ChildPID) {
        warn "jukebox_123 : fork failed : $!\n";
        ::ErrorPlay("Fork failed : $!");
        return;
    }
    elsif ($ChildPID == 0)    #child
    {
        close $OUTPUTfh;
        close $CMDfh;
        open my ($olderr), ">&", \*STDERR;
        open \*STDIN,  '<&=' . fileno $rfh;
        open \*STDOUT, '>&=' . fileno $wfh;
        open \*STDERR, '>&=' . fileno $wfh;
        exec @cmd_and_args
          or print $olderr "launch failed (@cmd_and_args) : $!\n";
        POSIX::_exit(1);
    }
    close $wfh;
    close $rfh;
    if ($RemoteMode) {
        $CMDfh->autoflush(1);
        print $CMDfh $RemoteMode->{LOAD}($file) . "\n";
        SkipTo(undef, $sec) if $sec;
    }
    $OUTPUTfh->blocking(0);    #set non-blocking IO
    warn "playing $file (pid=$ChildPID)\n" if $::Verbose;
    $WatchTag = Glib::IO->add_watch(fileno($OUTPUTfh), 'hup', \&_eos_cb);
    $WatchTag2 =
      $RemoteMode
      ? Glib::IO->add_watch(fileno($OUTPUTfh), 'in', $RemoteMode->{watcher})
      : Glib::Timeout->add(500, \&_UpdateTime);
}

sub _eos_cb {
    _UpdateTime();             #parse last lines

    #close $OUTPUTfh;
    if ($ChildPID && $ChildPID == waitpid($ChildPID, WNOHANG)) {
        $Error ||= "Check your audio settings" if $?;
    }
    while (waitpid(-1, WNOHANG) > 0) { }    #reap dead children
    Glib::Source->remove($WatchTag);
    Glib::Source->remove($WatchTag2);
    $WatchTag = $WatchTag2 = $ChildPID = undef;
    if ($Error) {
        ::ErrorPlay($Error, "Command used :\n@cmd_and_args");
    }
    ::end_of_file();
    return 1;
}

sub _remotemsg                              #used by flac123 and mpg123
{
    my $buf;
    my @line = (<$OUTPUTfh>);
    my $line = pop @line;                   #only read the last line
    chomp $line;
    if ($line =~ m/^\@P 0$/) {
        print $CMDfh $RemoteMode->{QUIT} . "\n";
    }                                       #finished or stopped
    elsif ($line =~ m/^\@F \d+ \d+ (\d+)\.\d\d \d+\.\d\d$/) {
        ::UpdateTime($1);
    }
    elsif ($line =~ m/^\@E(.*)$/) {
        $Error = $1;
        print $CMDfh $RemoteMode->{QUIT} . "\n";
    }                                       #Error

    #else {warn $line."\n"}
    return 1;
}

sub Pause {
    $Paused = 1;
    if    ($RemoteMode) { print $CMDfh $RemoteMode->{PAUSE} . "\n" }
    elsif ($ChildPID)   { kill STOP => $ChildPID }
}

sub Resume {
    $Paused = 0;
    if ($ChildPID) {
        if   ($RemoteMode) { print $CMDfh $RemoteMode->{RESUME} . "\n" }
        else               { kill CONT => $ChildPID; }
    }
    else { SkipTo(undef, $SkipTo); $SkipTo = undef; }
}

sub SkipTo {
    my $sec = $_[1];
    if ($Paused) { Stop(); $Paused = 1; $SkipTo = $sec; }
    elsif ($RemoteMode && $ChildPID) {
        ::setlocale(::LC_NUMERIC, 'C');    #flac123 ignores decimals anyway
        print $CMDfh $RemoteMode->{JUMP}($sec) . "\n";
        ::setlocale(::LC_NUMERIC, '');
    }
    else { Play(undef, $file, $sec); }
}


sub Stop {
    $Paused = 0;
    if ($WatchTag) {
        Glib::Source->remove($WatchTag);
        Glib::Source->remove($WatchTag2);
        $WatchTag = $WatchTag2 = undef;
    }
    if ($ChildPID) {
        print $CMDfh $RemoteMode->{QUIT} . "\n" if $RemoteMode;
        warn "killing $ChildPID\n"              if $::debug;

        #close $OUTPUTfh;
        #kill TERM,$ChildPID;
        kill INT => $ChildPID;
        Glib::Timeout->add(200, \&_Kill_timeout) unless @pidToKill;
        push @pidToKill, $ChildPID;
        undef $ChildPID;
    }
}

sub _Kill_timeout    #make sure old children are dead
{
    @pidToKill = grep kill(0, $_), @pidToKill;
    if (@pidToKill) {
        warn "killing -9 @pidToKill\n" if $::debug;
        kill KILL => @pidToKill;
        undef @pidToKill;
    }
    while (waitpid(-1, WNOHANG) > 0) { }    #reap dead children
    return 0;
}

sub _UpdateTime                             #used by ogg123 and mpg321
{
    my @lines = (<$OUTPUTfh>);
    for (reverse @lines) {
        if (m#\D: +(\d\d):(\d\d)\.(\d\d)#) {
            ::UpdateTime($1 * 60 + $2 + ($3 >= 50 ? 1 : 0));
            return 1;
        }

        # check if known error message
        $Error = $1
          if m#(Can't find a suitable libao driver)#
          || m#(No such device \w+)#
          || m#(Failed to initialize output)#
          || m#(Cannot open .+)#
          || m#(.+: No such file or directory)#;
    }
    warn join("123:$_", '', @lines) if $::debug;
    return 1;
}

sub AdvancedOptions {
    my $vbox  = Gtk2::VBox->new;
    my $table = Gtk2::Table->new(1, 1, ::FALSE);
    my %ext;
    my %extgroup;
    $ext{$_} = undef for map split(/ /, $Commands{$_}{type}), keys %Commands;
    my @ext = sort keys %ext;
    for my $e (@ext) {
        $ext{$e} = join '/', $e, sort grep $::Alias_ext{$_} eq $e,
          keys %::Alias_ext;
    }
    my $i = my $j = 0;
    $table->attach_defaults(Gtk2::Label->new($_), $i++, $i, $j, $j + 1)
      for ("Command", "Output", "Options", map " $ext{$_} ", @ext);
    my $hsize = Gtk2::SizeGroup->new('vertical');
    $hsize->add_widget($_) for $table->get_children;
    for my $cmd (sort keys %Commands) {
        $i = 0;
        $j++;
        my $devs = $Commands{$cmd}{devices};
        my @widgets;
        $devs = ''
          if ref $devs
          && !$Commands{$cmd}{found}
          ; #don't try to find dynamic list of devices if command not found, as the function likely requires the command
        my @devlist = ref $devs ? $devs->() : split / /, $devs;
        push @widgets,
          Gtk2::Label->new($cmd),
          ::NewPrefCombo('123device_' . $cmd => ['default', @devlist]),
          ::NewPrefEntry('123options_' . $cmd);
        $hsize->add_widget($_) for @widgets;
        my %cando;
        $cando{$_} = undef for split / /, $Commands{$cmd}{type};
        $table->attach_defaults($_, $i++, $i, $j, $j + 1) for @widgets;

        for my $ext (@ext) {
            if (exists $cando{$ext}) {
                my $w = Gtk2::RadioButton->new($extgroup{$ext});
                $w->set_tooltip_text(
                    ::__x(
                        "Use {command} to play {ext} files",
                        command => $cmd,
                        ext     => $ext{$ext}
                    )
                );
                $extgroup{$ext} ||= $w;
                $table->attach($w, $i, $i + 1, $j, $j + 1, 'expand', 'expand',
                    0, 0);
                push @widgets, $w;
                $w->set_active(1) if $cmd eq ($Supported{$ext} || '');
                $w->signal_connect(
                    toggled => sub {
                        return unless $_[0]->get_active;
                        $Supported{$ext} = $::Options{'123priority_' . $ext} =
                          $cmd;
                        $Supported{$_} = $Supported{$ext}
                          for grep $::Alias_ext{$_} eq $ext,
                          keys %::Alias_ext;
                    }
                );
            }
            $i++;
        }
        unless ($Commands{$cmd}{found}) { $_->set_sensitive(0) for @widgets; }
    }
    $vbox->pack_start($table, ::FALSE, ::FALSE, 2);
    my $hbox = Play_amixer->make_option_widget;

    $vbox->pack_start($hbox, ::FALSE, ::FALSE, 2);
    return $vbox;
}

package Play_amixer;
my ($mixer, $Mute, $Volume);

sub init {
    $Mute ||= 0;
    for my $path (split /:/, $ENV{PATH}) {
        if (-x $path . ::SLASH . 'amixer') {
            $mixer = $path . ::SLASH . 'amixer';
            last;
        }
    }

#	if ($mixer)
#	{	SetVolume();
    #Glib::Timeout->add(5000,\&SetVolume);
#	}
    unless ($mixer) {
        warn
          "amixer not found, won't be able to get/set volume through the 123 or mplayer output.\n";
    }
    return bless {}, __PACKAGE__;
}

sub init_volume {
    $Volume = -1;
    return unless $mixer;
    my @list = get_amixer_SMC_list();
    my %h;
    $h{$_} = 1 for @list;
    my $c = \$::Options{amixerSMC};
    if ($$c)     { SetVolume(); return if $Volume >= 0 || $h{$$c}; $$c = ''; }
    if ($h{PCM}) { $$c = 'PCM' }
    elsif ($h{Master}) { $$c = 'Master' }
    else { warn "Don't know what mixer to choose among : @list\n"; }
    SetVolume();
}

sub GetVolume {
    init_volume() unless defined $Volume;
    return $Volume;
}

sub GetVolumeError {
    "Can't change the volume. Needs amixer (packaged in alsa-utils) to change volume when using this audio backend.";
}
sub GetMute {$Mute}

sub SetVolume {
    shift;
    my $inc = $_[0];
    return unless $mixer;
    my $cmd = $mixer;
    if ($inc) {
        if ($inc =~ m/^([+-])?(\d+)$/) { $inc = $2 . '%' . ($1 || ''); }
        $cmd .= " set '$::Options{amixerSMC}' $inc";
    }
    else { $cmd .= " get '$::Options{amixerSMC}'"; }
    warn "volume command : $cmd\n" if $::debug;
    my $oldvol = $Volume;
    my $oldm   = $Mute;
    open VOL, '-|', $cmd;
    while (<VOL>) {
        if (m/ \d+ \[(\d+)%\](?:.*?\[(on|off)\])?/) {
            $Volume = $1;
            $Mute   = ($2 && $2 ne 'on') ? 1 : 0;
            last;
        }
    }
    close VOL;
    return 1 unless ($oldvol != $Volume || $oldm != $Mute);
    ::HasChanged('Vol');
    1;
}

sub make_option_widget {
    my $hbox = ::NewPrefCombo(
        amixerSMC => [get_amixer_SMC_list()],
        text      => "amixer control :",
        cb        => sub { SetVolume() }
    );
    $hbox->set_sensitive(0) unless $mixer;
    return $hbox;
}

sub get_amixer_SMC_list {
    init()        unless $mixer;
    return ()     unless $mixer;
    init_volume() unless defined $Volume;
    my (@list, $SMC);
    open VOL, '-|', $mixer;
    while (<VOL>) {
        if (m/^Simple mixer control '([^']+)'/) {
            $SMC = $1;
        }
        elsif ($SMC && m/ \d+ \[(\d+)%\](?: \[(\w+)\])?/) {
            push @list, $SMC;
            $SMC = undef;
        }
    }
    close VOL;
    return @list;
}

1;

# vim:sw=4:ts=4:sts=4:et:cc=80
# End of file
