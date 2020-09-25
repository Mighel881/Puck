#import "Puck.h"

BOOL enabled;

%group Puck

%hook SBTapToWakeController

- (void)tapToWakeDidRecognize:(id)arg1 { // disable tap to wake

	if (!isPuckActive)
		%orig;
	else
		return;

}

- (void)pencilToWakeDidRecognize:(id)arg1 { // disable apple pencil tap to wake

	if (!isPuckActive)
		%orig;
	else
		return;

}

%end

%hook SBLiftToWakeController

- (void)wakeGestureManager:(id)arg1 didUpdateWakeGesture:(long long)arg2 orientation:(int)arg3 { // disable raise to wake

	if (!isPuckActive)
		%orig;
	else
		return;

}

%end

%hook SBSleepWakeHardwareButtonInteraction

- (void)_performWake { // disable sleep button

	if (!isPuckActive)
		%orig;
	else
		return;

}

- (void)_performSleep { // disable sleep button

	if (!isPuckActive)
		%orig;
	else
		return;

}

%end

%hook SBLockHardwareButtonActions

- (BOOL)disallowsSinglePressForReason:(id*)arg1 { // disable sleep button

	if (!isPuckActive)
		return %orig;
	else
		return YES;

}

- (BOOL)disallowsDoublePressForReason:(id *)arg1 { // disable sleep button

	if (!isPuckActive)
		return %orig;
	else
		return YES;

}

- (BOOL)disallowsTriplePressForReason:(id*)arg1 { // disable sleep button

	if (!isPuckActive)
		return %orig;
	else
		return YES;

}

- (BOOL)disallowsLongPressForReason:(id*)arg1 { // disable sleep button

	if (!isPuckActive)
		return %orig;
	else
		return YES;
	
}

%end

%hook SBHomeHardwareButton

- (void)initialButtonDown:(id)arg1 { // disable home button

	if (!isPuckActive)
		%orig;
	else
		return;

}

- (void)singlePressUp:(id)arg1 { // disable home button

	if (!isPuckActive)
		%orig;
	else
		return;

}

%end

%hook SBHomeHardwareButtonActions

- (void)performLongPressActions { // disable home button

	if (!isPuckActive)
		%orig;
	else
		return;

}

%end

%hook SBRingerControl

- (void)setRingerMuted:(BOOL)arg1 { // disable ringer switch

	if (!isPuckActive)
		%orig;
	else
		%orig(NO);

}

%end

%hook SBBacklightController

- (void)turnOnScreenFullyWithBacklightSource:(long long)arg1 { // prevent display from turning on

	if (!isPuckActive)
		%orig;
	else
		return;

}

%end

%hook SBVolumeControl

- (void)increaseVolume { // wake after three volume up steps when active

	if (!isPuckActive || (isPuckActive && allowVolumeChangesSwitch)) %orig;

	if (!isPuckActive || !wakeWithVolumeButtonSwitch) return;
	timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(resetPresses) userInfo:nil repeats:NO];

	if (!timer) return;
	volumeUpPresses += 1;
	if (volumeUpPresses == 3)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"puckWakeNotification" object:nil];

}

- (void)decreaseVolume {

	if (!isPuckActive || (isPuckActive && allowVolumeChangesSwitch)) %orig;

}

%new
- (void)resetPresses { // reset presses after timer is up

	volumeUpPresses = 0;
	[timer invalidate];
	timer = nil;

}

%end

%hook SBUIController

- (void)updateBatteryState:(id)arg1 { // automatic shutdown and wake

	%orig;

	if ([self batteryCapacityAsPercentage] != shutdownPercentageValue)
		recentlyWoke = NO;

	if ([self batteryCapacityAsPercentage] == shutdownPercentageValue && ![self isOnAC] && !isPuckActive && !recentlyWoke)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"puckShutdownNotification" object:nil];

	if ([self batteryCapacityAsPercentage] == wakePercentageValue && [self isOnAC] && isPuckActive)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"puckWakeNotification" object:nil];

}

- (void)ACPowerChanged { // wake after plugged in

	%orig;

	if (wakeWhenPluggedInSwitch && [self isOnAC] && isPuckActive)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"puckWakeNotification" object:nil];

}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)arg1 { // register puck notifications

	%orig;

	recentlyWoke = YES;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivePuckNotification:) name:@"puckShutdownNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivePuckNotification:) name:@"puckWakeNotification" object:nil];

}

%new
- (void)receivePuckNotification:(NSNotification *)notification {

	if ([notification.name isEqual:@"puckShutdownNotification"]) { // shutdown
		SpringBoard* springboard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
		[springboard _simulateLockButtonPress]; // lock device
		[[%c(SBAirplaneModeController) sharedInstance] setInAirplaneMode:YES]; // enable airplane mode
		[[%c(_CDBatterySaver) sharedInstance] setPowerMode:1 error:nil]; // enable low power mode
		isPuckActive = YES;

		if (!allowMusicPlaybackSwitch) { // stop music
			pid_t pid;
			const char* args[] = {"killall", "mediaserverd", NULL};
			posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const *)args, NULL);
		}
	} else if ([notification.name isEqual:@"puckWakeNotification"]) { // wake
		[[%c(SBAirplaneModeController) sharedInstance] setInAirplaneMode:NO]; // disable airplane mode
		[[%c(_CDBatterySaver) sharedInstance] setPowerMode:0 error:nil]; // disable low power mode
		isPuckActive = NO;
		
		if (!respringOnWakeSwitch) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				SpringBoard* springboard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
				[springboard _simulateHomeButtonPress];
			});
		} else {
			pid_t pid;
			const char* args[] = {"killall", "backboardd", NULL};
			posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const *)args, NULL);
		}
	}

}

%end

%end

%ctor {

	preferences = [[HBPreferences alloc] initWithIdentifier:@"love.litten.puckpreferences"];

	[preferences registerBool:&enabled default:NO forKey:@"Enabled"];

	// Behavior
	[preferences registerInteger:&shutdownPercentageValue default:7 forKey:@"shutdownPercentage"];
	[preferences registerInteger:&wakePercentageValue default:10 forKey:@"wakePercentage"];
	[preferences registerBool:&wakeWithVolumeButtonSwitch default:YES forKey:@"wakeWithVolumeButton"];
	[preferences registerBool:&wakeWhenPluggedInSwitch default:NO forKey:@"wakeWhenPluggedIn"];
	[preferences registerBool:&respringOnWakeSwitch default:NO forKey:@"respringOnWake"];

	// Music
	[preferences registerBool:&allowMusicPlaybackSwitch default:YES forKey:@"allowMusicPlayback"];
	[preferences registerBool:&allowVolumeChangesSwitch default:YES forKey:@"allowVolumeChanges"];

	if (enabled) {
		%init(Puck);
	}
	
}