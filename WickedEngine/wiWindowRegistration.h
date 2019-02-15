#pragma once
#include "CommonInclude.h"
//#import <MetalKit/MetalKit.h>

namespace wiWindowRegistration
{
#ifdef _WIN32
	typedef HWND window_type;
#elif WINSTORE_SUPPORT
	typedef Windows::UI::Core::CoreWindow^ window_type;
#elif __APPLE__
    typedef void *window_type;
#endif

	window_type GetRegisteredWindow();
	void RegisterWindow(window_type wnd);
	bool IsWindowActive();
};
