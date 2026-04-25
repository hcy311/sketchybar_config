#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>

#include "../sketchybar.h"

static NSString* g_event_name = @"media_change";
static NSString* g_last_payload = nil;

static NSString* sanitize_value(id value) {
  if (!value || value == [NSNull null]) return @"";
  NSString* string = [value isKindOfClass:[NSString class]] ? value : [value description];
  string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
  string = [string stringByReplacingOccurrencesOfString:@"'" withString:@" "];
  string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
  string = [string stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
  return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString* normalize_state(id state_value, BOOL has_track) {
  NSString* normalized = [[sanitize_value(state_value) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([normalized containsString:@"play"]) return @"playing";
  if ([normalized containsString:@"pause"]) return @"paused";
  if ([normalized containsString:@"stop"]) return @"stopped";
  return has_track ? @"playing" : @"";
}

static NSString* running_app_name(NSString* bundle_id, NSString* fallback) {
  NSArray<NSRunningApplication*>* apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundle_id];
  for (NSRunningApplication* app in apps) {
    if (!app.terminated) {
      return app.localizedName ?: fallback;
    }
  }
  return fallback;
}

static NSDictionary* query_bundle(NSString* bundle_id, NSString* fallback_name) {
  Class app_class = NSClassFromString(@"SBApplication");
  if (!app_class) return nil;

  id app = [app_class performSelector:@selector(applicationWithBundleIdentifier:) withObject:bundle_id];
  if (!app) return nil;

  @try {
    id running_value = [app valueForKey:@"running"];
    if (running_value && [running_value respondsToSelector:@selector(boolValue)] && ![running_value boolValue]) {
      return nil;
    }

    id track = [app valueForKey:@"currentTrack"];
    if (!track || track == [NSNull null]) return nil;

    NSString* title = sanitize_value([track valueForKey:@"name"]);
    NSString* artist = sanitize_value([track valueForKey:@"artist"]);
    if (title.length == 0 && artist.length == 0) return nil;

    NSString* app_name = running_app_name(bundle_id, fallback_name);
    NSString* state = normalize_state([app valueForKey:@"playerState"], YES);

    return @{
      @"app": app_name ?: fallback_name,
      @"state": state ?: @"playing",
      @"title": title ?: @"",
      @"artist": artist ?: @"",
    };
  } @catch (__unused NSException* exception) {
    return nil;
  }
}

static void trigger_media_event(NSDictionary* payload) {
  NSString* app = sanitize_value(payload[@"app"]);
  NSString* state = sanitize_value(payload[@"state"]);
  NSString* title = sanitize_value(payload[@"title"]);
  NSString* artist = sanitize_value(payload[@"artist"]);

  NSString* fingerprint = [NSString stringWithFormat:@"%@\t%@\t%@\t%@", app, state, title, artist];
  if ([g_last_payload isEqualToString:fingerprint]) {
    return;
  }
  g_last_payload = fingerprint;

  char message[4096];
  snprintf(message,
           sizeof(message),
           "--trigger '%s' app='%s' state='%s' title='%s' artist='%s'",
           [g_event_name UTF8String],
           [app UTF8String],
           [state UTF8String],
           [title UTF8String],
           [artist UTF8String]);
  sketchybar(message);
}

static NSDictionary* current_media_payload(void) {
  NSDictionary* spotify = query_bundle(@"com.spotify.client", @"Spotify");
  if (spotify) return spotify;

  NSDictionary* music = query_bundle(@"com.apple.Music", @"Music");
  if (music) return music;

  return @{
    @"app": @"",
    @"state": @"stopped",
    @"title": @"",
    @"artist": @"",
  };
}

@interface MediaObserver : NSObject
@end

@implementation MediaObserver

- (void)pollNow {
  trigger_media_event(current_media_payload());
}

- (void)start {
  [self pollNow];

  NSDistributedNotificationCenter* center = [NSDistributedNotificationCenter defaultCenter];
  [center addObserver:self
             selector:@selector(handleExternalChange:)
                 name:@"com.apple.Music.playerInfo"
               object:nil
   suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
  [center addObserver:self
             selector:@selector(handleExternalChange:)
                 name:@"com.spotify.client.PlaybackStateChanged"
               object:nil
   suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

  [NSTimer scheduledTimerWithTimeInterval:1.0
                                   target:self
                                 selector:@selector(handleTimer:)
                                 userInfo:nil
                                  repeats:YES];
}

- (void)handleExternalChange:(__unused NSNotification*)notification {
  [self pollNow];
}

- (void)handleTimer:(__unused NSTimer*)timer {
  [self pollNow];
}

@end

int main(int argc, char** argv) {
  @autoreleasepool {
    if (argc >= 2 && argv[1]) {
      g_event_name = [NSString stringWithUTF8String:argv[1]];
    }

    char event_message[512];
    snprintf(event_message, sizeof(event_message), "--add event '%s'", [g_event_name UTF8String]);
    sketchybar(event_message);

    MediaObserver* observer = [[MediaObserver alloc] init];
    [observer start];

    [[NSRunLoop currentRunLoop] run];
  }

  return 0;
}
