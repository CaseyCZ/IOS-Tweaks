#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <string.h>

#import "CSpeedMath.h"

// This implementation is original to IOS-Tweaks. NtSpeed by julioverne
// inspired the feature, but no source code was copied from that project.

static NSString *const CSpeedPreferencesPath =
    @"/var/mobile/Library/Preferences/cz.caseycz.cspeed.plist";
static CFStringRef const CSpeedPreferencesNotification =
    CFSTR("cz.caseycz.cspeed/preferencesChanged");

static CGFloat CSpeedClamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
    return MIN(MAX(value, minimum), maximum);
}

static BOOL CSpeedIsTrafficInterface(const char *name)
{
    if (!name) return NO;
    // Count Wi-Fi and cellular interfaces. Avoid loopback, AWDL and VPN tunnels
    // that would otherwise cause duplicated totals on some configurations.
    return strncmp(name, "en", 2) == 0 || strncmp(name, "pdp_ip", 6) == 0;
}

static NSDictionary<NSString *, NSValue *> *CSpeedReadNetworkCounters(void)
{
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) return nil;

    NSMutableDictionary<NSString *, NSValue *> *results = [NSMutableDictionary dictionary];
    for (struct ifaddrs *entry = interfaces; entry != NULL; entry = entry->ifa_next) {
        if (!entry->ifa_name || !entry->ifa_addr || !entry->ifa_data) continue;
        if (entry->ifa_addr->sa_family != AF_LINK) continue;
        if (!(entry->ifa_flags & IFF_UP)) continue;
        if (!CSpeedIsTrafficInterface(entry->ifa_name)) continue;

        const struct if_data *data = (const struct if_data *)entry->ifa_data;
        CSpeedCounters counters = {
            .received = (uint64_t)data->ifi_ibytes,
            .sent = (uint64_t)data->ifi_obytes,
        };
        NSString *name = [NSString stringWithUTF8String:entry->ifa_name];
        if (name) {
            results[name] = [NSValue valueWithBytes:&counters objCType:@encode(CSpeedCounters)];
        }
    }
    freeifaddrs(interfaces);
    return results;
}

static NSString *CSpeedFormatRate(double bytesPerSecond)
{
    if (bytesPerSecond >= 1024.0 * 1024.0 * 1024.0) {
        return [NSString stringWithFormat:@"%.2f GB/s", bytesPerSecond / (1024.0 * 1024.0 * 1024.0)];
    }
    if (bytesPerSecond >= 1024.0 * 1024.0) {
        return [NSString stringWithFormat:@"%.2f MB/s", bytesPerSecond / (1024.0 * 1024.0)];
    }
    if (bytesPerSecond >= 1024.0) {
        return [NSString stringWithFormat:@"%.1f KB/s", bytesPerSecond / 1024.0];
    }
    return [NSString stringWithFormat:@"%.0f B/s", MAX(bytesPerSecond, 0.0)];
}

@interface CSpeedOverlayWindow : UIWindow
@end

@implementation CSpeedOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    // A passive overlay must never block touches to apps underneath it.
    (void)point;
    (void)event;
    return nil;
}
@end

@interface CSpeedController : NSObject
@property (nonatomic, strong) CSpeedOverlayWindow *window;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSDictionary<NSString *, NSValue *> *previousCounters;
@property (nonatomic) CFTimeInterval previousTime;

@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL showDownload;
@property (nonatomic) BOOL showUpload;
@property (nonatomic) BOOL hideWhenIdle;
@property (nonatomic, copy) NSString *position;
@property (nonatomic, copy) NSString *colorScheme;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic) CGFloat opacity;
@property (nonatomic) CGFloat horizontalInset;
@property (nonatomic) CGFloat verticalInset;

+ (instancetype)sharedController;
- (void)start;
- (void)reloadPreferences;
@end

@implementation CSpeedController

