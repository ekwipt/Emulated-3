// Cocoa view for the panel: a child NSView of the host's plugin view (VST3 / AU, via the CLAP cocoa window API).
// Everything runs on the main thread: Cocoa delivers the events straight to the callbacks.  Blits come from a
// 0x00RRGGBB canvas; the canvas is in device pixels (view size in points x the screen's backing scale), and every
// coordinate passed to the callbacks is in canvas pixels.
#pragma once
#include "raster.h"
#include <functional>
#include <string>

namespace eiii::ui {

class mac_window
{
public:
	struct callbacks
	{
		std::function<void(int x, int y, int button)> down, up;
		std::function<void(int x, int y)> move;
		std::function<void(int x, int y, int steps)> wheel;
		std::function<void(int w, int h)> resized;      // canvas pixels (backing scale or view size changed)
		std::function<void()> expose, focus_out;
	};
	mac_window();
	~mac_window();
	mac_window(mac_window const &) = delete;
	mac_window &operator=(mac_window const &) = delete;

	// parent: the host's NSView *; w, h in points
	bool open(void *parent, int w, int h, std::string &error);
	void close();
	bool is_open() const;
	void present(canvas const &c, recti r);           // copy a region of the canvas to the view
	void set_size(int w, int h);                      // points
	void show(bool visible);
	int pixel_width() const;
	int pixel_height() const;
	callbacks cb;

	struct impl;
private:
	impl *m;
};

} // namespace eiii::ui
