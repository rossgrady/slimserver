package Slim::Plugin::DateTime::Plugin;

# SqueezeCenter Copyright 2001-2007 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use base qw(Slim::Plugin::Base);
use Slim::Utils::DateTime;
use Slim::Utils::Prefs;

use Slim::Plugin::DateTime::Settings;

my $prefs = preferences('plugin.datetime');

sub getDisplayName {
	return 'PLUGIN_SCREENSAVER_DATETIME';
}

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin();

	Slim::Plugin::DateTime::Settings->new;

	Slim::Buttons::Common::addSaver(
		'SCREENSAVER.datetime',
		getScreensaverDatetime(),
		\&setScreensaverDateTimeMode,
		\&exitScreensaverDateTimeMode,
		getDisplayName(),
	);
}

our %screensaverDateTimeFunctions = (
	'done' => sub  {
		my ($client ,$funct ,$functarg) = @_;

		Slim::Buttons::Common::popMode($client);
		$client->update();

		# pass along ir code to new mode if requested
		if (defined $functarg && $functarg eq 'passback') {
			Slim::Hardware::IR::resendButton($client);
		}
	},
);

sub getScreensaverDatetime {
	return \%screensaverDateTimeFunctions;
}

sub setScreensaverDateTimeMode() {
	my $client = shift;

	$client->lines(\&screensaverDateTimelines);

	$client->modeParam('modeUpdateInterval', 1);
}

sub exitScreensaverDateTimeMode {
	my $client = shift;

	Slim::Utils::Timers::killTimers($client, \&_flashAlarm);
}

# following is a an optimisation for graphics rendering given the frequency DateTime is displayed
# by always returning the same hash for the font definition render does less work
my $fontDef = {
	'graphic-280x16'  => { 'overlay' => [ 'small.1'    ] },
	'graphic-320x32'  => { 'overlay' => [ 'standard.1' ] },
	'graphic-160x32'  => { 'overlay' => [ 'standard.1' ] },
	'text'            => { 'displayoverlays' => 1        },
};

sub screensaverDateTimelines {
	my $client = shift;
	my $flash  = shift; # set when called from animation callback

	my $currentAlarm = Slim::Utils::Alarm->getCurrentAlarm($client);
	my $nextAlarm = Slim::Utils::Alarm->getNextAlarm($client);

	# show alarm symbol if active or set for next 24 hours
	my $alarmOn = defined $currentAlarm || ( defined $nextAlarm && ($nextAlarm->nextDue - time < 86400) );

	my $twoLines = $client->linesPerScreen == 2;
	my $narrow = $client->display->isa('Slim::Display::Boom');

	my $overlay = undef;

	if ($alarmOn && !$flash) {
		if (defined $currentAlarm && $currentAlarm->snoozeActive) {
			$overlay = $client->symbols('sleep');
		} else {
			$overlay = $client->symbols('bell');
			# Include the next alarm time in the overlay if there's room
			if (! defined $currentAlarm && ($twoLines || ! $narrow)) {
				# Remove seconds from alarm time
				my $timeStr = Slim::Utils::DateTime::timeF($nextAlarm->time % 86400, $prefs->timeformat, 1);
				$timeStr =~ s/(\d?\d\D\d\d)\D\d\d/\1/;
				$overlay .=  "$timeStr";
			}
		}
	}

	my $display = {
		fonts   => $fontDef,
		overlay => [ $overlay ],
	};

	my $timeStr = Slim::Utils::DateTime::timeF(undef, $prefs->get('timeformat'));

	if ($twoLines) {
		$display->{center}->[1] = $timeStr;
		# If we're displaying next alarm time on boom, use short date format and left-align in order to fit it all in
		if ($narrow && $alarmOn && ! defined $currentAlarm) {
			$display->{line}->[0] = Slim::Utils::DateTime::shortDateF(),
		} else {
			$display->{center}->[0] = Slim::Utils::DateTime::longDateF(undef, $prefs->get('dateformat'));
		}
	} else {
		# Use left-align if we're also displaying the bell/snooze symbol
		# Also need to use left-align if the symbol is flashing otherwise the time jumps around as the overlay appears
		# and disappears.
		if ($narrow && $alarmOn) {
			$display->{line}->[1] = $timeStr;
		} else {
			$display->{center}->[1] = $timeStr;
		}
	}

	if ($currentAlarm && !$flash) {
		# schedule another update to remove the alarm symbol during alarm
		Slim::Utils::Timers::setTimer($client, Time::HiRes::time + 0.5, \&_flashAlarm);
	}
	
# BUG 3964: comment out until Dean has a final word on the UI for this.	
# 	if ($client->display->hasScreen2) {
# 		if ($client->display->linesPerScreen == 1) {
# 			$display->{'screen2'}->{'center'} = [undef,Slim::Utils::DateTime::longDateF(undef,$prefs->get('dateformat'))];
# 		} else {
# 			$display->{'screen2'} = {};
# 		}
# 	}

	return $display;
}

sub _flashAlarm {
	my $client = shift;
	
	$client->update( screensaverDateTimelines($client, 'flash') );
}

1;

__END__