+ (instancetype)sharedController
{
    static CSpeedController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)start
{
    if (self.timer) return;
    [self reloadPreferences];
    self.previousCounters = CSpeedReadNetworkCounters() ?: @{};
    self.previousTime = CACurrentMediaTime();

    self.timer = [NSTimer timerWithTimeInterval:1.0
                                       target:self
                                     selector:@selector(updateSpeed:)
                                     userInfo:nil
                                      repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self ensureWindow];
}

- (void)reloadPreferences
{
    NSDictionary *values = [NSDictionary dictionaryWithContentsOfFile:CSpeedPreferencesPath] ?: @{};

    self.enabled = values[@"Enabled"] ? [values[@"Enabled"] boolValue] : YES;
    self.showDownload = values[@"ShowDownload"] ? [values[@"ShowDownload"] boolValue] : YES;
    self.showUpload = values[@"ShowUpload"] ? [values[@"ShowUpload"] boolValue] : YES;
    self.hideWhenIdle = [values[@"HideWhenIdle"] boolValue];
    self.position = [values[@"Position"] isKindOfClass:NSString.class] ? values[@"Position"] : @"bottomRight";
    self.colorScheme = [values[@"ColorScheme"] isKindOfClass:NSString.class] ? values[@"ColorScheme"] : @"system";
    self.fontSize = CSpeedClamp(values[@"FontSize"] ? [values[@"FontSize"] doubleValue] : 12.5, 10.0, 20.0);
    self.opacity = CSpeedClamp(values[@"Opacity"] ? [values[@"Opacity"] doubleValue] : 0.86, 0.15, 1.0);
    self.horizontalInset = CSpeedClamp(values[@"HorizontalInset"] ? [values[@"HorizontalInset"] doubleValue] : 14.0, 8.0, 80.0);
    self.verticalInset = CSpeedClamp(values[@"VerticalInset"] ? [values[@"VerticalInset"] doubleValue] : 18.0, 8.0, 100.0);

    [self applyAppearance];
    [self updateLayout];
    if (!self.enabled && self.window) self.window.hidden = YES;
}

- (void)ensureWindow
{
    if (self.window || !self.enabled) return;

    UIWindowScene *preferredScene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if (![candidate isKindOfClass:UIWindowScene.class]) continue;
        preferredScene = (UIWindowScene *)candidate;
        if (candidate.activationState == UISceneActivationStateForegroundActive) break;
    }

    if (preferredScene) {
        self.window = [[CSpeedOverlayWindow alloc] initWithWindowScene:preferredScene];
    } else {
        // Some SpringBoard configurations expose no public UIWindowScene.
        self.window = [[CSpeedOverlayWindow alloc] initWithFrame:CGRectMake(0, 0, 130, 48)];
    }

    self.window.windowLevel = UIWindowLevelStatusBar + 50.0;
    self.window.userInteractionEnabled = NO;
    self.window.clipsToBounds = YES;
    self.window.layer.cornerRadius = 12.0;

    self.label = [[UILabel alloc] initWithFrame:CGRectZero];
    self.label.numberOfLines = 2;
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.adjustsFontSizeToFitWidth = YES;
    self.label.minimumScaleFactor = 0.75;
    self.label.text = @"↓ —\n↑ —";
    [self.window addSubview:self.label];

    [self applyAppearance];
    [self updateLayout];
    self.window.hidden = NO;
}

- (void)applyAppearance
{
    if (!self.window || !self.label) return;

    UIColor *text = nil;
    UIColor *background = nil;
    if ([self.colorScheme isEqualToString:@"light"]) {
        text = UIColor.blackColor;
        background = UIColor.whiteColor;
    } else if ([self.colorScheme isEqualToString:@"dark"]) {
        text = UIColor.whiteColor;
        background = UIColor.blackColor;
    } else {
        text = UIColor.labelColor;
        background = UIColor.secondarySystemBackgroundColor;
    }

    self.label.textColor = text;
    self.label.font = [UIFont monospacedDigitSystemFontOfSize:self.fontSize weight:UIFontWeightSemibold];
    self.window.backgroundColor = [background colorWithAlphaComponent:self.opacity];
}

