#include "wiWindowRegistration.h"

namespace wiWindowRegistration
{
	window_type window = nullptr;

	window_type GetRegisteredWindow() {
		return window;
	}
	void RegisterWindow(window_type wnd) {
		window = wnd;
	}
	bool IsWindowActive() {
#ifdef _WIN32
		HWND fgw = GetForegroundWindow();
		return fgw == window;
#elif WINSTORE_SUPPORT
		return true;
#elif __APPLE__
        return true;
#endif
	}
}
