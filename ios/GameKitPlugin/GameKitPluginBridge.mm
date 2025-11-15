#import <Foundation/Foundation.h>
#import "GameKitPlugin-Swift.h"

extern "C" {

void gamekit_authenticate() {
    [[GameKitPlugin shared] authenticate];
}

void gamekit_submit_score(int score, const char *leaderboardId) {
    NSString *lid = [NSString stringWithUTF8String:leaderboardId];
    [[GameKitPlugin shared] submitScore:score leaderboardId:lid];
}

}