- (void)updateLayout
{
    if (!self.window) return;

    BOOL twoLines = self.showDownload && self.showUpload;
    CGFloat width = CSpeedClamp(self.fontSize * 11.0 + 25.0, 140.0, 245.0);
    CGFloat rowHeight = MAX(self.fontSize + 7.0, 20.0);
    CGFloat height = rowHeight * (twoLines ? 2.0 : 1.0) + 9.0;

    CGRect bounds = self.window.windowScene
        ? self.window.windowScene.coordinateSpace.bounds
        : UIScreen.mainScreen.bounds;

    // A conservative top reserved area avoids the notch / Dynamic Island by
    // default, without depending on undocumented SpringBoard view classes.
    CGFloat reservedTop = MAX(self.window.safeAreaInsets.top, 64.0);
    CGFloat reservedBottom = MAX(self.window.safeAreaInsets.bottom, 24.0);
    BOOL left = [self.position isEqualToString:@"topLeft"] ||
                [self.position isEqualToString:@"bottomLeft"];
    BOOL top = [self.position isEqualToString:@"topLeft"] ||
               [self.position isEqualToString:@"topRight"];

    CGFloat x = left ? self.horizontalInset : CGRectGetWidth(bounds) - width - self.horizontalInset;
    CGFloat y = top ? reservedTop + self.verticalInset
                    : CGRectGetHeight(bounds) - reservedBottom - height - self.verticalInset;

    x = CSpeedClamp(x, 0.0, MAX(0.0, CGRectGetWidth(bounds) - width));
    y = CSpeedClamp(y, 0.0, MAX(0.0, CGRectGetHeight(bounds) - height));
    self.window.frame = CGRectMake(x, y, width, height);
    self.label.frame = CGRectInset(self.window.bounds, 5.0, 3.0);
}

- (void)updateSpeed:(NSTimer *)timer
{
    (void)timer;
    [self ensureWindow];

    NSDictionary<NSString *, NSValue *> *snapshot = CSpeedReadNetworkCounters();
    if (!snapshot) return;
    CFTimeInterval now = CACurrentMediaTime();
    double elapsed = now - self.previousTime;
    double download = 0.0;
    double upload = 0.0;

    if (self.previousCounters && elapsed > 0.0) {
        for (NSString *name in snapshot) {
            NSValue *oldValue = self.previousCounters[name];
            if (!oldValue) continue;

            CSpeedCounters previous = {0, 0};
            CSpeedCounters current = {0, 0};
            [oldValue getValue:&previous];
            [snapshot[name] getValue:&current];

            CSpeedRates rates = CSpeedCalculateRates(previous, current, elapsed);
            download += rates.downloadBytesPerSecond;
            upload += rates.uploadBytesPerSecond;
        }
    }

    self.previousCounters = snapshot;
    self.previousTime = now;
    if (!self.enabled || !self.window) return;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (self.showDownload) [lines addObject:[@"↓ " stringByAppendingString:CSpeedFormatRate(download)]];
    if (self.showUpload) [lines addObject:[@"↑ " stringByAppendingString:CSpeedFormatRate(upload)]];
    self.label.text = [lines componentsJoinedByString:@"\n"];
    self.window.hidden = lines.count == 0 ||
        (self.hideWhenIdle && download < 1.0 && upload < 1.0);
    [self updateLayout];
}

@end

static void CSpeedPreferencesDidChange(CFNotificationCenterRef center,
                                      void *observer,
                                      CFStringRef name,
                                      const void *object,
                                      CFDictionaryRef userInfo)
{
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[CSpeedController sharedController] reloadPreferences];
    });
}

%ctor
{
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        CSpeedPreferencesDidChange,
                                        CSpeedPreferencesNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[CSpeedController sharedController] start];
        });
    }
}
