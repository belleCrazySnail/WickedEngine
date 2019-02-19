#ifndef WICKEDENGINE_OBJCHELPER_DEFINED
#define WICKEDENGINE_OBJCHELPER_DEFINED


#include <string>
#include "wiWindowRegistration.h"

namespace wiGraphicsTypes {
    class GraphicsDevice;
}

namespace wiObjCHelper
{
    double getCurrentTime();
    void logMessage(const std::string& msg);
    wiGraphicsTypes::GraphicsDevice *createMetalGraphicsDevice(wiWindowRegistration::window_type window, bool fullscreen = false, bool debuglayer = false);
    const std::string &getResourceLocation();
}

#endif // WICKEDENGINE_OBJCHELPER_DEFINED
