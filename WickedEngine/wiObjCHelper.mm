#include "wiVersion.h"

#include "wiGraphicsDevice_Metal.h"
#import <Foundation/Foundation.h>

namespace wiObjCHelper
{
    double getCurrentTime() {
        return CFAbsoluteTimeGetCurrent();
    }
    
    void logMessage(const std::string& msg) {
        NSLog(@"%@", [NSString stringWithUTF8String:msg.c_str()]);
    }
    
    wiGraphicsTypes::GraphicsDevice *createMetalGraphicsDevice(wiWindowRegistration::window_type window, bool fullscreen, bool debuglayer)
    {
        return new wiGraphicsTypes::GraphicsDevice_Metal(window, fullscreen, debuglayer);
    }
    
    std::string ResourceLocation = [[[NSBundle mainBundle] resourcePath] UTF8String];
    const std::string &getResourceLocation() {
        return ResourceLocation;
    }
    
}
