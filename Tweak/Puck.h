#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>
#import <spawn.h>

HBPreferences* preferences;

BOOL isPuckActive = NO;
BOOL recentlyWoke = NO;
NSTimer* timer = nil;
int volumeUpPresses = 0;

extern BOOL enabled;

// behavior
NSInteger shutdownPercentageValue = 7;
NSInteger wakePercentageValue = 10;
BOOL wakeWithVolumeButtonSwitch = YES;
BOOL wakeWhenPluggedInSwitch = NO;
BOOL respringOnWakeSwitch = YES;

// miscellaneous
BOOL allowMusicPlaybackSwitch = NO;

// device locking
@interface SpringBoard : UIApplication
- (void)_simulateLockButtonPress;
- (void)_simulateHomeButtonPress;
- (void)receivePuckNotification:(NSNotification *)notification;
@end

// airplane mode
@interface SBAirplaneModeController : NSObject
+ (id)sharedInstance;
- (void)setInAirplaneMode:(BOOL)arg1;
@end

// low power mode
@interface _CDBatterySaver : NSObject
+ (id)sharedInstance;
- (BOOL)setPowerMode:(long long)arg1 error:(id *)arg2;
@end

// battery percentage
@interface SBUIController : NSObject
- (int)batteryCapacityAsPercentage;
- (BOOL)isOnAC;
@end